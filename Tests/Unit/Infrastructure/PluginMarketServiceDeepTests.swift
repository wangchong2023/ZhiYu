//
//  PluginMarketServiceDeepTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 PluginMarketService（fetchPlugins/downloadPlugin/
//           readmeCandidateURLs）、PluginLoader（verifyPluginSignature/
//           constantTimeCompare）、JavaScriptPlugin 生命周期的未覆盖分支。
//

import XCTest
@testable import ZhiYu
import UFPCore

#if canImport(JavaScriptCore) && !os(watchOS)
import JavaScriptCore
#endif

@MainActor
final class PluginMarketServiceDeepTests: XCTestCase {

    // MARK: - PluginMarketService

    /// fetchPlugins 完成后 isLoading 应为 false
    func testFetchPluginsCompletesWithLoadingFalse() async {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        await service.fetchPlugins()
        XCTAssertFalse(service.isLoading)
    }

    /// downloadPlugin 无 downloadURL 应返回 false
    func testDownloadPluginWithoutDownloadURLReturnsFalse() async {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        let plugin = MarketPlugin(
            id: "no.url",
            version: "1.0",
            author: "Author",
            downloads: "0",
            rating: 0,
            icon: "star",
            downloadURL: nil,
            minAppVersion: nil,
            requiredPermissions: nil,
            monetization: nil,
            reviewCount: nil,
            category: nil,
            source: nil,
            names: [:],
            descriptions: [:]
        )
        let result = await service.downloadPlugin(plugin)
        XCTAssertFalse(result)
    }

    /// downloadPlugin 无效 URL 字符串应返回 false
    func testDownloadPluginWithInvalidURLStringReturnsFalse() async {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        let plugin = MarketPlugin(
            id: "invalid.url",
            version: "1.0",
            author: "Author",
            downloads: "0",
            rating: 0,
            icon: "star",
            downloadURL: "not-a-valid-url",
            minAppVersion: nil,
            requiredPermissions: nil,
            monetization: nil,
            reviewCount: nil,
            category: nil,
            source: nil,
            names: [:],
            descriptions: [:]
        )
        let result = await service.downloadPlugin(plugin)
        XCTAssertFalse(result)
    }

    /// readmeCandidateURLs 中文语言应返回 zh-Hans + en + default 三个候选
    func testReadmeCandidateURLsChineseLanguageReturnsThreeCandidates() {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        let urls = service.readmeCandidateURLs(
            forID: "test.plugin",
            downloadURLString: "https://example.com/plugins/test/plugin",
            preferredLanguages: ["zh-Hans"]
        )
        XCTAssertEqual(urls.count, 3)
        XCTAssertTrue(urls[0].absoluteString.contains("test.plugin_zh-Hans.md"))
        XCTAssertTrue(urls[1].absoluteString.contains("test.plugin_en.md"))
        XCTAssertTrue(urls[2].absoluteString.contains("test.plugin.md"))
    }

