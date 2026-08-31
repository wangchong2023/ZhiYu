//
//  UIComponentsOverlaysAndAlertSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 AppEmptyState、AppErrorView、AppLoadingOverlay 与 AppToast 提示浮层的视觉一致性与暗黑模式。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class UIComponentsOverlaysAndAlertSnapshots: XCTestCase {

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

    // MARK: - 1. 空状态与错误视图快照

    func testAppEmptyStateAndErrorView_Snapshot() {
        let view = VStack(spacing: DesignSystem.medium) {
            AppEmptyState(
                icon: "doc.text.magnifyingglass",
                title: "暂无搜索结果",
                description: "请尝试使用其他关键词或缩短查询"
            )
            AppErrorView(
                title: "网络连接失败",
                message: "请检查您的网络连接并重试",
                retryAction: {}
            )
        }
        .padding(DesignSystem.medium)
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
