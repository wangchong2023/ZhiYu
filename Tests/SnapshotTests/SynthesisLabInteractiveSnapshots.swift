//
//  SynthesisLabInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：AI 合成实验室 (SynthesisView)、异常状态卡片与合成文档行的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class SynthesisLabInteractiveSnapshots: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 合成主视图入口（分类模板与空文档列表）

    func testSynthesisView_EmptyState_RendersCategorySections() {
        let view = SynthesisView(
            selection: .constant(.tool(.synthesis)),
            selectedTab: .constant(.synthesis)
        )
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 合成结果解析降级友好错误卡片

    func testSynthesisErrorStateView_RendersGracefulFallbackCard() {
        let view = SynthesisErrorStateView(
            docType: .mindmap,
            onSwitchToText: {},
            onRetry: {}
        )
        .padding()
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)))
    }

    // MARK: - 3. 合成文档行项渲染（思维导图与报告卡片）

    func testSynthesisDocRow_NormalAndEditMode_RendersCorrectly() {
        let doc = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .mindmap,
            name: "微服务架构演进脑图",
            content: "mindmap\n  root((微服务))\n    DDD\n    EventSourcing",
            createdAt: Date(),
            size: 256,
            sourcePageIDs: []
        )

        let view = VStack(spacing: Spacing.medium) {
            SynthesisDocRow(
                doc: doc,
                type: .mindmap,
                editMode: .inactive,
                isSelected: false,
                onTap: {},
                onRename: {},
                onDelete: {}
            )

            SynthesisDocRow(
                doc: doc,
                type: .mindmap,
                editMode: .active,
                isSelected: true,
                onTap: {},
                onRename: {},
                onDelete: {}
            )
        }
        .padding()
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotGraphViewportSize)))
    }
}
