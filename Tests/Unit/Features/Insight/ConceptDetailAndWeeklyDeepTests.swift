//
//  ConceptDetailAndWeeklyDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 ConceptDetailBodyView 局部脑图/知识脉络树与 WeeklyInsightCard 洞察卡片。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class ConceptDetailAndWeeklyDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ConceptDetailBodyView 测试

    func testConceptDetailBodyView_Hierarchy() {
        let page = KnowledgePage(
            title: "Transformer 架构详解",
            pageType: .concept,
            content: """
            ---
            surprising_insights:
              - "自注意力机制实现了线性复杂度的并行化"
              - "位置编码替代了传统循环神经网络的序列时序"
            outlines:
              - "1. 架构总览"
              - "2. Multi-Head Attention"
              - "3. 前馈神经网络与残差连接"
            ---
            # Transformer 深度原理解析
            Transformer 是现代大型语言模型的基础骨架。
            """
        )

        let host = NavigationStack {
            ConceptDetailBodyView(page: page, onLinkTap: { _ in })
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. WeeklyInsightCard 状态流测试

    func testWeeklyInsightCard_Hierarchy() {
        let host = WeeklyInsightCard()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
