//
//  GraphCanvasInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：知识图谱视图 (GraphView)、空状态占位与控制条的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class GraphCanvasInteractiveSnapshots: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 图谱空数据占位引导快照

    func testGraphEmptyStateView_RendersStartBuildingCard() {
        let view = GraphEmptyStateView(selectedTab: .constant(.knowledge))
            .padding()
            .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 图谱主视图入口快照

    struct GraphWrapperView: View {
        @Namespace private var namespace
        var body: some View {
            NavigationStack {
                GraphContainerView(heroNamespace: namespace, selectedTab: .constant(.knowledge))
            }
        }
    }

    func testGraphView_InitialState_RendersToolbarAndCanvas() {
        let view = GraphWrapperView()
            .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
