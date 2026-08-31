//
//  UIComponentsEditorAndToolbarSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 AdaptiveTextEditor、EditorToolbar 与 Markdown 渲染工具栏的快照视觉一致性。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class UIComponentsEditorAndToolbarSnapshots: XCTestCase {

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

    // MARK: - 1. 自适应编辑器快照

    func testAdaptiveTextEditor_Snapshot() {
        let view = VStack {
            AdaptiveTextEditor(
                text: .constant("# 知识架构标题\n\n- 第一条核心规则\n- 第二条核心规则")
            )
        }
        .padding(DesignSystem.medium)
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }
}
