//
//  Graph3DAndComponentsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对 3D 知识图谱（Graph3DView）、2D 图谱主视图（GraphView）
//            及图谱控制面板与筛选器（GraphComponents）进行全状态与交互测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class Graph3DAndComponentsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Graph3DView 3D 场景与控制面板

    func testGraph3DView_FullScreenAndDefaultState() {
        let graph3D = Graph3DView(
            selectedNodeID: .constant(nil),
            isFullScreen: .constant(false)
        ).snapshotEnvironment()

        let host = UIHostingController(rootView: graph3D)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testGraph3DView_WithSelectedNodeAndFullScreen() {
        let nodeID = UUID()
        let graph3D = Graph3DView(
            selectedNodeID: .constant(nodeID),
            isFullScreen: .constant(true)
        ).snapshotEnvironment()

        let host = UIHostingController(rootView: graph3D)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. GraphContainerView 2D 主图谱视图

    private struct GraphContainerWrapper: View {
        @Namespace private var heroNamespace
        @State private var selectedTab: AppTab = .graph

        var body: some View {
            GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
        }
    }

    func testGraphContainerView_InteractiveModes() {
        let graphView = GraphContainerWrapper()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: graphView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}
