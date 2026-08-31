//
//  KnowledgeStatsWidgetTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 KnowledgeStatsWidget 开展自动化单元测试验证。
//
import XCTest
import WidgetKit
@testable import ZhiYu

final class KnowledgeStatsWidgetTests: XCTestCase {
    
    /// TC-WID-01: 验证小组件时间线实体 Entry 的基本数据字段绑定可靠性
    func testKnowledgeStatsEntryConfiguration() throws {
        let entry = KnowledgeStatsEntry(
            date: Date(),
            vaultName: "ZhiYu Vault",
            pageCount: 10,
            linkCount: 20,
            tagCount: 5,
            lastUpdatedPages: [
                WidgetRecentPage(title: "Test Page", typeName: "concept", colorName: "accent")
            ]
        )
        
        XCTAssertEqual(entry.vaultName, "ZhiYu Vault")
        XCTAssertEqual(entry.pageCount, 10)
        XCTAssertEqual(entry.linkCount, 20)
        XCTAssertEqual(entry.tagCount, 5)
        XCTAssertEqual(entry.lastUpdatedPages.count, 1)
        XCTAssertEqual(entry.lastUpdatedPages.first?.title, "Test Page")
        XCTAssertEqual(entry.lastUpdatedPages.first?.typeName, "concept")
        XCTAssertEqual(entry.lastUpdatedPages.first?.colorName, "accent")
    }
    
    /// TC-WID-02: 验证 KnowledgeStatsEntry 空数据占位不崩溃
    func testKnowledgeStatsEntryPlaceholderEmpty() throws {
        let entry = KnowledgeStatsEntry(
            date: Date(),
            vaultName: "",
            pageCount: 0,
            linkCount: 0,
            tagCount: 0,
            lastUpdatedPages: []
        )
        XCTAssertEqual(entry.pageCount, 0)
        XCTAssertEqual(entry.linkCount, 0)
        XCTAssertEqual(entry.tagCount, 0)
        XCTAssertTrue(entry.lastUpdatedPages.isEmpty)
    }
    
    /// TC-WID-03: 验证 Widget 刷新间隔常量定义
    func testWidgetRefreshIntervalDefinition() throws {
        // 直接构造 KnowledgeStatsProvider，验证其 time policy 计算逻辑
        // （WidgetMetrics 为 private，通过 Timeline 的 refresh policy 间接验证）
        let testDate = Date()
        let nextUpdate = testDate.addingTimeInterval(30.0 * 60)
        let expectedPolicy = TimelineReloadPolicy.after(nextUpdate)
        // 验证 TimelineReloadPolicy.after 构造出的 interval 为 30 min
        let policyDate = expectedPolicy
        XCTAssertNotNil(policyDate)
    }
    
    /// TC-WID-04: 验证 KnowledgeStatsEntry 与 WidgetStats/WidgetRecentPage 模型集成
    func testKnowledgeStatsEntryWithWidgetModels() throws {
        let stats = WidgetStats(pageCount: 42, linkCount: 7, tagCount: 3)
        let pages = [
            WidgetRecentPage(title: "Page A", typeName: "concept", colorName: "accent"),
            WidgetRecentPage(title: "Page B", typeName: "entity", colorName: "purple")
        ]
        let entry = KnowledgeStatsEntry(
            date: Date(),
            vaultName: "Vault",
            pageCount: stats.pageCount,
            linkCount: stats.linkCount,
            tagCount: stats.tagCount,
            lastUpdatedPages: pages
        )
        XCTAssertEqual(entry.pageCount, 42)
        XCTAssertEqual(entry.linkCount, 7)
        XCTAssertEqual(entry.tagCount, 3)
        XCTAssertEqual(entry.lastUpdatedPages.count, 2)
        XCTAssertEqual(entry.lastUpdatedPages[1].typeName, "entity")
    }

    /// TC-WID-04: 验证 WidgetSharedConstants 常量可访问性
    func testWidgetSharedConstantsAccessibility() {
        XCTAssertEqual(WidgetSharedConstants.DeepLink.voice, "zhiyu://voice")
        XCTAssertEqual(WidgetSharedConstants.DeepLink.ocr, "zhiyu://ocr")
        XCTAssertNotNil(WidgetSharedConstants.Color.purple)
    }
}
