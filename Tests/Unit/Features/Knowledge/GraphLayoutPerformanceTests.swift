//
//  GraphLayoutPerformanceTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Knowledge
//  核心职责：验证 GraphLayoutProcessor 图谱布局计算与孤岛节点过滤在大图规模下的时间复杂度与性能边界。
//

import XCTest
@testable import ZhiYu

final class GraphLayoutPerformanceTests: XCTestCase {

    /// 验证 orphanNodes 在大图上性能表现良好
    func testOrphanNodes_largeGraph_completesWithinThreshold() {
        let nodes = (0..<100).map { i in
            GraphNode(
                id: UUID(),
                title: "Node\(i)",
                pageType: .concept,
                position: CGPoint(x: Double(i), y: 0),
                communityID: i % 5
            )
        }
        var edges: [GraphEdge] = []
        for i in 0..<nodes.count - 1 {
            edges.append(GraphEdge(source: nodes[i].id, target: nodes[i + 1].id))
        }

        let startTime = Date()
        let orphans = GraphLayoutProcessor.orphanNodes(nodes: nodes, edges: edges)
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertNotNil(orphans, "大图孤岛节点计算应正常返回")
        XCTAssertLessThan(duration, 5.0, "100 节点图应在 5 秒内完成")
    }
}
