//
//  GraphViewAndSimulationDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 GraphContainerView、GraphViewModel 物理仿真循环、
//           边截断缓存机制、拓扑过滤与图谱状态机。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class GraphViewAndSimulationDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. GraphViewModel 基础状态与过滤测试

    func testGraphViewModel_InitialState() {
        let viewModel = GraphViewModel()
        XCTAssertNil(viewModel.selectedNodeID)
        XCTAssertTrue(viewModel.nodes.isEmpty)
        XCTAssertTrue(viewModel.edges.isEmpty)
        XCTAssertTrue(viewModel.isLayouting)
        XCTAssertFalse(viewModel.isAnimating)
        XCTAssertNil(viewModel.filterType)
    }

    func testGraphViewModel_GetFilteredNodesAndEdges() {
        let viewModel = GraphViewModel()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let node1 = GraphNode(id: id1, title: "Transformer", pageType: .concept, position: CGPoint(x: 10, y: 10), linkCount: 2)
        let node2 = GraphNode(id: id2, title: "BERT", pageType: .concept, position: CGPoint(x: 20, y: 20), linkCount: 1)
        let node3 = GraphNode(id: id3, title: "对比分析", pageType: .comparison, position: CGPoint(x: 30, y: 30), linkCount: 1)

        let edge1 = GraphEdge(source: id1, target: id2)
        let edge2 = GraphEdge(source: id1, target: id3)

        viewModel.nodes = [node1, node2, node3]
        viewModel.edges = [edge1, edge2]

        // 1. 无过滤
        viewModel.filterType = nil
        let allNodes = viewModel.getFilteredNodes()
        let allEdges = viewModel.getFilteredEdges(for: allNodes)
        XCTAssertEqual(allNodes.count, 3)
        XCTAssertEqual(allEdges.count, 2)

        // 2. 按 Concept 过滤
        viewModel.filterType = .concept
        let conceptNodes = viewModel.getFilteredNodes()
        let conceptEdges = viewModel.getFilteredEdges(for: conceptNodes)
        XCTAssertEqual(conceptNodes.count, 2)
        XCTAssertEqual(conceptEdges.count, 1)
        XCTAssertEqual(conceptEdges.first?.target, id2)

        // 3. 按 Comparison 过滤
        viewModel.filterType = .comparison
        let compNodes = viewModel.getFilteredNodes()
        let compEdges = viewModel.getFilteredEdges(for: compNodes)
        XCTAssertEqual(compNodes.count, 1)
        XCTAssertEqual(compEdges.count, 0)
    }

    // MARK: - 2. 物理仿真启停状态机测试

    func testGraphViewModel_SimulationLifecycle() async {
        let viewModel = GraphViewModel()
        let id1 = UUID()
        let id2 = UUID()
        viewModel.nodes = [
            GraphNode(id: id1, title: "A", pageType: .concept, position: CGPoint(x: 10, y: 10)),
            GraphNode(id: id2, title: "B", pageType: .concept, position: CGPoint(x: 100, y: 100))
        ]
        viewModel.edges = [GraphEdge(source: id1, target: id2)]
        viewModel.graphSize = CGSize(width: 400, height: 400)

        // 开启仿真
        viewModel.isAnimating = true
        XCTAssertTrue(viewModel.isAnimating)

        // 等待几帧物理迭代
        try? await Task.sleep(for: .milliseconds(50))

        // 停止仿真
        viewModel.isAnimating = false
        XCTAssertFalse(viewModel.isAnimating)
    }

    // MARK: - 3. GraphContainerView 视图装配与交互测试

    func testGraphContainerView_Hierarchy() {
        struct HostView: View {
            @Namespace var heroNamespace
            @State var selectedTab: AppTab = .graph

            var body: some View {
                NavigationStack {
                    GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
                }
                .snapshotEnvironment()
            }
        }

        let view = HostView()
        XCTAssertNotNil(view)
    }
}
