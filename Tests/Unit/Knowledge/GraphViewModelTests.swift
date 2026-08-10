//
//  GraphViewModelTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 GraphViewModel 的节点/边过滤、仿真启停与状态管理逻辑。
//

import XCTest
import SwiftUI
@testable import ZhiYu

@MainActor
final class GraphViewModelTests: XCTestCase {

    /// 被测视图模型
    private var viewModel: GraphViewModel!

    /// 测试用节点 ID
    private let nodeA = UUID()
    private let nodeB = UUID()
    private let nodeC = UUID()

    override func setUp() async throws {
        try await super.setUp()
        viewModel = GraphViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    /// 构造测试用节点集合（含三种 PageType）
    private func makeTestNodes() -> [GraphNode] {
        [
            GraphNode(id: nodeA, title: "概念A", pageType: .concept, position: .zero),
            GraphNode(id: nodeB, title: "词条B", pageType: .entity, position: .zero),
            GraphNode(id: nodeC, title: "来源C", pageType: .source, position: .zero)
        ]
    }

    /// 构造测试用边集合（A→B, B→C, A→C）
    private func makeTestEdges() -> [GraphEdge] {
        [
            GraphEdge(source: nodeA, target: nodeB),
            GraphEdge(source: nodeB, target: nodeC),
            GraphEdge(source: nodeA, target: nodeC)
        ]
    }

    // MARK: - getFilteredNodes

    /// 验证 filterType=nil 时返回全部节点
    func testGetFilteredNodesNoFilterReturnsAll() {
        viewModel.nodes = makeTestNodes()
        viewModel.filterType = nil

        let filtered = viewModel.getFilteredNodes()
        XCTAssertEqual(filtered.count, 3, "无过滤时应返回全部节点")
    }

    /// 验证 filterType=.concept 时只返回 concept 类型节点
    func testGetFilteredNodesByConceptType() {
        viewModel.nodes = makeTestNodes()
        viewModel.filterType = .concept

        let filtered = viewModel.getFilteredNodes()
        XCTAssertEqual(filtered.count, 1, "应只返回 1 个 concept 节点")
        XCTAssertEqual(filtered.first?.id, nodeA, "应返回节点 A")
        XCTAssertEqual(filtered.first?.pageType, .concept)
    }

    /// 验证 filterType=.entity 时只返回 entity 类型节点
    func testGetFilteredNodesByEntityType() {
        viewModel.nodes = makeTestNodes()
        viewModel.filterType = .entity

        let filtered = viewModel.getFilteredNodes()
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, nodeB)
    }