    /// readmeCandidateURLs 英文语言应返回 en + default 两个候选
    func testReadmeCandidateURLsEnglishLanguageReturnsTwoCandidates() {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        let urls = service.readmeCandidateURLs(
            forID: "test.plugin",
            downloadURLString: "https://example.com/plugins/test/plugin",
            preferredLanguages: ["en"]
        )
        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls[0].absoluteString.contains("test.plugin_en.md"))
        XCTAssertTrue(urls[1].absoluteString.contains("test.plugin.md"))
    }

    /// readmeCandidateURLs 其他语言应返回 lang + en + default 三个候选
    func testReadmeCandidateURLsOtherLanguageReturnsThreeCandidates() {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        let urls = service.readmeCandidateURLs(
            forID: "test.plugin",
            downloadURLString: "https://example.com/plugins/test/plugin",
            preferredLanguages: ["ja-JP"]
        )
        XCTAssertEqual(urls.count, 3)
        XCTAssertTrue(urls[0].absoluteString.contains("test.plugin_ja.md"))
        XCTAssertTrue(urls[1].absoluteString.contains("test.plugin_en.md"))
        XCTAssertTrue(urls[2].absoluteString.contains("test.plugin.md"))
    }

    /// readmeCandidateURLs 无效 URL 字符串应返回空列表
    func testReadmeCandidateURLsInvalidURLReturnsEmpty() {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        let urls = service.readmeCandidateURLs(
            forID: "test.plugin",
            downloadURLString: "",
            preferredLanguages: ["en"]
        )
        XCTAssertTrue(urls.isEmpty)
    }

    /// readmeCandidateURLs 空 preferredLanguages 应 fallback 到 en
    func testReadmeCandidateURLsEmptyPreferredLanguagesFallsBackToEn() {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)
        let urls = service.readmeCandidateURLs(
            forID: "test.plugin",
            downloadURLString: "https://example.com/plugins/test/plugin",
            preferredLanguages: []
        )
        XCTAssertFalse(urls.isEmpty)
        XCTAssertTrue(urls.contains { $0.absoluteString.contains("test.plugin_en.md") })
    }

    // MARK: - PluginLoader.verifyPluginSignature

    /// isTrustedLocal=true 应跳过签名校验返回 true
    func testVerifyPluginSignatureTrustedLocalReturnsTrue() {
        let manifest = PluginManifest(
            id: "local.trusted",
            version: "1.0",
            names: ["en": "Trusted"],
            descriptions: ["en": "Trusted plugin"]
        )
        XCTAssertTrue(PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest,
            isTrustedLocal: true
        ))
    }

    /// 外部插件使用 local. 前缀应拒绝
    func testVerifyPluginSignatureExternalLocalPrefixRejected() {
        let manifest = PluginManifest(
            id: "local.external",
            version: "1.0",
            names: ["en": "External"],
            descriptions: ["en": "External plugin"]
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest,
            isTrustedLocal: false
        ))
    }

    /// 外部插件无签名应拒绝
    func testVerifyPluginSignatureExternalNoSignatureRejected() {
        let manifest = PluginManifest(
            id: "external.nosig",
            version: "1.0",
            names: ["en": "No Sig"],
            descriptions: ["en": "No signature"]
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest,
            isTrustedLocal: false
        ))
    }

    /// 外部插件空签名应拒绝
    func testVerifyPluginSignatureExternalEmptySignatureRejected() {
        let manifest = PluginManifest(
            id: "external.emptysig",
            version: "1.0",
            names: ["en": "Empty Sig"],
            descriptions: ["en": "Empty signature"],
            codeSignature: ""
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest,
            isTrustedLocal: false
        ))
    }

    /// 外部插件无效 hex 签名应拒绝
    func testVerifyPluginSignatureExternalInvalidHexSignatureRejected() {
        let manifest = PluginManifest(
            id: "external.invalidhex",
            version: "1.0",
            names: ["en": "Invalid Hex"],
            descriptions: ["en": "Invalid hex sig"],
            codeSignature: "not-hex-zzzz"
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest,
            isTrustedLocal: false
        ))
    }

    /// 外部插件签名不匹配应拒绝
    func testVerifyPluginSignatureExternalMismatchedSignatureRejected() {
        let manifest = PluginManifest(
            id: "external.mismatch",
            version: "1.0",
            names: ["en": "Mismatch"],
            descriptions: ["en": "Mismatched sig"],
            codeSignature: "deadbeef"
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest,
            isTrustedLocal: false
        ))
    }

    // MARK: - PluginLoader.constantTimeCompare

    /// 相同数据应返回 true
    func testConstantTimeCompareEqualDataReturnsTrue() {
        let a = Data([0x01, 0x02, 0x03])
        let b = Data([0x01, 0x02, 0x03])
        XCTAssertTrue(PluginLoader.constantTimeCompare(a, b: b))
    }

    /// 不同数据应返回 false
    func testConstantTimeCompareDifferentDataReturnsFalse() {
        let a = Data([0x01, 0x02, 0x03])
        let b = Data([0x01, 0x02, 0x04])
        XCTAssertFalse(PluginLoader.constantTimeCompare(a, b: b))
    }

    /// 不同长度应返回 false
    func testConstantTimeCompareDifferentLengthReturnsFalse() {
        let a = Data([0x01, 0x02])
        let b = Data([0x01, 0x02, 0x03])
        XCTAssertFalse(PluginLoader.constantTimeCompare(a, b: b))
    }

    /// 空数据应返回 true
    func testConstantTimeCompareEmptyDataReturnsTrue() {
        XCTAssertTrue(PluginLoader.constantTimeCompare(Data(), b: Data()))
    }

    // MARK: - JavaScriptPlugin

    #if canImport(JavaScriptCore) && !os(watchOS)
    /// 语法正确的脚本应成功创建插件
    func testJavaScriptPluginValidScriptCreatesInstance() {
        let manifest = PluginManifest(
            id: "js.valid",
            version: "1.0",
            names: ["en": "Valid JS"],
            descriptions: ["en": "Valid JS plugin"]
        )
        let plugin = JavaScriptPlugin(script: "function onLoad() {}", manifest: manifest)
        XCTAssertNotNil(plugin)
    }

    /// 空脚本应成功创建插件
    func testJavaScriptPluginEmptyScriptCreatesInstance() {
        let manifest = PluginManifest(
            id: "js.empty",
            version: "1.0",
            names: ["en": "Empty JS"],
            descriptions: ["en": "Empty JS plugin"]
        )
        let plugin = JavaScriptPlugin(script: "", manifest: manifest)
        XCTAssertNotNil(plugin)
    }

    /// onLoad 无 onLoad 函数应不崩溃
    func testJavaScriptPluginOnLoadWithoutFunctionNoCrash() {
        let manifest = PluginManifest(
            id: "js.no.onload",
            version: "1.0",
            names: ["en": "No onLoad"],
            descriptions: ["en": "No onLoad function"]
        )
        guard let plugin = JavaScriptPlugin(script: "", manifest: manifest) else {
            XCTFail("插件应创建成功")
            return
        }
        let mockContext = MockPluginContext(manifest: manifest)
        plugin.onLoad(context: mockContext)
    }

    /// onUnload 无 onUnload 函数应不崩溃
    func testJavaScriptPluginOnUnloadWithoutFunctionNoCrash() {
        let manifest = PluginManifest(
            id: "js.no.onunload",
            version: "1.0",
            names: ["en": "No onUnload"],
            descriptions: ["en": "No onUnload function"]
        )
        guard let plugin = JavaScriptPlugin(script: "", manifest: manifest) else {
            XCTFail("插件应创建成功")
            return
        }
        let mockContext = MockPluginContext(manifest: manifest)
        plugin.onLoad(context: mockContext)
        plugin.onUnload()
    }
    #endif
}

// MARK: - 辅助类型

/// 测试用 PluginContext 桩实现
@MainActor
private final class MockPluginContext: PluginContext {
    let manifest: PluginManifest
    var hostVersion: String { "2.0.0" }

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func log(_ message: String) {}
    func requestAIAccess(prompt: String) async -> String? { nil }
    func queryPages(matching query: String) async -> [KnowledgePage] { [] }
    func registerCommand(id: String, name: String, callback: @escaping @MainActor () -> Void) {}
    func registerRibbonItem(icon: String, title: String, callback: @escaping @MainActor () -> Void) {}
    func registerPageProcessor(_ processor: any KnowledgePageProcessor) {}
    func registerSettingTab(name: String, schema: String?, callback: @escaping @MainActor (String?) -> Void) {}
    func registerView(id: String, title: String, icon: String, callback: @escaping @MainActor () -> Void) {}
    func addEventListener(event: String, callback: @escaping @MainActor (Any?) -> Void) {}
    func saveData(key: String, value: String) {}
    func loadData(key: String) -> String? { nil }
}
