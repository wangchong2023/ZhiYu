//
//  L10nSystemTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 System 表 L10n 扩展的 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// System 表 L10n 扩展测试（Shortcuts/Workflow/Coachmark/Reminder）
final class L10nSystemTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Shortcuts_为System() {
        XCTAssertEqual(L10n.Shortcuts.tableName, "System")
    }

    func testTableName_Workflow_为System() {
        XCTAssertEqual(L10n.Workflow.tableName, "System")
    }

    func testTableName_Coachmark_为System() {
        XCTAssertEqual(L10n.Coachmark.tableName, "System")
    }

    func testTableName_Reminder_为System() {
        XCTAssertEqual(L10n.Reminder.tableName, "System")
    }

    // MARK: - Shortcuts 属性 key 存在性

    func testShortcuts_Capture_所有属性返回非Missing值() {
        let values = [
            L10n.Shortcuts.Capture.title,
            L10n.Shortcuts.Capture.description,
            L10n.Shortcuts.Capture.contentTitle,
            L10n.Shortcuts.Capture.logMessage,
            L10n.Shortcuts.Capture.success
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Shortcuts.Capture 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Shortcuts.Capture 属性返回空字符串")
        }
    }

    func testShortcuts_Search_所有属性返回非Missing值() {
        let values = [
            L10n.Shortcuts.Search.title,
            L10n.Shortcuts.Search.description,
            L10n.Shortcuts.Search.queryTitle,
            L10n.Shortcuts.Search.logMessage
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Shortcuts.Search 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Shortcuts.Search 属性返回空字符串")
        }
    }

    func testShortcuts_Stats_所有属性返回非Missing值() {
        let values = [
            L10n.Shortcuts.Stats.title,
            L10n.Shortcuts.Stats.description
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Shortcuts.Stats 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Shortcuts.Stats 属性返回空字符串")
        }
    }

    func testShortcuts_Provider_所有属性返回非Missing值() {
        let values = [
            L10n.Shortcuts.Provider.capturePhrases1,
            L10n.Shortcuts.Provider.capturePhrases2,
            L10n.Shortcuts.Provider.captureShortTitle,
            L10n.Shortcuts.Provider.searchPhrases1,
            L10n.Shortcuts.Provider.searchPhrases2,
            L10n.Shortcuts.Provider.searchShortTitle,
            L10n.Shortcuts.Provider.statsPhrases1,
            L10n.Shortcuts.Provider.statsPhrases2,
            L10n.Shortcuts.Provider.statsShortTitle
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Shortcuts.Provider 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Shortcuts.Provider 属性返回空字符串")
        }
    }

    // MARK: - Shortcuts trf 参数化方法

    func testShortcuts_Capture_pageTitle_返回非Missing() {
        let result = L10n.Shortcuts.Capture.pageTitle("测试摘要")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Capture.pageTitle 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testShortcuts_Search_success_返回非Missing() {
        let result = L10n.Shortcuts.Search.success("测试查询")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Search.success 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testShortcuts_Stats_success_返回非Missing() {
        let result = L10n.Shortcuts.Stats.success(10)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Stats.success 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Workflow 属性 key 存在性

    func testWorkflow_所有属性返回非Missing值() {
        let values = [
            L10n.Workflow.accessDeniedMessage,
            L10n.Workflow.noTasksFoundMessage
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Workflow 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Workflow 属性返回空字符串")
        }
    }

    // MARK: - Workflow trf 参数化方法

    func testWorkflow_syncingMessage_返回非Missing() {
        let result = L10n.Workflow.syncingMessage(5)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "syncingMessage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testWorkflow_sourceNotes_返回非Missing() {
        let result = L10n.Workflow.sourceNotes("测试标题")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "sourceNotes 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testWorkflow_syncSuccessMessage_返回非Missing() {
        let result = L10n.Workflow.syncSuccessMessage(3)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "syncSuccessMessage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testWorkflow_syncErrorMessage_返回非Missing() {
        let result = L10n.Workflow.syncErrorMessage("测试错误")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "syncErrorMessage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Coachmark 属性 key 存在性

    func testCoachmark_所有属性返回非Missing值() {
        let values = [
            L10n.Coachmark.graphDiscoveryTitle,
            L10n.Coachmark.graphDiscoveryDesc,
            L10n.Coachmark.graphDiscoveryAction
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Coachmark 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Coachmark 属性返回空字符串")
        }
    }

    // MARK: - Reminder 属性 key 存在性

    func testReminder_所有属性返回非Missing值() {
        let value = L10n.Reminder.noListAvailableMessage
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Reminder 属性返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Reminder 属性返回空字符串")
    }
}
