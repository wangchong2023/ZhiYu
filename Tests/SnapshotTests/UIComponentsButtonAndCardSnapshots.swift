//
//  UIComponentsButtonAndCardSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 AppButton、AppCard、AppChip、AppMetricCard、StatCard 等核心基础视觉组件的快照渲染与暗黑模式。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class UIComponentsButtonAndCardSnapshots: XCTestCase {

    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 按钮组件变体快照

    func testAppButtons_AllVariantsSnapshot() {
        let view = VStack(spacing: DesignSystem.medium) {
            AppPrimaryButton(title: "主要操作", icon: "arrow.right", action: {})
            AppBorderedButton(title: "次要操作", icon: "gear", action: {})
            AppCapsuleButton(title: "胶囊标签", icon: "tag.fill")
        }
        .padding(DesignSystem.medium)
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    // MARK: - 2. 卡片与指标组件快照

    func testAppMetricCards_Snapshot() {
        let view = VStack(spacing: DesignSystem.medium) {
            AppMetricCard(
                title: "知识页面总数",
                value: "1,248",
                icon: "doc.text",
                color: .blue
            )
            StatCard(
                title: "合成报告",
                value: "36",
                icon: "sparkles",
                color: .blue
            )
        }
        .padding(DesignSystem.medium)
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
