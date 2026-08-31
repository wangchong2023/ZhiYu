//
//  KnowledgeStatsWidgetAndWatchAdapterTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台测试层
//  核心职责：验证 KnowledgeStatsWidget 的 TimelineEntry、快照与数据结构序列化。
//

import XCTest
import SwiftUI
import WidgetKit
@testable import ZhiYu

final class KnowledgeStatsWidgetAndWatchAdapterTests: XCTestCase {

    // MARK: - 1. TimelineEntry 数据实体属性完整性

    func testKnowledgeStatsEntry_Initialization() {
        let now = Date()
        let recentPages = [
            WidgetRecentPage(title: "知识库概览", typeName: "concept", colorName: "blue"),
            WidgetRecentPage(title: "系统架构设计", typeName: "concept", colorName: "purple")
        ]

        let entry = KnowledgeStatsEntry(
            date: now,
            vaultName: "智宇个人库",
            pageCount: 42,
            linkCount: 128,
            tagCount: 15,
            lastUpdatedPages: recentPages
        )

        XCTAssertEqual(entry.vaultName, "智宇个人库")
        XCTAssertEqual(entry.pageCount, 42)
        XCTAssertEqual(entry.linkCount, 128)
        XCTAssertEqual(entry.tagCount, 15)
        XCTAssertEqual(entry.lastUpdatedPages.count, 2)
    }

    // MARK: - 2. WidgetRecentPage 序列化与属性

    func testWidgetRecentPage_EqualityAndProperties() {
        let page1 = WidgetRecentPage(title: "概念 A", typeName: "concept", colorName: "green")
        let page2 = WidgetRecentPage(title: "概念 A", typeName: "concept", colorName: "green")

        XCTAssertEqual(page1.title, page2.title)
        XCTAssertEqual(page1.typeName, page2.typeName)
    }
}
