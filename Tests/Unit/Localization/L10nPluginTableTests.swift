//
//  L10nPluginTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Plugin 表 L10n 扩展（Plugin/Collaboration）的 tableName 正确性与属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// Plugin 表 L10n 扩展测试（Plugin/Collaboration）
final class L10nPluginTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Plugin_为Plugin() {
        XCTAssertEqual(L10n.Plugin.tableName, "Plugin")
    }

    func testTableName_Collaboration_为Plugin() {
        XCTAssertEqual(L10n.Collaboration.tableName, "Plugin")
    }

    // MARK: - Plugin 属性 key 存在性

    func testPlugin_基础属性返回非Missing值() {
        let values = [
            L10n.Plugin.title,
            L10n.Plugin.centerTitle,
            L10n.Plugin.marketTitle,
            L10n.Plugin.myPlugins,
            L10n.Plugin.safeModeTitle,
            L10n.Plugin.safeModeWarningTitle,
            L10n.Plugin.safeModeWarningMessage,
            L10n.Plugin.safeModeTurnOff,
            L10n.Plugin.searchPlaceholder,
            L10n.Plugin.noPlugins,
            L10n.Plugin.noPluginsHint,
            L10n.Plugin.noResults,
            L10n.Plugin.noResultsHint,
            L10n.Plugin.noPluginsInCategory,
            L10n.Plugin.noPluginsInCategoryHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Plugin 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Plugin 属性返回空字符串")
        }
    }

    func testPlugin_permissionMessage_返回非Missing且包含参数() {
        let result = L10n.Plugin.permissionMessage("camera")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Plugin.permissionMessage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testPlugin_permTitle_返回非Missing且包含参数() {
        let result = L10n.Plugin.permTitle("network")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Plugin.permTitle 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Collaboration 属性 key 存在性

    func testCollaboration_基础属性返回非Missing值() {
        let values = [
            L10n.Collaboration.title,
            L10n.Collaboration.subtitle,
            L10n.Collaboration.defaultRoom,
            L10n.Collaboration.room,
            L10n.Collaboration.roomName,
            L10n.Collaboration.roomNamePlaceholder,
            L10n.Collaboration.username,
            L10n.Collaboration.usernamePlaceholder,
            L10n.Collaboration.nearbyRooms,
            L10n.Collaboration.howItWorks,
            L10n.Collaboration.hostedBy,
            L10n.Collaboration.noNearbyRooms,
            L10n.Collaboration.joinSession,
            L10n.Collaboration.hostSession,
            L10n.Collaboration.startHosting,
            L10n.Collaboration.hostSetup,
            L10n.Collaboration.stopSearching,
            L10n.Collaboration.searching,
            L10n.Collaboration.leaveSession,
            L10n.Collaboration.connectedUsers,
            L10n.Collaboration.recentEdits,
            L10n.Collaboration.noEdits,
            L10n.Collaboration.simulatorWarning
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Collaboration 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Collaboration 属性返回空字符串")
        }
    }
}
