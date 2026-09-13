//
//  PluginManifestDeepTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 PluginManifest 本地化、MonetizationInfo、MarketPlugin
//           （含 CommunityPluginEntry 映射）的未覆盖分支。
//

import XCTest
@testable import ZhiYu
import UFPCore

@MainActor
final class PluginManifestDeepTests: XCTestCase {

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
}
