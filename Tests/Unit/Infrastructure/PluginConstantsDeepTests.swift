//
//  PluginConstantsDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 PluginConstants 纯常量集的完整性，覆盖 Sandbox / Localization /
//           DefaultManifest / Permission / MarketJSON / LanguagePrefix / MarketError /
//           PluginID / JSGlobal / AnalyticsKey。
//

import XCTest
@testable import ZhiYu

// MARK: - PluginConstants 常量完整性测试

final class PluginConstantsDeepTests: XCTestCase {

    /// 验证 Sandbox 限制常量
    func testSandboxConstants() {
        XCTAssertEqual(PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, 0.5)
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeMB, 5)
        XCTAssertGreaterThan(PluginConstants.Sandbox.maxResponseSizeBytes, 0)
    }

    /// 验证 maxResponseSizeBytes = 5MB * 1024 * 1024
    func testSandboxMaxResponseSizeBytesCalculation() {
        let expected = 5 * 1024 * 1024
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeBytes, expected)
    }

    /// 验证 Localization requiredLocales
    func testLocalizationRequiredLocales() {
        let locales = PluginConstants.Localization.requiredLocales
        XCTAssertEqual(locales.count, 2)
        XCTAssertTrue(locales.contains("en"))
        XCTAssertTrue(locales.contains("zh-Hans"))
    }

    /// 验证 DefaultManifest 默认值
    func testDefaultManifestValues() {
        XCTAssertEqual(PluginConstants.DefaultManifest.author, "Local Developer")
        XCTAssertEqual(PluginConstants.DefaultManifest.permissions, ["log", "writeContent"])
        XCTAssertEqual(PluginConstants.DefaultManifest.descriptionEn, "Legacy .js plugin (migrate to .zyplugin format)")
        XCTAssertEqual(PluginConstants.DefaultManifest.idPrefix, "local.")
    }

    /// 验证 Permission 权限字面量
    func testPermissionStrings() {
        XCTAssertEqual(PluginConstants.Permission.network, "network")
        XCTAssertEqual(PluginConstants.Permission.llm, "llm")
        XCTAssertEqual(PluginConstants.Permission.pagesRead, "pages.read")
        XCTAssertEqual(PluginConstants.Permission.writeContent, "writeContent")
    }

    /// 验证 MarketJSON 文件名
    func testMarketJSONFilenames() {
        XCTAssertEqual(PluginConstants.MarketJSON.communityPlugins, "community-plugins.json")
        XCTAssertEqual(PluginConstants.MarketJSON.communityPluginsZhHans, "community-plugins_zh-Hans.json")
        XCTAssertEqual(PluginConstants.MarketJSON.community, "community.json")
        XCTAssertEqual(PluginConstants.MarketJSON.pluginsPathSegment, "plugins")
    }

    /// 验证 LanguagePrefix 标记
    func testLanguagePrefixMarkers() {
        XCTAssertEqual(PluginConstants.LanguagePrefix.zh, "zh")
        XCTAssertEqual(PluginConstants.LanguagePrefix.en, "en")
    }

    /// 验证 MarketError 错误域
    func testMarketErrorDomain() {
        XCTAssertEqual(PluginConstants.MarketError.domain, "PluginMarketService")
        XCTAssertEqual(PluginConstants.MarketError.httpPrefix, "HTTP ")
        XCTAssertEqual(PluginConstants.MarketError.documentsNotFound, L10n.Plugin.Error.documentsNotFound)
    }

    /// 验证 PluginID 前缀
    func testPluginIDPrefix() {
        XCTAssertEqual(PluginConstants.PluginID.officialPrefix, "com.zhiyu.plugin.")
        XCTAssertEqual(PluginConstants.PluginID.v1VersionPrefix, "1.")
    }

    /// 验证 JSGlobal 全局对象名
    func testJSGlobalObjectName() {
        XCTAssertEqual(PluginConstants.JSGlobal.hostBridge, "ZhiYu")
    }

    /// 验证 AnalyticsKey 事件参数 Key
    func testAnalyticsKeys() {
        XCTAssertEqual(PluginConstants.AnalyticsKey.id, "id")
        XCTAssertEqual(PluginConstants.AnalyticsKey.duration, "duration")
        XCTAssertEqual(PluginConstants.AnalyticsKey.error, "error")
    }
}
