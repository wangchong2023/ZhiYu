//
//  GraphCycleAndSelfLoopTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试图谱算法在自环边 (Self-Loop)、多重循环依赖 (Cycles) 与孤立环路下的收敛性与洞察检测。
//

import XCTest
import CoreGraphics
@testable import ZhiYu

final class GraphCycleAndSelfLoopTests: XCTestCase {

    // MARK: - 1. 自环边与无边图的社区分配

    func testDetectCommunitiesWithSelfLoopsAndIsolatedNodes() {
        let nodeA = GraphNode(id: UUID(), title: "节点 A", pageType: .concept, position: .zero)
        let nodeB = GraphNode(id: UUID(), title: "节点 B", pageType: .concept, position: .zero)
        let nodeC = GraphNode(id: UUID(), title: "节点 C", pageType: .entity, position: .zero)

        // 包含自环边 A -> A
        let selfLoopEdge = GraphEdge(source: nodeA.id, target: nodeA.id)
        let normalEdge = GraphEdge(source: nodeA.id, target: nodeB.id)

        let result = GraphLayoutProcessor.detectCommunities(
            nodes: [nodeA, nodeB, nodeC],
            edges: [selfLoopEdge, normalEdge]
        )

        XCTAssertEqual(result.count, 3)
        // 验证每个节点都分配到了有效的社区 ID
        for node in result {
            XCTAssertNotNil(node.communityID)
            XCTAssertNotNil(node.communityCohesion)
        }
    }

    // MARK: - 2. 强连通有向/无向环路图的社区收敛

    func testCycleGraphCommunityConvergence() {
        let n1 = GraphNode(id: UUID(), title: "N1", pageType: .concept, position: .zero)
        let n2 = GraphNode(id: UUID(), title: "N2", pageType: .concept, position: .zero)
        let n3 = GraphNode(id: UUID(), title: "N3", pageType: .concept, position: .zero)

        // 环路 N1 -> N2 -> N3 -> N1
        let edges = [
            GraphEdge(source: n1.id, target: n2.id),
            GraphEdge(source: n2.id, target: n3.id),
            GraphEdge(source: n3.id, target: n1.id)
        ]

        let result = GraphLayoutProcessor.detectCommunities(nodes: [n1, n2, n3], edges: edges)
        XCTAssertEqual(result.count, 3)

        // 环形强连通子图应被归为同一个社区
        let communityIDs = Set(result.compactMap { $0.communityID })
        XCTAssertEqual(communityIDs.count, 1, "三角紧密环路应聚合为单一社区")
    }

    // MARK: - 3. 孤立节点与洞察探测

    func testOrphanAndInsightDetection() {
        let nodeA = GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero, communityID: 0)
        let nodeB = GraphNode(id: UUID(), title: "B", pageType: .source, position: .zero, communityID: 1)
        let orphanNode = GraphNode(id: UUID(), title: "孤立节点", pageType: .concept, position: .zero, communityID: 2)

        let edge = GraphEdge(source: nodeA.id, target: nodeB.id)

        let insights = GraphLayoutProcessor.detectInsights(
            nodes: [nodeA, nodeB, orphanNode],
            edges: [edge],
            pages: []
        )

        XCTAssertEqual(insights.orphans, [orphanNode.id], "应准确识别孤立节点")
        XCTAssertTrue(insights.surprising.contains(nodeA.id) || insights.surprising.contains(nodeB.id), "跨社区且异构类型的边应触发意外关联")
    }
}
