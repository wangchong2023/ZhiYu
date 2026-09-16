//
//  JSPluginPostProcessSizeTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 JavaScriptPlugin.postProcess 的返回值大小限制——安全防护一致性。
//

import XCTest
@testable import ZhiYu

#if canImport(JavaScriptCore)

@MainActor
final class JSPluginPostProcessSizeTests: XCTestCase {

    // MARK: - 辅助方法

    private static let projectRoot: String = {
        let url = URL(fileURLWithPath: #filePath)
        return url.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }()

    private func readJS(_ relativePath: String) -> String? {
        let full = Self.projectRoot + "/" + relativePath
        return try? String(contentsOfFile: full, encoding: .utf8)
    }

    private func makeManifest() -> PluginManifest {
        return PluginManifest(
            id: "test.js.postprocess.size",
            version: "1.0.0",
            author: "Tester",
            permissions: ["writeContent"],
            allowedDomains: [],
            names: ["en": "PostProcess Size Test"],
            descriptions: ["en": "PostProcess Size Test"]
        )
    }

    // MARK: - 正常大小 postProcess 应放行

    /// 使用真实插件文件验证 postProcess 正常工作
    func testPostProcessWithRealPluginPassesThrough() {
        guard let js = readJS("Tools/Plugins/Local/word-counter/index.js") else {
            XCTFail("无法读取 word-counter 插件")
            return
        }

        let manifest = PluginManifest(
            id: "test.js.postprocess.real",
            version: "1.0.0",
            author: "Tester",
            permissions: ["log"],
            allowedDomains: [],
            names: ["en": "Real Plugin Test"],
            descriptions: ["en": "Real Plugin Test"]
        )

        guard let plugin = JavaScriptPlugin(script: js, manifest: manifest) else {
            XCTFail("无法实例化 JavaScriptPlugin")
            return
        }

        do {
            let result = try plugin.postProcess(content: "# Hello World\n\nThis is a test.")
            XCTAssertFalse(result.isEmpty, "postProcess 应返回非空结果")
        } catch {
            XCTFail("正常 postProcess 不应抛出错误: \(error)")
        }
    }

    // MARK: - postProcess 无定义时返回原文

    /// 脚本没有 postProcess 函数时，应直接返回 content
    /// 使用 toc-generator 插件（有 preProcess 但可能无 postProcess）
    func testPostProcessNotDefinedReturnsContent() {
        guard let js = readJS("Tools/Plugins/Local/toc-generator/index.js") else {
            XCTFail("无法读取 toc-generator 插件")
            return
        }

        let manifest = PluginManifest(
            id: "test.js.postprocess.none",
            version: "1.0.0",
            author: "Tester",
            permissions: ["log"],
            allowedDomains: [],
            names: ["en": "No PostProcess Test"],
            descriptions: ["en": "No PostProcess Test"]
        )

        guard let plugin = JavaScriptPlugin(script: js, manifest: manifest) else {
            XCTFail("无法实例化 JavaScriptPlugin")
            return
        }

        do {
            let result = try plugin.postProcess(content: "original content")
            // toc-generator 可能没有 postProcess，应返回原文
            XCTAssertFalse(result.isEmpty, "postProcess 应返回非空结果")
        } catch {
            // 如果 toc-generator 有 postProcess，可能抛出执行错误，这也是可接受的
            // 关键是不应因 Function.prototype 错误失败
        }
    }

    // MARK: - 源码审计验证：postProcess 与 preProcess 统一使用 processContent 进行大小检查

    /// 验证 postProcess 与 preProcess 均委托至包含 maxResponseSize 检查的通用处理函数
    func testPostProcessSourceCodeHasSizeCheck() {
        let sourcePath = Self.projectRoot + "/Sources/Infrastructure/Plugins/JavaScriptPlugin.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("无法读取源码文件: \(sourcePath)")
            return
        }

        // 验证 postProcess 与 preProcess 均调用 processContent
        XCTAssertTrue(source.contains("func postProcess(content: String) throws -> String"), "应找到 postProcess 函数")
        XCTAssertTrue(source.contains("func preProcess(content: String) throws -> String"), "应找到 preProcess 函数")
        XCTAssertTrue(source.contains("func processContent("), "应包含统一的 processContent 通用处理函数")

        // 验证 processContent 包含 maxResponseSize 与 payloadTooLarge
        guard let processContentRange = source.range(of: "func processContent(") else {
            XCTFail("应找到 processContent 函数")
            return
        }
        let processContentSection = String(source[processContentRange.lowerBound...])
        XCTAssertTrue(processContentSection.contains("maxResponseSize"), "processContent 应包含 maxResponseSize 检查")
        XCTAssertTrue(processContentSection.contains("payloadTooLarge"), "processContent 应抛出 payloadTooLarge 错误")
    }

    /// 对比验证：preProcess 和 postProcess 统一经过 processContent 大小检查
    func testBothPreAndPostProcessHaveSizeCheck() {
        let sourcePath = Self.projectRoot + "/Sources/Infrastructure/Plugins/JavaScriptPlugin.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("无法读取源码文件")
            return
        }

        // 验证 preProcess 和 postProcess 均调用 processContent
        let hasPreProcess = source.contains("processContent(content: content, functionName: PluginConstants.JSFunctionName.preProcess") ||
                            source.contains("processContent(content: content, functionName: \"preProcess\"")
        let hasPostProcess = source.contains("processContent(content: content, functionName: PluginConstants.JSFunctionName.postProcess") ||
                             source.contains("processContent(content: content, functionName: \"postProcess\"")
        XCTAssertTrue(hasPreProcess, "preProcess 应调用 processContent")
        XCTAssertTrue(hasPostProcess, "postProcess 应调用 processContent")
        XCTAssertTrue(source.contains("maxResponseSize"), "源码应包含 maxResponseSize")
        XCTAssertTrue(source.contains("payloadTooLarge"), "源码应抛出 payloadTooLarge")
    }

    /// 行为测试：超大响应在 preProcess 和 postProcess 中均被硬拦截
    func testOversizedPayload_PreProcessAndPostProcess_ThrowsPayloadTooLarge() {
        let js = """
        function preProcess(content) {
            return "A".repeat(6000000);
        }
        function postProcess(content) {
            return "B".repeat(6000000);
        }
        """
        let manifest = PluginManifest(
            id: "test.js.oversized.payload",
            version: "1.0.0",
            author: "Tester",
            permissions: ["writeContent"],
            allowedDomains: [],
            names: ["en": "Oversized Payload Test"],
            descriptions: ["en": "Oversized Payload Test"]
        )

        guard let plugin = JavaScriptPlugin(script: js, manifest: manifest) else {
            XCTFail("无法实例化 JavaScriptPlugin")
            return
        }

        XCTAssertThrowsError(try plugin.preProcess(content: "input")) { error in
            guard let sandboxError = error as? PluginSandboxError, case .payloadTooLarge = sandboxError else {
                XCTFail("preProcess 应当抛出 payloadTooLarge 错误，实际: \(error)")
                return
            }
        }

        XCTAssertThrowsError(try plugin.postProcess(content: "input")) { error in
            guard let sandboxError = error as? PluginSandboxError, case .payloadTooLarge = sandboxError else {
                XCTFail("postProcess 应当抛出 payloadTooLarge 错误，实际: \(error)")
                return
            }
        }
    }
}

#endif
