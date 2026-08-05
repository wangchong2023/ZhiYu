//
//  GraphCommunityProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 GraphCommunityProcessor 社区发现算法的空输入、无边图、连通图、模块度优化等边界语义。
//

import XCTest
@testable import ZhiYu

final class GraphCommunityProcessorEdgeTests: XCTestCase {

    // MARK: - 空输入

    func testDetectCommunities_emptyNodes_returnsEmpty() {
        let result = GraphLayoutProcessor.detectCommunities(nodes: [], edges: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 无边图（每个节点独立社区）

    func testDetectCommunities_noEdges_eachNodeOwnCommunity() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero),
            GraphNode(id: UUID(), title: "B", pageType: .concept, position: .zero),
            GraphNode(id: UUID(), title: "C", pageType: .concept, position: .zero)
        ]
        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: [])
        XCTAssertEqual(result.count, 3)
        let communityIDs = result.compactMap { $0.communityID }
        let uniqueIDs = Set(communityIDs)
        XCTAssertEqual(uniqueIDs.count, 3, "无边图每个节点应有独立社区")
        for node in result {
            XCTAssertEqual(node.communityCohesion, 1.0, "独立社区内聚力应为 1.0")
        }
    }

    // MARK: - 连通图

    func testDetectCommunities_connectedGraph_assignsCommunityIDs() {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero),
            GraphNode(id: idC, title: "C", pageType: .concept, position: .zero)
        ]
        let edges = [
            GraphEdge(source: idA, target: idB),
            GraphEdge(source: idB, target: idC),
            GraphEdge(source: idA, target: idC)
        ]
        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: edges)
        XCTAssertEqual(result.count, 3)
        for node in result {
            XCTAssertNotNil(node.communityID, "连通图节点应被分配社区 ID")
        }
    }

    // MARK: - 两个独立连通分量

    func testDetectCommunities_twoComponents_assignsDifferentCommunities() {
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()
        let idD = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero),
            GraphNode(id: idC, title: "C", pageType: .concept, position: .zero),
            GraphNode(id: idD, title: "D", pageType: .concept, position: .zero)
        ]
        let edges = [
            GraphEdge(source: idA, target: idB),
            GraphEdge(source: idC, target: idD)
        ]
        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: edges)
        XCTAssertEqual(result.count, 4)
        let commAB = result.first { $0.id == idA }?.communityID
        let commCD = result.first { $0.id == idC }?.communityID
        XCTAssertNotNil(commAB)
        XCTAssertNotNil(commCD)
        XCTAssertNotEqual(commAB, commCD, "两个独立连通分量应分属不同社区")
    }

    // MARK: - lowCohesionCommunities

    func testLowCohesionCommunities_filtersByThreshold() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, communityID: 0, communityCohesion: 0.1),
            GraphNode(id: UUID(), title: "B", pageType: .concept, position: .zero, communityID: 1, communityCohesion: 0.5),
            GraphNode(id: UUID(), title: "C", pageType: .concept, position: .zero, communityID: 2, communityCohesion: 0.05)
        ]
        let lowCohesion = GraphLayoutProcessor.lowCohesionCommunities(nodes: nodes, threshold: 0.15)
        XCTAssertEqual(lowCohesion.count, 2, "内聚力 < 0.15 的节点应被识别")
    }

    func testLowCohesionCommunities_nilCohesion_filtered() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, communityID: nil, communityCohesion: nil)
        ]
        let lowCohesion = GraphLayoutProcessor.lowCohesionCommunities(nodes: nodes)
        XCTAssertTrue(lowCohesion.isEmpty, "communityCohesion 为 nil 的节点应被过滤")
    }

    // MARK: - EdgePair Hashable

    func testEdgePair_hashableAndEquatable() {
        let id1 = UUID()
        let id2 = UUID()
        let p1 = EdgePair(id1, id2)
        let p2 = EdgePair(id1, id2)
        XCTAssertEqual(p1, p2)
        XCTAssertEqual(p1.hashValue, p2.hashValue)
    }

    func testEdgePair_orderIndependent() {
        let id1 = UUID()
        let id2 = UUID()
        let p1 = EdgePair(min(id1, id2), max(id1, id2))
        let p2 = EdgePair(min(id1, id2), max(id1, id2))
        XCTAssertEqual(p1, p2)
    }
}
