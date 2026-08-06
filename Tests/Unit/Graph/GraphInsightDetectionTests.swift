//
//  GraphInsightDetectionTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证图谱洞察检测：孤立节点、桥接节点、意外关联、低内聚力社区等边界语义。
//

import XCTest
@testable import ZhiYu

final class GraphInsightDetectionTests: XCTestCase {

    // MARK: - orphanNodes 孤立节点检测

    func testOrphanNodes_noEdges_allNodesOrphan() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero)
        ]
        let orphans = GraphLayoutProcessor.orphanNodes(nodes: nodes, edges: [])
        XCTAssertEqual(orphans.count, 2)
        XCTAssertTrue(orphans.contains(idA))
        XCTAssertTrue(orphans.contains(idB))
    }

    func testOrphanNodes_connectedGraph_noOrphans() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]
        let orphans = GraphLayoutProcessor.orphanNodes(nodes: nodes, edges: edges)
        XCTAssertTrue(orphans.isEmpty)
    }

    func testOrphanNodes_partialConnection_onlyUnconnectedOrphan() {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero),
            GraphNode(id: idC, title: "C", pageType: .concept, position: .zero)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]
        let orphans = GraphLayoutProcessor.orphanNodes(nodes: nodes, edges: edges)
        XCTAssertEqual(orphans.count, 1)
        XCTAssertTrue(orphans.contains(idC))
    }

    // MARK: - detectInsights 综合检测

    func testDetectInsights_emptyGraph_returnsEmptyResults() {
        let results = GraphLayoutProcessor.detectInsights(nodes: [], edges: [], pages: [])
        XCTAssertTrue(results.surprising.isEmpty)
        XCTAssertTrue(results.orphans.isEmpty)
        XCTAssertTrue(results.sparse.isEmpty)
        XCTAssertTrue(results.bridges.isEmpty)
    }

    func testDetectInsights_allOrphans_detected() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero)
        ]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: [], pages: [])
        XCTAssertEqual(results.orphans.count, 2)
    }

    // MARK: - 桥接节点检测

    func testDetectInsights_bridgeNode_detected() {
        // 构造 3 社区图：A(社区0) - B(社区1) - C(社区2) - D(社区0)
        // B 连接社区 0/2，C 连接社区 1/0，但需 >=3 个不同社区
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let idD = UUID()
        let idE = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero, communityID: 0),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero, communityID: 1),
            GraphNode(id: idC, title: "C", pageType: .concept, position: .zero, communityID: 2),
            GraphNode(id: idD, title: "D", pageType: .concept, position: .zero, communityID: 3),
            GraphNode(id: idE, title: "E", pageType: .concept, position: .zero, communityID: 4)
        ]
        // E 连接 A/B/C/D → E 连接 4 个不同社区，是桥接节点
        let edges = [
            GraphEdge(source: idE, target: idA),
            GraphEdge(source: idE, target: idB),
            GraphEdge(source: idE, target: idC),
            GraphEdge(source: idE, target: idD)
        ]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: edges, pages: [])
        XCTAssertTrue(results.bridges.contains(idE), "E 连接 4 个社区应为桥接节点")
    }

    func testDetectInsights_noBridge_fewCommunities() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero, communityID: 0),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero, communityID: 1)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: edges, pages: [])
        XCTAssertTrue(results.bridges.isEmpty, "仅连接 1 个社区不应为桥接节点")
    }

    // MARK: - 意外关联检测

    func testDetectInsights_surprisingConnection_crossCommunityDifferentType() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero, communityID: 0),
            GraphNode(id: idB, title: "B", pageType: .entity, position: .zero, communityID: 1)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: edges, pages: [])
        XCTAssertTrue(results.surprising.contains(idA), "跨社区且类型不同的连接应为意外关联")
        XCTAssertTrue(results.surprising.contains(idB))
    }

    func testDetectInsights_noSurprising_sameCommunity() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero, communityID: 0),
            GraphNode(id: idB, title: "B", pageType: .entity, position: .zero, communityID: 0)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: edges, pages: [])
        XCTAssertTrue(results.surprising.isEmpty, "同社区连接不应为意外关联")
    }

    func testDetectInsights_noSurprising_sameType() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero, communityID: 0),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero, communityID: 1)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: edges, pages: [])
        XCTAssertTrue(results.surprising.isEmpty, "同类型连接不应为意外关联")
    }

    // MARK: - 低内聚力社区检测

    func testDetectInsights_lowCohesion_detected() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, communityID: 0, communityCohesion: 0.1),
            GraphNode(id: UUID(), title: "B", pageType: .concept, position: .zero, communityID: 1, communityCohesion: 0.9)
        ]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: [], pages: [])
        XCTAssertEqual(results.sparse.count, 1, "内聚力 0.1 < 0.15 应被识别为稀疏")
    }

    // MARK: - nil communityID 处理

    func testDetectInsights_nilCommunityID_noBridge() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero, communityID: nil),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero, communityID: nil)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]
        let results = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: edges, pages: [])
        XCTAssertTrue(results.bridges.isEmpty, "communityID 为 nil 不应触发桥接检测")
        XCTAssertTrue(results.surprising.isEmpty, "communityID 为 nil 不应触发意外关联检测")
    }
}
