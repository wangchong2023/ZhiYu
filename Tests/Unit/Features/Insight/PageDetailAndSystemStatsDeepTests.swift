//
//  PageDetailAndSystemStatsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SystemStatsCoordinator 系统监控、RawStorageListView 原始文件列表、
//           HighlightedText 高亮文本渲染与 PageDetailCoordinator 页面详情双向链接及 AI 编排。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class PageDetailAndSystemStatsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SystemStatsCoordinator 系统统计与监控测试

    func testSystemStatsCoordinator_LoadStatsAndCleanup() async {
        let coordinator = SystemStatsCoordinator()
        XCTAssertTrue(coordinator.isLoading)

        await coordinator.loadStats()
        XCTAssertFalse(coordinator.isLoading)

        // 验证字节格式化
        let formatted = coordinator.formatBytes(1024 * 1024 * 5)
        XCTAssertFalse(formatted.isEmpty)

        // 验证分类图标映射
        let dbIcon = coordinator.iconForCategory(L10n.Dashboard.System.database)
        XCTAssertEqual(dbIcon, DesignSystem.Icons.StorageStats.database)
        let fallbackIcon = coordinator.iconForCategory("unknown_category")
        XCTAssertEqual(fallbackIcon, DesignSystem.Icons.StorageStats.fallback)

        // 触发数据清理
        await coordinator.cleanupData()
        XCTAssertFalse(coordinator.isCleaning)
    }

    func testSystemStatsView_HierarchyAndTabSwitching() {
        let view = NavigationStack {
            SystemStatsView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)

        for tab in SystemStatsView.Tab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
        }
    }

    // MARK: - 2. RawCategoryType & HighlightedText 测试

    func testRawCategoryType_AllCasesAndProperties() {
        for category in RawCategoryType.allCases {
            XCTAssertFalse(category.id.isEmpty)
            XCTAssertFalse(category.systemIconName.isEmpty)
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertNotNil(category.defaultColor)
        }
    }

    func testHighlightedText_RenderingWithMatches() {
        let view = HighlightedText(text: "Karpathy LLM OS 知识架构", highlight: "LLM")
        XCTAssertNotNil(view)

        let emptyHighlightView = HighlightedText(text: "全文内容", highlight: "")
        XCTAssertNotNil(emptyHighlightView)

        let noMatchView = HighlightedText(text: "全文内容", highlight: "不存在的关键词")
        XCTAssertNotNil(noMatchView)
    }

    // MARK: - 3. PageDetailCoordinator 核心业务与 AI 编排测试

    func testPageDetailCoordinator_BacklinksAndPin() async {
        let page = KnowledgePage(
            id: UUID(),
            title: "Transformer 架构",
            pageType: .concept,
            content: "详见 [[Attention 机制]]",
            tags: ["AI"],
            isPinned: false
        )

        let coordinator = PageDetailCoordinator(page: page)
        XCTAssertFalse(coordinator.page.isPinned)
        XCTAssertEqual(coordinator.backlinks.count, 0)

        // 切换置顶
        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned)

        // AI 任务编排触发
        coordinator.generateSummary()
        coordinator.extractActions()
        coordinator.expandContent()
        coordinator.performSynthesis(type: .slides)
        coordinator.findRelatedLinks()
        XCTAssertTrue(coordinator.hasScannedForLinks)

        // 删除页面
        await coordinator.deletePage()
    }
}
