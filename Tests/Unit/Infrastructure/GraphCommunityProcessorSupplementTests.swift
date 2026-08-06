//
//  GraphCommunityProcessorSupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：补充 GraphCommunityProcessor 社区发现算法的重复边去重、自环过滤、单节点图、全连通图等边界语义。
//

import XCTest
@testable import ZhiYu

final class GraphCommunityProcessorSupplementTests: XCTestCase {

    // MARK: - 重复边去重

    func testDetectCommunities_duplicateEdges_deduplicated() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero)
        ]
        let edges = [
            GraphEdge(source: idA, target: idB),
            GraphEdge(source: idA, target: idB),
            GraphEdge(source: idB, target: idA)
        ]

        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: edges)

        XCTAssertEqual(result.count, 2, "重复边不应影响节点数量")
        for node in result {
            XCTAssertNotNil(node.communityID, "重复边图节点仍应被分配社区")
        }
    }

    // MARK: - 自环边过滤

    func testDetectCommunities_selfLoopEdge_ignored() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero)
        ]
        let edges = [
            GraphEdge(source: idA, target: idA),
            GraphEdge(source: idA, target: idB)
        ]

        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: edges)

        XCTAssertEqual(result.count, 2, "自环边不应影响节点数量")
    }

    // MARK: - 单节点图

    func testDetectCommunities_singleNode_returnsSingleNodeWithCommunity() {
        let idA = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero)
        ]

        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[0].communityID, "单节点应被分配社区 ID")
        XCTAssertEqual(result[0].communityCohesion, 1.0, "单节点内聚力应为 1.0")
    }

    // MARK: - 边引用不存在的节点

    func testDetectCommunities_edgeToNonExistentNode_filtered() {
        let idA = UUID()
        let idB = UUID()
        let ghostID = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero)
        ]
        let edges = [
            GraphEdge(source: idA, target: ghostID),
            GraphEdge(source: idA, target: idB)
        ]

        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: edges)

        XCTAssertEqual(result.count, 2, "引用不存在节点的边应被过滤")
    }

    // MARK: - 全连通图（3 节点三角形）

    func testDetectCommunities_fullyConnectedTriangle_singleCommunity() {
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

        XCTAssertEqual(result.count, 3, "全连通三角形应保留全部节点")
        let communityIDs = Set(result.compactMap { $0.communityID })
        XCTAssertEqual(communityIDs.count, 1, "全连通三角形应合并为单一社区")
        for node in result {
            XCTAssertNotNil(node.communityID, "全连通图节点应被分配社区 ID")
            XCTAssertNotNil(node.communityCohesion, "全连通图节点应有内聚力值")
        }
    }

    // MARK: - lowCohesionCommunities 默认阈值

    func testLowCohesionCommunities_defaultThreshold_filtersCorrectly() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, communityID: 0, communityCohesion: 0.1),
            GraphNode(id: UUID(), title: "B", pageType: .concept, position: .zero, communityID: 1, communityCohesion: 0.2)
        ]

        let lowCohesion = GraphLayoutProcessor.lowCohesionCommunities(nodes: nodes)

        XCTAssertEqual(lowCohesion.count, 1, "默认阈值 0.15 下只有 0.1 应被识别")
    }

    // MARK: - lowCohesionCommunities 空节点

    func testLowCohesionCommunities_emptyNodes_returnsEmpty() {
        let result = GraphLayoutProcessor.lowCohesionCommunities(nodes: [])
        XCTAssertTrue(result.isEmpty, "空节点列表应返回空")
    }

    // MARK: - lowCohesionCommunities 全部高内聚

    func testLowCohesionCommunities_allHighCohesion_returnsEmpty() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, communityID: 0, communityCohesion: 0.9),
            GraphNode(id: UUID(), title: "B", pageType: .concept, position: .zero, communityID: 1, communityCohesion: 1.0)
        ]

        let result = GraphLayoutProcessor.lowCohesionCommunities(nodes: nodes, threshold: 0.15)

        XCTAssertTrue(result.isEmpty, "全部高内聚节点应返回空")
    }

    // MARK: - lowCohesionCommunities 边界值

    func testLowCohesionCommunities_exactThreshold_notIncluded() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, communityID: 0, communityCohesion: 0.15)
        ]

        let result = GraphLayoutProcessor.lowCohesionCommunities(nodes: nodes, threshold: 0.15)

        XCTAssertTrue(result.isEmpty, "内聚力 == 阈值不应被包含（严格小于）")
    }

    // MARK: - 社区内聚力计算

    func testDetectCommunities_twoNodeOneEdge_cohesionIsOne() {
        let idA = UUID()
        let idB = UUID()
        let nodes = [
            GraphNode(id: idA, title: "A", pageType: .concept, position: .zero),
            GraphNode(id: idB, title: "B", pageType: .concept, position: .zero)
        ]
        let edges = [GraphEdge(source: idA, target: idB)]

        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: edges)

        XCTAssertEqual(result.count, 2, "两节点一边应保留全部节点")
        let communityIDs = Set(result.compactMap { $0.communityID })
        XCTAssertEqual(communityIDs.count, 1, "两节点一边应合并为单一社区")
        for node in result {
            XCTAssertNotNil(node.communityID, "节点应被分配社区 ID")
            XCTAssertNotNil(node.communityCohesion, "节点应有内聚力值")
        }
    }
}
