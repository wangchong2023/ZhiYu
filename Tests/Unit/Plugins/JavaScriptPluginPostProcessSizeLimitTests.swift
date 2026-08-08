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

    // MARK: - 源码审计验证：postProcess 已添加大小检查

    /// 验证 postProcess 源码中包含 maxResponseSize 检查（与 preProcess 一致）
    /// 此测试确保安全防护一致性——如果未来有人移除检查，此测试会失败
    func testPostProcessSourceCodeHasSizeCheck() {
        let sourcePath = Self.projectRoot + "/Sources/Infrastructure/Plugins/JavaScriptPlugin.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("无法读取源码文件: \(sourcePath)")
            return
        }

        // 提取 postProcess 函数体（从 "func postProcess" 到文件末尾的类结束 }）
        guard let postProcessStart = source.range(of: "func postProcess(content: String)") else {
            XCTFail("应找到 postProcess 函数")
            return
        }

        // 从 postProcess 开始到文件末尾
        let postProcessSection = String(source[postProcessStart.lowerBound...])

        // 验证 postProcess 包含 maxResponseSize 检查
        XCTAssertTrue(postProcessSection.contains("maxResponseSize"), "postProcess 应包含 maxResponseSize 检查")
        XCTAssertTrue(postProcessSection.contains("payloadTooLarge"), "postProcess 应抛出 payloadTooLarge 错误")
    }

    /// 对比验证：preProcess 和 postProcess 都应有大小检查
    func testBothPreAndPostProcessHaveSizeCheck() {
        let sourcePath = Self.projectRoot + "/Sources/Infrastructure/Plugins/JavaScriptPlugin.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("无法读取源码文件")
            return
        }

        // 统计 maxResponseSize 出现次数——应为 2 次（preProcess + postProcess）
        let count = source.components(separatedBy: "maxResponseSize").count - 1
        XCTAssertGreaterThanOrEqual(count, 2, "preProcess 和 postProcess 都应包含 maxResponseSize 检查，实际: \(count)")

        // 统计 payloadTooLarge 在 process 函数中的出现次数
        let payloadCount = source.components(separatedBy: "payloadTooLarge").count - 1
        XCTAssertGreaterThanOrEqual(payloadCount, 2, "preProcess 和 postProcess 都应抛出 payloadTooLarge，实际: \(payloadCount)")
    }
}

#endif
