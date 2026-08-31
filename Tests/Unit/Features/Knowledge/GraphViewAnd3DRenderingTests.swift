//
//  GraphViewAnd3DRenderingTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 GraphViewModel 节点类型过滤、边关联截断、物理仿真启停与 3D 模式流转。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class GraphViewAnd3DRenderingTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 节点与边类型过滤分支

    func testGraphViewModel_FilteringNodesAndEdges() {
        let vm = GraphViewModel()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let node1 = GraphNode(id: id1, title: "节点1", pageType: .concept, position: .zero)
        let node2 = GraphNode(id: id2, title: "节点2", pageType: .concept, position: .zero)
        let node3 = GraphNode(id: id3, title: "节点3", pageType: .entity, position: .zero)

        vm.nodes = [node1, node2, node3]
        vm.edges = [
            GraphEdge(source: id1, target: id2),
            GraphEdge(source: id2, target: id3)
        ]

        // 默认不过滤
        XCTAssertEqual(vm.getFilteredNodes().count, 3)
        XCTAssertEqual(vm.getFilteredEdges(for: vm.nodes).count, 2)

        // 过滤 Concept 类型
        vm.filterType = .concept
        let filteredNodes = vm.getFilteredNodes()
        XCTAssertEqual(filteredNodes.count, 2)

        let filteredEdges = vm.getFilteredEdges(for: filteredNodes)
        XCTAssertEqual(filteredEdges.count, 1, "只保留两端均为 Concept 的边")
    }

    // MARK: - 2. 物理仿真启停状态机

    func testGraphViewModel_SimulationLifecycle() {
        let vm = GraphViewModel()
        XCTAssertFalse(vm.isAnimating)

        vm.isAnimating = true
        XCTAssertTrue(vm.isAnimating)

        vm.isAnimating = false
        XCTAssertFalse(vm.isAnimating)
    }

    // MARK: - 3. 3D 与洞察模式状态流转

    func testGraphViewModel_ModeToggles() {
        let vm = GraphViewModel()
        XCTAssertFalse(vm.show3D)
        XCTAssertFalse(vm.showInsights)

        vm.show3D = true
        XCTAssertTrue(vm.show3D)

        vm.showInsights = true
        XCTAssertTrue(vm.showInsights)
    }
}