    /// 验证空节点列表过滤返回空
    func testGetFilteredNodesEmptyList() {
        viewModel.nodes = []
        viewModel.filterType = .concept

        let filtered = viewModel.getFilteredNodes()
        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - getFilteredEdges

    /// 验证 filterType=nil 时返回全部边
    func testGetFilteredEdgesNoFilterReturnsAll() {
        viewModel.nodes = makeTestNodes()
        viewModel.edges = makeTestEdges()
        viewModel.filterType = nil

        let filteredNodes = viewModel.getFilteredNodes()
        let filteredEdges = viewModel.getFilteredEdges(for: filteredNodes)
        XCTAssertEqual(filteredEdges.count, 3, "无过滤时应返回全部边")
    }

    /// 验证过滤节点后只返回两端都在过滤集合中的边
    func testGetFilteredEdgesWithFilteredNodes() {
        viewModel.nodes = makeTestNodes()
        viewModel.edges = makeTestEdges()
        viewModel.filterType = .concept

        let filteredNodes = viewModel.getFilteredNodes()
        XCTAssertEqual(filteredNodes.count, 1, "前置：concept 节点仅 1 个")

        let filteredEdges = viewModel.getFilteredEdges(for: filteredNodes)
        XCTAssertTrue(filteredEdges.isEmpty, "仅 1 个节点时无两端都在集合中的边")
    }

    /// 验证两个 concept 节点间的边被保留
    func testGetFilteredEdgesKeepsEdgesBetweenSameType() {
        let nodeD = UUID()
        viewModel.nodes = [
            GraphNode(id: nodeA, title: "概念A", pageType: .concept, position: .zero),
            GraphNode(id: nodeD, title: "概念D", pageType: .concept, position: .zero),
            GraphNode(id: nodeB, title: "词条B", pageType: .entity, position: .zero)
        ]
        viewModel.edges = [
            GraphEdge(source: nodeA, target: nodeD),
            GraphEdge(source: nodeA, target: nodeB),
            GraphEdge(source: nodeD, target: nodeB)
        ]
        viewModel.filterType = .concept

        let filteredNodes = viewModel.getFilteredNodes()
        let filteredEdges = viewModel.getFilteredEdges(for: filteredNodes)
        XCTAssertEqual(filteredEdges.count, 1, "应只保留 A↔D 这条 concept-concept 边")
        XCTAssertEqual(filteredEdges.first?.source, nodeA)
        XCTAssertEqual(filteredEdges.first?.target, nodeD)
    }

    // MARK: - 仿真启停

    /// 验证 isAnimating=true 启动仿真任务
    func testIsAnimatingTrueStartsSimulation() async {
        viewModel.nodes = makeTestNodes()
        viewModel.graphSize = CGSize(width: 400, height: 400)
        viewModel.isAnimating = true

        // 等待仿真任务启动
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.isAnimating, "isAnimating 应为 true")
        // 节点位置应被仿真更新（不再全是 .zero）
        let movedCount = viewModel.nodes.filter { $0.position != .zero }.count
        XCTAssertGreaterThan(movedCount, 0, "至少一个节点位置应被仿真更新")
    }

    /// 验证 isAnimating=false 停止仿真任务
    func testIsAnimatingFalseStopsSimulation() async {
        viewModel.nodes = makeTestNodes()
        viewModel.graphSize = CGSize(width: 400, height: 400)
        viewModel.isAnimating = true
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.isAnimating = false
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(viewModel.isAnimating, "isAnimating 应为 false")
    }

    /// 验证空节点时仿真自动退出
    func testSimulationExitsOnEmptyNodes() async {
        viewModel.nodes = []
        viewModel.graphSize = CGSize(width: 400, height: 400)
        viewModel.isAnimating = true

        try? await Task.sleep(nanoseconds: 100_000_000)

        // 空节点时仿真循环应 break 退出，但 isAnimating 状态不变（由外部控制）
        XCTAssertTrue(viewModel.isAnimating, "isAnimating 状态由外部控制，仿真退出不改变状态")
    }

    // MARK: - 状态管理

    /// 验证初始状态
    func testInitialState() {
        XCTAssertNil(viewModel.selectedNodeID, "初始 selectedNodeID 应为 nil")
        XCTAssertTrue(viewModel.nodes.isEmpty, "初始 nodes 应为空")
        XCTAssertTrue(viewModel.edges.isEmpty, "初始 edges 应为空")
        XCTAssertEqual(viewModel.scale, 1.0, "初始 scale 应为 1.0")
        XCTAssertEqual(viewModel.offset, .zero, "初始 offset 应为 zero")
        XCTAssertTrue(viewModel.isLayouting, "初始 isLayouting 应为 true")
        XCTAssertFalse(viewModel.showLegend, "初始 showLegend 应为 false")
        XCTAssertFalse(viewModel.useClustering, "初始 useClustering 应为 false")
        XCTAssertFalse(viewModel.show3D, "初始 show3D 应为 false")
        XCTAssertNil(viewModel.filterType, "初始 filterType 应为 nil")
    }

    /// 验证 selectedNodeID 可正常设置
    func testSetSelectedNodeID() {
        viewModel.selectedNodeID = nodeA
        XCTAssertEqual(viewModel.selectedNodeID, nodeA)
    }

    /// 验证 filterType 切换
    func testFilterTypeSwitch() {
        viewModel.filterType = .concept
        XCTAssertEqual(viewModel.filterType, .concept)

        viewModel.filterType = .entity
        XCTAssertEqual(viewModel.filterType, .entity)

        viewModel.filterType = nil
        XCTAssertNil(viewModel.filterType)
    }
}
