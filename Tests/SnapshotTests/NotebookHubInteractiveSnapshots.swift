//
//  NotebookHubInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：笔记本中心 (NotebookHubView)、卡片与网格列表的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class NotebookHubInteractiveSnapshots: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 笔记本中心主页快照

    func testNotebookHubView_MainLayout_RendersCorrectly() {
        let view = NavigationStack {
            NotebookHubView()
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 笔记本卡片组件快照

    func testNotebookCard_NormalState_RendersIconAndTitle() {
        let vault = Vault(
            id: UUID(),
            name: "AI 智能体研发笔记",
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 12,
            icon: "🧠",
            description: "涵盖 Karpathy LLM Wiki、RAG 向量检索与多模态架构设计"
        )
        let view = NotebookCard(notebook: vault, action: {})
            .frame(width: DesignSystem.Metrics.snapshotNotebookCardWidth)
            .padding()
            .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotNotebookCardHeight)))
    }
}
