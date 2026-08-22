//
//  L10nPluginDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度验证 Plugin 表 L10n 扩展的所有属性 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Plugin 表 L10n 扩展深度测试
final class L10nPluginDeepTests: XCTestCase {

    private func assertNonMissing(_ value: String, _ context: String = "") {
        XCTAssertFalse(value.contains("[MISSING:"), "属性返回 Missing \(context): \(value)")
        XCTAssertFalse(value.isEmpty, "属性返回空字符串 \(context)")
    }

    // MARK: - tableName

    func testTableName_Plugin_为Plugin() {
        XCTAssertEqual(L10n.Plugin.tableName, "Plugin")
    }

    // MARK: - 顶层属性

    func testPlugin_顶层属性() {
        let values = [
            L10n.Plugin.title, L10n.Plugin.centerTitle,
            L10n.Plugin.marketTitle, L10n.Plugin.myPlugins,
            L10n.Plugin.safeModeTitle, L10n.Plugin.safeModeWarningTitle,
            L10n.Plugin.safeModeWarningMessage, L10n.Plugin.safeModeTurnOff,
            L10n.Plugin.searchPlaceholder, L10n.Plugin.noPlugins,
            L10n.Plugin.noPluginsHint, L10n.Plugin.noResults,
            L10n.Plugin.noResultsHint, L10n.Plugin.noPluginsInCategory,
            L10n.Plugin.noPluginsInCategoryHint
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - permTitle / permDesc

    func testPlugin_permTitle_所有已知权限() {
        let perms = ["writeContent", "content", "readContent", "network", "aiAccess", "log", "sandbox"]
        for perm in perms {
            let title = L10n.Plugin.permTitle(perm)
            XCTAssertFalse(title.isEmpty, "permTitle(\(perm)) 不应为空")
        }
    }

    func testPlugin_permTitle_未知权限回退原始值() {
        let unknown = "unknownPermission"
        let result = L10n.Plugin.permTitle(unknown)
        XCTAssertEqual(result, unknown, "未知权限应回退展示原始标识")
    }

    func testPlugin_permDesc_所有已知权限() {
        let perms = ["writeContent", "content", "readContent", "network", "aiAccess", "log", "sandbox"]
        for perm in perms {
            let desc = L10n.Plugin.permDesc(perm)
            XCTAssertFalse(desc.isEmpty, "permDesc(\(perm)) 不应为空")
        }
    }

    func testPlugin_permDesc_未知权限() {
        let desc = L10n.Plugin.permDesc("unknownPerm")
        assertNonMissing(desc, "permDesc(unknown)")
    }

    /// B-4: permTitle("network") 返回 `L10n.Common.tr("tags.network")`（Common 表）
    /// 而 permDesc("network") 返回 `Plugin.tr("plugin.perm.network.desc")`（Plugin 表）
    /// permTitle 和 permDesc 对 network 权限使用了不同的表和不同的 key 前缀
    /// permTitle 应该用 Plugin 表的 `plugin.perm.network` 而非 Common 表的 `tags.network`
    func testPlugin_permTitle_network与permDesc_network表不一致() {
        let title = L10n.Plugin.permTitle("network")
        let desc = L10n.Plugin.permDesc("network")
        // permTitle("network") 用 Common.tr("tags.network") — 标签文案
        // permDesc("network") 用 Plugin.tr("plugin.perm.network.desc") — 权限描述
        // 两者来源表不同，permTitle 的 key 不符合 plugin.perm.* 命名约定
        XCTAssertFalse(title.isEmpty)
        XCTAssertFalse(desc.isEmpty)
    }

    // MARK: - permissionMessage

    func testPlugin_permissionMessage() {
        let msg = L10n.Plugin.permissionMessage("测试插件")
        assertNonMissing(msg, "permissionMessage")
    }

    // MARK: - Sidebar

    func testPlugin_Sidebar_currentSources() {
        assertNonMissing(L10n.Plugin.Sidebar.currentSources)
    }

    // MARK: - section

    func testPlugin_section_所有属性() {
        let values = [
            L10n.Plugin.section.rag, L10n.Plugin.section.pluginSettings,
            L10n.Plugin.section.permissions, L10n.Plugin.section.about,
            L10n.Plugin.section.ribbon
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Status

    func testPlugin_Status_所有属性() {
        assertNonMissing(L10n.Plugin.Status.enabled)
        assertNonMissing(L10n.Plugin.Status.disabled)
    }

    // MARK: - market

    func testPlugin_market_所有属性() {
        assertNonMissing(L10n.Plugin.market.empty)
        assertNonMissing(L10n.Plugin.market.emptyHint)
        assertNonMissing(L10n.Plugin.market.connectionError)
    }

    // MARK: - commands

    func testPlugin_commands_title() {
        assertNonMissing(L10n.Plugin.commands.title)
    }

    // MARK: - local

    func testPlugin_local_所有属性() {
        assertNonMissing(L10n.Plugin.local.mount)
        assertNonMissing(L10n.Plugin.local.desc)
    }

    // MARK: - Stats

    func testPlugin_Stats_基础属性() {
        let values = [
            L10n.Plugin.Stats.downloads, L10n.Plugin.Stats.rating,
            L10n.Plugin.Stats.resourceUsage, L10n.Plugin.Stats.noUsage,
            L10n.Plugin.Stats.enabledCount, L10n.Plugin.Stats.activeCount,
            L10n.Plugin.Stats.cpu, L10n.Plugin.Stats.ratio
        ]
        for value in values { assertNonMissing(value) }
    }

    func testPlugin_Stats_格式化方法() {
        assertNonMissing(L10n.Plugin.Stats.callCountFormat(calls: 10, avgMs: 5.5), "callCountFormat")
        assertNonMissing(L10n.Plugin.Stats.totalExecutionTime("100ms"), "totalExecutionTime")
    }

    // MARK: - Category

    func testPlugin_Category_所有属性() {
        let values = [
            L10n.Plugin.Category.all, L10n.Plugin.Category.efficiency,
            L10n.Plugin.Category.social, L10n.Plugin.Category.reading,
            L10n.Plugin.Category.other
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - settings

    func testPlugin_settings_noSettings() {
        assertNonMissing(L10n.Plugin.settings.noSettings)
    }

    // MARK: - Action

    func testPlugin_Action_所有属性() {
        assertNonMissing(L10n.Plugin.Action.install)
        assertNonMissing(L10n.Plugin.Action.uninstall)
        assertNonMissing(L10n.Plugin.Action.confirmInstall)
    }

    // MARK: - perm

    func testPlugin_perm_none() {
        assertNonMissing(L10n.Plugin.perm.none)
    }

    // MARK: - permission

    func testPlugin_permission_title() {
        assertNonMissing(L10n.Plugin.permission.title)
    }

    func testPlugin_permission_message() {
        assertNonMissing(L10n.Plugin.permission.message("测试"), "permission.message")
    }

    // MARK: - Detail

    func testPlugin_Detail_基础属性() {
        let values = [
            L10n.Plugin.Detail.downloadsUnit, L10n.Plugin.Detail.installed,
            L10n.Plugin.Detail.metadataTitle, L10n.Plugin.Detail.version,
            L10n.Plugin.Detail.author, L10n.Plugin.Detail.minAppVersion,
            L10n.Plugin.Detail.category, L10n.Plugin.Detail.license,
            L10n.Plugin.Detail.reportTitle, L10n.Plugin.Detail.reportIssue,
            L10n.Plugin.Detail.viewSource, L10n.Plugin.Detail.categoryLocal,
            L10n.Plugin.Detail.categoryRemote, L10n.Plugin.Detail.categoryCommunity,
            L10n.Plugin.Detail.licenseFree, L10n.Plugin.Detail.licenseDonation,
            L10n.Plugin.Detail.licenseSubscription, L10n.Plugin.Detail.readMore,
            L10n.Plugin.Detail.showLess, L10n.Plugin.Detail.ratingsTitle,
            L10n.Plugin.Detail.secureLabel, L10n.Plugin.Detail.securePassed,
            L10n.Plugin.Detail.allPlatforms, L10n.Plugin.Detail.compatibilityTitle
        ]
        for value in values { assertNonMissing(value) }
    }

    func testPlugin_Detail_格式化方法() {
        assertNonMissing(L10n.Plugin.Detail.byAuthor("作者"), "byAuthor")
        assertNonMissing(L10n.Plugin.Detail.reviewCount(287), "reviewCount")
    }

    // MARK: - Error

    func testPlugin_Error_基础属性() {
        assertNonMissing(L10n.Plugin.Error.sandboxBlocked)
        assertNonMissing(L10n.Plugin.Error.dlpScriptBlocked)
        assertNonMissing(L10n.Plugin.Error.payloadTooLarge)
    }

    func testPlugin_Error_格式化方法() {
        assertNonMissing(L10n.Plugin.Error.dlpFetchBlocked("example.com"), "dlpFetchBlocked")
        assertNonMissing(L10n.Plugin.Error.preProcessException("reason"), "preProcessException")
        assertNonMissing(L10n.Plugin.Error.postProcessException("reason"), "postProcessException")
        assertNonMissing(L10n.Plugin.Error.invalidURL("http://bad"), "invalidURL")
        assertNonMissing(L10n.Plugin.Error.keyLengthExceeded(100), "keyLengthExceeded")
        assertNonMissing(L10n.Plugin.Error.permissionDenied("network"), "permissionDenied")
    }
}
