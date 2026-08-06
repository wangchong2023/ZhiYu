//
//  L10nInsightTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Insight 表 L10n 扩展的 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Insight 表 L10n 扩展测试（Insight）
final class L10nInsightTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Insight_为Insight() {
        XCTAssertEqual(L10n.Insight.tableName, "Insight")
    }

    // MARK: - Insight 属性 key 存在性

    func testInsight_Weekly_所有属性返回非Missing值() {
        let value = L10n.Insight.Weekly.aiAnalysis
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Insight.Weekly 属性返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Insight.Weekly 属性返回空字符串")
    }

    func testInsight_InsightSection_Daily_所有属性返回非Missing值() {
        let values = [
            L10n.Insight.InsightSection.Daily.noUpdate,
            L10n.Insight.InsightSection.Daily.systemPrompt
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Insight.InsightSection.Daily 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Insight.InsightSection.Daily 属性返回空字符串")
        }
    }

    func testInsight_InsightSection_Weekly_所有属性返回非Missing值() {
        let value = L10n.Insight.InsightSection.Weekly.systemPrompt
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Insight.InsightSection.Weekly 属性返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Insight.InsightSection.Weekly 属性返回空字符串")
    }

    func testInsight_Medal_基础属性返回非Missing值() {
        let values = [
            L10n.Insight.Medal.totalEarned,
            L10n.Insight.Medal.progress,
            L10n.Insight.Medal.congrats
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Insight.Medal 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Insight.Medal 属性返回空字符串")
        }
    }

    func testInsight_Medal_Category_所有属性返回非Missing值() {
        let values = [
            L10n.Insight.Medal.Category.explore,
            L10n.Insight.Medal.Category.accumulation,
            L10n.Insight.Medal.Category.connection
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Insight.Medal.Category 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Insight.Medal.Category 属性返回空字符串")
        }
    }

    func testInsight_Medal_Wall_所有属性返回非Missing值() {
        let value = L10n.Insight.Medal.Wall.title
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Insight.Medal.Wall 属性返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Insight.Medal.Wall 属性返回空字符串")
    }

    func testInsight_Report_所有属性返回非Missing值() {
        let values = [
            L10n.Insight.Report.title,
            L10n.Insight.Report.appName,
            L10n.Insight.Report.footer
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Insight.Report 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Insight.Report 属性返回空字符串")
        }
    }

    func testInsight_dateCalculationFailed_返回非Missing值() {
        let value = L10n.Insight.dateCalculationFailed
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Insight.dateCalculationFailed 属性返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Insight.dateCalculationFailed 属性返回空字符串")
    }

    // MARK: - Insight trf 参数化方法

    func testInsight_Report_nodeCount_返回非Missing() {
        let result = L10n.Insight.Report.nodeCount(42)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Report.nodeCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }
}
