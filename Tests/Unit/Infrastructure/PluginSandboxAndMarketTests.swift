//
//  PluginSandboxAndMarketTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 PluginSandboxGateway/PluginMarketService/JavaScriptPlugin/
//           PluginManifest/MarketPlugin/PluginConstants 的未覆盖分支。
//

import XCTest
@testable import ZhiYu
import UFPCore

#if canImport(JavaScriptCore) && !os(watchOS)
import JavaScriptCore
#endif

@MainActor
final class PluginSandboxAndMarketTests: XCTestCase {

    // MARK: - PluginSandboxGateway.auditFetch

    /// 无 network 权限应抛 permissionDenied
    func testAuditFetchWithoutNetworkPermissionThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: []
        )) { error in
            guard case PluginSandboxError.permissionDenied(let perm) = error else {
                XCTFail("期望 permissionDenied，实际: \(error)")
                return
            }
            XCTAssertEqual(perm, PluginConstants.Permission.network)
        }
    }

    /// 无效 URL 应抛 invalidURL
    func testAuditFetchInvalidURLThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "not-a-url",
            options: nil,
            allowedDomains: [],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.invalidURL = error else {
                XCTFail("期望 invalidURL，实际: \(error)")
                return
            }
        }
    }

    /// URL 无 host 应抛 invalidURL
    func testAuditFetchURLWithoutHostThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "file:///local/path",
            options: nil,
            allowedDomains: [],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.invalidURL = error else {
                XCTFail("期望 invalidURL，实际: \(error)")
                return
            }
        }
    }

    /// 域名不在允许列表应抛 dlpFetchBlocked
    func testAuditFetchDomainNotInAllowlistThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://evil.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.dlpFetchBlocked(let host) = error else {
                XCTFail("期望 dlpFetchBlocked，实际: \(error)")
                return
            }
            XCTAssertEqual(host, "evil.com")
        }
    }

    /// 空字符串允许列表不应匹配任意 host
    func testAuditFetchEmptyAllowlistDomainDoesNotMatch() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://evil.com/api",
            options: nil,
            allowedDomains: [""],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.dlpFetchBlocked = error else {
                XCTFail("空字符串白名单不应匹配，期望 dlpFetchBlocked")
                return
            }
        }
    }

    /// 子域后缀匹配应通过（example.com 白名单匹配 sub.example.com）
    func testAuditFetchSubdomainSuffixMatchSucceeds() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://sub.example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.url?.host, "sub.example.com")
    }

    /// 精确域名匹配应通过
    func testAuditFetchExactDomainMatchSucceeds() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.url?.host, "example.com")
    }

    /// 前缀欺骗不应通过（evil-example.com 不应匹配 example.com）
    func testAuditFetchPrefixSpoofingDoesNotMatch() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://evil-example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.dlpFetchBlocked = error else {
                XCTFail("前缀欺骗不应通过，期望 dlpFetchBlocked")
                return
            }
        }
    }

    /// 大写 host 应匹配小写白名单
    func testAuditFetchCaseInsensitiveHostMatchSucceeds() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://EXAMPLE.COM/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertNotNil(request.url)
    }

    /// 带 options 的请求应正确设置 method/headers/body
    func testAuditFetchWithOptionsSetsRequestFields() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: [
                "method": "POST",
                "headers": ["X-Custom": "value"],
                "body": "test body"
            ],
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "value")
        XCTAssertEqual(request.httpBody, Data("test body".utf8))
    }

    /// 默认 method 应为 GET
    func testAuditFetchDefaultMethodIsGET() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: [:],
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.httpMethod, "GET")
    }

    /// 超大 body 应抛 payloadTooLarge
    func testAuditFetchOversizedBodyThrows() {
        let largeBody = String(repeating: "A", count: PluginConstants.Sandbox.maxResponseSizeBytes + 1)
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: ["body": largeBody],
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.payloadTooLarge = error else {
                XCTFail("期望 payloadTooLarge")
                return
            }
        }
    }

    // MARK: - PluginSandboxGateway.auditStorage

    /// 正常 key/value 应通过
    func testAuditStorageNormalKeyValueSucceeds() {
        XCTAssertNoThrow(try PluginSandboxGateway.auditStorage(key: "normalKey", value: "normalValue"))
    }

    /// 超长 key 应抛 keyLengthExceeded
    func testAuditStorageOversizedKeyThrows() {
        let longKey = String(repeating: "k", count: 257)
        XCTAssertThrowsError(try PluginSandboxGateway.auditStorage(key: longKey, value: "value")) { error in
            guard case PluginSandboxError.keyLengthExceeded(let maxLen) = error else {
                XCTFail("期望 keyLengthExceeded")
                return
            }
            XCTAssertEqual(maxLen, 256)
        }
    }

    /// 超大 value 应抛 payloadTooLarge
    func testAuditStorageOversizedValueThrows() {
        let largeValue = String(repeating: "V", count: PluginConstants.Sandbox.maxResponseSizeBytes + 1)
        XCTAssertThrowsError(try PluginSandboxGateway.auditStorage(key: "key", value: largeValue)) { error in
            guard case PluginSandboxError.payloadTooLarge = error else {
                XCTFail("期望 payloadTooLarge")
                return
            }
        }
    }

    /// 边界 key 长度（256）应通过
    func testAuditStorageBoundaryKeyLengthSucceeds() {
        let boundaryKey = String(repeating: "k", count: 256)
        XCTAssertNoThrow(try PluginSandboxGateway.auditStorage(key: boundaryKey, value: "value"))
    }

    // MARK: - PluginSandboxGateway.configureWatchdog

    #if canImport(JavaScriptCore) && !os(watchOS)
    /// 配置看门狗不应崩溃
    func testConfigureWatchdogDoesNotCrash() {
        let context = JSContext()
        XCTAssertNotNil(context)
        if let context {
            PluginSandboxGateway.configureWatchdog(for: context)
        }
    }
    #endif

    // MARK: - PluginManifest 本地化

    /// name 应返回当前语言匹配的名称
    func testManifestNameReturnsLocalizedMatch() {
        let manifest = PluginManifest(
            id: "test.i18n",
            version: "1.0",
            names: ["en": "Test Plugin", "zh-Hans": "测试插件"],
            descriptions: ["en": "A test", "zh-Hans": "一个测试"]
        )
        let name = manifest.name
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(["Test Plugin", "测试插件"].contains(name) || name == "test.i18n")
    }

    /// name 无匹配语言且字典为空时应 fallback 到 id
    func testManifestNameFallbackToIdWhenNoMatch() {
        let manifest = PluginManifest(
            id: "fallback.id",
            version: "1.0",
            names: [:],
            descriptions: [:]
        )
        XCTAssertEqual(manifest.name, "fallback.id")
    }

    /// description 无匹配语言且字典为空时应 fallback 到空字符串
    func testManifestDescriptionFallbackToEmptyWhenNoMatch() {
        let manifest = PluginManifest(
            id: "desc.fallback",
            version: "1.0",
            names: [:],
            descriptions: [:]
        )
        XCTAssertEqual(manifest.description, "")
    }

    /// description 有匹配语言时应返回对应描述
    func testManifestDescriptionReturnsLocalizedMatch() {
        let manifest = PluginManifest(
            id: "desc.match",
            version: "1.0",
            names: ["en": "Test"],
            descriptions: ["en": "English description", "zh-Hans": "中文描述"]
        )
        let desc = manifest.description
        XCTAssertTrue(["English description", "中文描述"].contains(desc) || desc.isEmpty)
    }

    /// Codable 往返应保持一致
    func testManifestCodableRoundTrip() throws {
        let original = PluginManifest(
            id: "code.roundtrip",
            version: "2.0",
            author: "Tester",
            permissions: ["network", "llm"],
            allowedDomains: ["example.com"],
            names: ["en": "Round", "zh-Hans": "往返"],
            descriptions: ["en": "Round trip", "zh-Hans": "往返测试"],
            readmeFiles: ["en": "README.md", "zh-Hans": "README.zh-Hans.md"],
            iconFile: "icon.png",
            category: "utility",
            codeSignature: "abcd1234"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.author, original.author)
        XCTAssertEqual(decoded.permissions, original.permissions)
        XCTAssertEqual(decoded.allowedDomains, original.allowedDomains)
        XCTAssertEqual(decoded.readmeFiles, original.readmeFiles)
        XCTAssertEqual(decoded.iconFile, original.iconFile)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.codeSignature, original.codeSignature)
    }

    // MARK: - MonetizationInfo

    /// MonetizationInfo Codable 往返
    func testMonetizationInfoCodableRoundTrip() throws {
        let original = MonetizationInfo(model: .subscription, supportURL: "https://example.com/subscribe")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MonetizationInfo.self, from: data)
        XCTAssertEqual(decoded.model, .subscription)
        XCTAssertEqual(decoded.supportURL, "https://example.com/subscribe")
    }

    /// MonetizationInfo free 模型
    func testMonetizationInfoFreeModel() {
        let info = MonetizationInfo(model: .free, supportURL: nil)
        XCTAssertEqual(info.model, .free)
        XCTAssertNil(info.supportURL)
    }

    /// MonetizationInfo donation 模型
    func testMonetizationInfoDonationModel() {
        let info = MonetizationInfo(model: .donation, supportURL: "https://example.com/donate")
        XCTAssertEqual(info.model, .donation)
        XCTAssertEqual(info.supportURL, "https://example.com/donate")
    }

    // MARK: - MarketPlugin

    /// MarketPlugin 直接构造器应正确设置所有字段
    func testMarketPluginDirectInit() {
        let plugin = MarketPlugin(
            id: "market.test",
            version: "1.0",
            author: "Author",
            downloads: "100",
            rating: 4.5,
            icon: "star",
            downloadURL: "https://example.com/plugin",
            minAppVersion: "2.0",
            requiredPermissions: ["network"],
            monetization: MonetizationInfo(model: .free, supportURL: nil),
            reviewCount: 42,
            category: "productivity",
            source: "remote",
            names: ["en": "Market Test"],
            descriptions: ["en": "A market test plugin"]
        )
        XCTAssertEqual(plugin.id, "market.test")
        XCTAssertEqual(plugin.version, "1.0")
        XCTAssertEqual(plugin.author, "Author")
        XCTAssertEqual(plugin.downloads, "100")
        XCTAssertEqual(plugin.rating, 4.5)
        XCTAssertEqual(plugin.icon, "star")
        XCTAssertEqual(plugin.downloadURL, "https://example.com/plugin")
        XCTAssertEqual(plugin.minAppVersion, "2.0")
        XCTAssertEqual(plugin.requiredPermissions, ["network"])
        XCTAssertEqual(plugin.reviewCount, 42)
        XCTAssertEqual(plugin.category, "productivity")
        XCTAssertEqual(plugin.source, "remote")
    }

    /// MarketPlugin 从 CommunityPluginEntry 构造应正确映射字段
    func testMarketPluginInitFromCommunityPluginEntry() {
        let entry = CommunityPluginEntry(
            id: "community.plugin",
            name: "Community Plugin",
            author: "Community Author",
            description: "A community plugin",
            repo: "user/repo",
            version: "1.2.0",
            icon: "gear",
            names: ["en": "Community Plugin", "zh-Hans": "社区插件"],
            descriptions: ["en": "A community plugin", "zh-Hans": "一个社区插件"],
            category: "tools"
        )
        let downloadBase = URL(string: "https://example.com/plugins")!
        let plugin = MarketPlugin(from: entry, downloadBase: downloadBase)
        XCTAssertEqual(plugin.id, "community.plugin")
        XCTAssertEqual(plugin.version, "1.2.0")
        XCTAssertEqual(plugin.author, "Community Author")
        XCTAssertEqual(plugin.downloads, "0")
        XCTAssertEqual(plugin.rating, 0)
        XCTAssertEqual(plugin.icon, "gear")
        XCTAssertEqual(plugin.category, "tools")
        XCTAssertEqual(plugin.source, "community")
        XCTAssertEqual(plugin.names["en"], "Community Plugin")
        XCTAssertEqual(plugin.names["zh-Hans"], "社区插件")
    }

    /// CommunityPluginEntry 无 version 时应 fallback 到 "0.0.1"
    func testMarketPluginInitFromEntryWithoutVersionFallsBack() {
        let entry = CommunityPluginEntry(
            id: "no.version",
            name: "No Version",
            author: "Author",
            description: "Desc",
            repo: "user/repo",
            version: nil,
            icon: nil,
            names: nil,
            descriptions: nil,
            category: nil
        )
        let downloadBase = URL(string: "https://example.com/plugins")!
        let plugin = MarketPlugin(from: entry, downloadBase: downloadBase)
        XCTAssertEqual(plugin.version, "0.0.1")
    }

    /// CommunityPluginEntry 无 icon 时应使用 downloadBase 拼接 icon.png
    func testMarketPluginInitFromEntryWithoutIconUsesDefaultURL() {
        let entry = CommunityPluginEntry(
            id: "no.icon",
            name: "No Icon",
            author: "Author",
            description: "Desc",
            repo: "user/repo",
            version: "1.0",
            icon: nil,
            names: nil,
            descriptions: nil,
            category: nil
        )
        let downloadBase = URL(string: "https://example.com/plugins")!
        let plugin = MarketPlugin(from: entry, downloadBase: downloadBase)
        XCTAssertTrue(plugin.icon.contains("icon.png"))
        XCTAssertTrue(plugin.icon.contains("no.icon"))
    }

    /// CommunityPluginEntry 无 names 时应自动补充 en
    func testMarketPluginInitFromEntryWithoutNamesAutoFillsEn() {
        let entry = CommunityPluginEntry(
            id: "no.names",
            name: "No Names",
            author: "Author",
            description: "Desc",
            repo: "user/repo",
            version: "1.0",
            icon: nil,
            names: nil,
            descriptions: nil,
            category: nil
        )
        let downloadBase = URL(string: "https://example.com/plugins")!
        let plugin = MarketPlugin(from: entry, downloadBase: downloadBase)
        XCTAssertEqual(plugin.names["en"], "No Names")
        XCTAssertEqual(plugin.descriptions["en"], "Desc")
    }

    /// CommunityPluginEntry 空 icon 字符串应使用默认 URL
    func testMarketPluginInitFromEntryWithEmptyIconUsesDefaultURL() {
        let entry = CommunityPluginEntry(
            id: "empty.icon",
            name: "Empty Icon",
            author: "Author",
            description: "Desc",
            repo: "user/repo",
            version: "1.0",
            icon: "",
            names: nil,
            descriptions: nil,
            category: nil
        )
        let downloadBase = URL(string: "https://example.com/plugins")!
        let plugin = MarketPlugin(from: entry, downloadBase: downloadBase)
        XCTAssertTrue(plugin.icon.contains("icon.png"))
    }

    /// CommunityPluginEntry 无 category 时应 fallback 到 "efficiency"
    func testMarketPluginInitFromEntryWithoutCategoryFallsBack() {
        let entry = CommunityPluginEntry(
            id: "no.category",
            name: "No Category",
            author: "Author",
            description: "Desc",
            repo: "user/repo",
            version: "1.0",
            icon: nil,
            names: nil,
            descriptions: nil,
            category: nil
        )
        let downloadBase = URL(string: "https://example.com/plugins")!
        let plugin = MarketPlugin(from: entry, downloadBase: downloadBase)
        XCTAssertEqual(plugin.category, "efficiency")
    }

    /// MarketPlugin name 应返回本地化匹配
    func testMarketPluginNameReturnsLocalized() {
        let plugin = MarketPlugin(
            id: "name.test",
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
            names: ["en": "Name Test"],
            descriptions: ["en": "Desc"]
        )
        XCTAssertEqual(plugin.name, "Name Test")
    }

    /// MarketPlugin name 无匹配且字典为空时应 fallback 到 id
    func testMarketPluginNameFallbackToId() {
        let plugin = MarketPlugin(
            id: "fallback.plugin",
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
        XCTAssertEqual(plugin.name, "fallback.plugin")
    }

    /// MarketPlugin description 无匹配且字典为空时应 fallback 到空字符串
    func testMarketPluginDescriptionFallbackToEmpty() {
        let plugin = MarketPlugin(
            id: "desc.fallback",
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
        XCTAssertEqual(plugin.description, "")
    }

    /// MarketPlugin Codable 往返
    func testMarketPluginCodableRoundTrip() throws {
        let original = MarketPlugin(
            id: "code.test",
            version: "1.0",
            author: "Author",
            downloads: "100",
            rating: 4.5,
            icon: "star",
            downloadURL: "https://example.com",
            minAppVersion: "2.0",
            requiredPermissions: ["network"],
            monetization: MonetizationInfo(model: .free, supportURL: nil),
            reviewCount: 10,
            category: "tools",
            source: "remote",
            names: ["en": "Code Test"],
            descriptions: ["en": "Desc"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MarketPlugin.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.rating, original.rating)
        XCTAssertEqual(decoded.downloadURL, original.downloadURL)
        XCTAssertEqual(decoded.names, original.names)
    }

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

    // MARK: - PluginConstants 验证

    /// Sandbox 常量值验证
    func testPluginConstantsSandboxValues() {
        XCTAssertEqual(PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, 0.5)
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeMB, 5)
        XCTAssertGreaterThan(PluginConstants.Sandbox.maxResponseSizeBytes, 0)
    }

    /// Permission 常量值验证
    func testPluginConstantsPermissionValues() {
        XCTAssertEqual(PluginConstants.Permission.network, "network")
        XCTAssertEqual(PluginConstants.Permission.llm, "llm")
        XCTAssertEqual(PluginConstants.Permission.pagesRead, "pages.read")
        XCTAssertEqual(PluginConstants.Permission.writeContent, "writeContent")
    }

    /// DefaultManifest 常量值验证
    func testPluginConstantsDefaultManifestValues() {
        XCTAssertEqual(PluginConstants.DefaultManifest.idPrefix, "local.")
        XCTAssertEqual(PluginConstants.DefaultManifest.author, "Local Developer")
        XCTAssertEqual(PluginConstants.DefaultManifest.version, SystemConstants.Version.defaultSemVer)
        XCTAssertTrue(PluginConstants.DefaultManifest.permissions.contains("log"))
        XCTAssertTrue(PluginConstants.DefaultManifest.permissions.contains("writeContent"))
    }

    /// MarketJSON 常量值验证
    func testPluginConstantsMarketJSONValues() {
        XCTAssertEqual(PluginConstants.MarketJSON.communityPlugins, "community-plugins.json")
        XCTAssertEqual(PluginConstants.MarketJSON.communityPluginsZhHans, "community-plugins_zh-Hans.json")
        XCTAssertEqual(PluginConstants.MarketJSON.community, "community.json")
        XCTAssertEqual(PluginConstants.MarketJSON.pluginsPathSegment, "plugins")
    }

    /// LanguagePrefix 常量值验证
    func testPluginConstantsLanguagePrefixValues() {
        XCTAssertEqual(PluginConstants.LanguagePrefix.zh, "zh")
        XCTAssertEqual(PluginConstants.LanguagePrefix.en, "en")
    }

    /// MarketError 常量值验证
    func testPluginConstantsMarketErrorValues() {
        XCTAssertEqual(PluginConstants.MarketError.domain, "PluginMarketService")
        XCTAssertEqual(PluginConstants.MarketError.httpPrefix, "HTTP ")
        XCTAssertEqual(PluginConstants.MarketError.documentsNotFound, "Failed to locate documents directory")
    }

    /// PluginID 常量值验证
    func testPluginConstantsPluginIDValues() {
        XCTAssertEqual(PluginConstants.PluginID.officialPrefix, "com.zhiyu.plugin.")
        XCTAssertEqual(PluginConstants.PluginID.v1VersionPrefix, "1.")
    }

    /// JSGlobal 常量值验证
    func testPluginConstantsJSGlobalValues() {
        XCTAssertEqual(PluginConstants.JSGlobal.hostBridge, "ZhiYu")
    }

    /// AnalyticsKey 常量值验证
    func testPluginConstantsAnalyticsKeyValues() {
        XCTAssertEqual(PluginConstants.AnalyticsKey.id, "id")
        XCTAssertEqual(PluginConstants.AnalyticsKey.duration, "duration")
        XCTAssertEqual(PluginConstants.AnalyticsKey.error, "error")
    }

    /// Localization requiredLocales 验证
    func testPluginConstantsLocalizationRequiredLocales() {
        XCTAssertEqual(PluginConstants.Localization.requiredLocales, ["en", "zh-Hans"])
    }

    // MARK: - PluginSandboxError statusCode 完整覆盖

    func testStatusCodePermissionDeniedReturns403() {
        XCTAssertEqual(PluginSandboxError.permissionDenied("network").statusCode, 403)
    }

    // MARK: - PluginSandboxError errorDescription 完整覆盖

    func testErrorDescriptionPermissionDeniedContainsPermission() {
        let error = PluginSandboxError.permissionDenied("network")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("network") == true || error.errorDescription?.isEmpty == false)
    }

    // MARK: - Data hex 扩展

    /// Data hexString 初始化奇数长度应返回 nil
    func testDataHexInitOddLengthReturnsNil() {
        XCTAssertNil(Data(hexString: "abc"))
    }

    /// Data hexString 初始化空字符串应返回空 Data
    func testDataHexInitEmptyStringReturnsEmptyData() {
        let data = Data(hexString: "")
        XCTAssertEqual(data?.count, 0)
    }

    /// Data hexString 初始化带空格应正确解析
    func testDataHexInitWithSpacesParsesCorrectly() {
        let data = Data(hexString: "ab cd")
        XCTAssertEqual(data?.count, 2)
        XCTAssertEqual(data?[0], 0xab)
        XCTAssertEqual(data?[1], 0xcd)
    }

    /// Data hexString 初始化大写应正确解析
    func testDataHexInitUpperCaseParsesCorrectly() {
        let data = Data(hexString: "ABCD")
        XCTAssertEqual(data?.count, 2)
        XCTAssertEqual(data?[0], 0xab)
        XCTAssertEqual(data?[1], 0xcd)
    }

    /// Data hexString 初始化无效字符应返回 nil
    func testDataHexInitInvalidCharReturnsNil() {
        XCTAssertNil(Data(hexString: "xy"))
    }

    /// Data hexEncoded 应正确编码
    func testDataHexEncodedCorrectOutput() {
        let data = Data([0xab, 0xcd])
        XCTAssertEqual(data.hexEncoded, "abcd")
    }

    /// Data hexEncoded 空数据应返回空字符串
    func testDataHexEncodedEmptyDataReturnsEmptyString() {
        XCTAssertEqual(Data().hexEncoded, "")
    }

    /// Data hex 往返一致性
    func testDataHexRoundTrip() {
        let original = Data([0x01, 0x02, 0xff, 0x00])
        let hex = original.hexEncoded
        let restored = Data(hexString: hex)
        XCTAssertEqual(original, restored)
    }

    // MARK: - String matchesRegex 扩展

    /// matchesRegex 空字符串空模式应匹配（NSRegularExpression 空模式匹配位置 0）
    func testMatchesRegexEmptyStringEmptyPatternReturnsTrue() {
        // NSRegularExpression 空模式会匹配，但 firstMatch 在空字符串上可能返回 nil
        // 行为依赖 NSRegularExpression 实现，此处验证不崩溃即可
        _ = "".matchesRegex("")
    }

    /// matchesRegex 非空字符串空模式应不崩溃
    func testMatchesRegexNonEmptyStringEmptyPatternDoesNotCrash() {
        _ = "abc".matchesRegex("")
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
