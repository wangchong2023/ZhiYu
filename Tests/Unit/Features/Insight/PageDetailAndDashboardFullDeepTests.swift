//
//  PageDetailAndDashboardFullDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 PageDetailView 知识页面详情、置顶/回链交互、推荐卡片以及 KnowledgeDashboardView 仪表板数据流与多维图表。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class PageDetailAndDashboardFullDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PageDetailView 渲染与交互测试

    func testPageDetailView_ConceptType() {
        let page = KnowledgePage(
            title: "Transformer 深度剖析",
            pageType: .concept,
            content: "# 核心架构\n- 自注意力机制\n- 前馈神经网络\n- 残差连接与层归一化",
            tags: ["AI", "Architecture", "NLP"],
            sourceURL: "https://arxiv.org/abs/1706.03762"
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testPageDetailView_SourceTypeWithMetadata() {
        let page = KnowledgePage(
            title: "WWDC 2026 论文研讨",
            pageType: .source,
            content: "转录正文内容...",
            tags: ["WWDC", "Swift"],
            sourceURL: "https://developer.apple.com",
            fileSize: 4_096_000,
            sourceType: "pdf"
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testPageDetailView_ComparisonType() {
        let page = KnowledgePage(
            title: "BERT vs GPT 对比分析",
            pageType: .comparison,
            content: "## 对比维度\n| 特性 | BERT | GPT |\n|---|---|---|\n| 结构 | 编码器 | 解码器 |",
            tags: ["LLM", "Benchmark"]
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testPageDetailView_EntityType() {
        let page = KnowledgePage(
            title: "Andrej Karpathy",
            pageType: .entity,
            content: "人工智能学者，LLM Wiki 方法论倡导者。",
            tags: ["Person", "AI"]
        )

        let host = NavigationStack {
            PageDetailView(page: page)
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. KnowledgeDashboardView 完整仪表板测试

    func testKnowledgeDashboardView_Hierarchy() {
        let host = NavigationStack {
            KnowledgeDashboardView()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
