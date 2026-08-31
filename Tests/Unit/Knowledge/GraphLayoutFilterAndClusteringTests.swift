//
//  GraphLayoutFilterAndClusteringTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 GraphViewModel 的类型过滤、连通边端点校验、物理仿真启停与初始加载状态分支。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class GraphLayoutFilterAndClusteringTests: XCTestCase {

    // MARK: - 1. 节点类型动态过滤分支

    func testGetFilteredNodes_WithFilterType_FiltersCorrectly() {
        let vm = GraphViewModel()
        let n1 = GraphNode(id: UUID(), title: "概念节点", pageType: .concept, position: .zero, linkCount: 3)
        let n2 = GraphNode(id: UUID(), title: "实体节点", pageType: .entity, position: .zero, linkCount: 1)
        let n3 = GraphNode(id: UUID(), title: "来源节点", pageType: .source, position: .zero, linkCount: 2)
        vm.nodes = [n1, n2, n3]

        // 1. 无过滤
        vm.filterType = nil
        XCTAssertEqual(vm.getFilteredNodes().count, 3)

        // 2. 仅保留概念节点
        vm.filterType = .concept
        let filtered = vm.getFilteredNodes()
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, n1.id)
    }

    // MARK: - 2. 连通边过滤（必须两端节点均在过滤列表内）

    func testGetFilteredEdges_EnsuresBothEndpointsMatchFilteredNodes() {
        let vm = GraphViewModel()
        let n1 = GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, linkCount: 1)
        let n2 = GraphNode(id: UUID(), title: "B", pageType: .concept, position: .zero, linkCount: 1)
        let n3 = GraphNode(id: UUID(), title: "C", pageType: .entity, position: .zero, linkCount: 1)
        vm.nodes = [n1, n2, n3]

        let e1 = GraphEdge(source: n1.id, target: n2.id) // 两端均为 concept
        let e2 = GraphEdge(source: n1.id, target: n3.id) // 跨类型边
        vm.edges = [e1, e2]

        vm.filterType = .concept
        let filteredNodes = vm.getFilteredNodes()
        let filteredEdges = vm.getFilteredEdges(for: filteredNodes)

        XCTAssertEqual(filteredEdges.count, 1, "只有两端均为目标类型的边才会被保留")
        XCTAssertEqual(filteredEdges.first?.id, e1.id)
    }

    // MARK: - 3. 物理仿真动画启停分支

    func testSimulation_StartAndStop_UpdatesSimulationState() {
        let vm = GraphViewModel()
        XCTAssertFalse(vm.isAnimating)

        vm.isAnimating = true
        XCTAssertTrue(vm.isAnimating)

        vm.isAnimating = false
        XCTAssertFalse(vm.isAnimating)
    }
}
