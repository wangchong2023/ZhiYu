//
//  GraphInsightDetection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：知识图谱：3D 可视化、社区发现、力导向布局。
//
import Foundation

// MARK: - Insight Detection
extension GraphLayoutProcessor {

    /// 获取孤立页面（无任何连接的节点）
    static func orphanNodes(nodes: [GraphNode], edges: [GraphEdge]) -> [UUID] {
        var connectedNodes: Set<UUID> = []
        for edge in edges {
            connectedNodes.insert(edge.source)
            connectedNodes.insert(edge.target)
        }
        return nodes.filter { !connectedNodes.contains($0.id) }.map { $0.id }
    }

    /// 综合检测所有类型的洞察：意外关联、孤立页面、稀疏社区、桥接节点
    /// - Returns: (surprisingConnections, orphans, sparseCommunity, bridges)
    struct InsightResults { var surprising: [UUID]; var orphans: [UUID]; var sparse: [UUID]; var bridges: [UUID] }
    static func detectInsights(
        nodes: [GraphNode],
        edges: [GraphEdge],
        pages _: [KnowledgePage]
    ) -> InsightResults {
        // 性能优化：建立节点查找索引
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        // 1. 孤立页面检测
        let orphans = orphanNodes(nodes: nodes, edges: edges)

        // 2. 低内聚力社区检测
        let sparse = lowCohesionCommunities(nodes: nodes, threshold: 0.15)

        // 3. 桥接节点检测（连接多个社区的节点）
        let bridges = detectBridgeNodes(nodes: nodes, edges: edges, nodeMap: nodeMap)

        // 4. 意外关联检测（跨社区且类型不同的关联）
        let surprising = detectSurprisingConnections(edges: edges, nodeMap: nodeMap)

        return InsightResults(surprising: surprising, orphans: orphans, sparse: sparse, bridges: bridges)
    }

    // MARK: - 私有检测组件

    /// 检测桥接节点：连接 >= 3 个不同社区的节点
    private static func detectBridgeNodes(
        nodes _: [GraphNode],
        edges: [GraphEdge],
        nodeMap: [UUID: GraphNode]
    ) -> [UUID] {
        var bridges: Set<UUID> = []

        for edge in edges {
            let srcComm = nodeMap[edge.source]?.communityID
            let tgtComm = nodeMap[edge.target]?.communityID

            if let sc = srcComm, let tc = tgtComm, sc != tc {
                // 检查两个节点各自连接了多少个不同社区
                let srcConnectedCommunities = countDistinctCommunities(node: edge.source, nodeMap: nodeMap, edges: edges)
                let tgtConnectedCommunities = countDistinctCommunities(node: edge.target, nodeMap: nodeMap, edges: edges)

                if srcConnectedCommunities >= 3 { bridges.insert(edge.source) }
                if tgtConnectedCommunities >= 3 { bridges.insert(edge.target) }
            }
        }
        return Array(bridges)
    }

    /// 检测意外关联：跨社区且节点类型不同的关联
    private static func detectSurprisingConnections(
        edges: [GraphEdge],
        nodeMap: [UUID: GraphNode]
    ) -> [UUID] {
        var surprising: Set<UUID> = []
        for edge in edges {
            guard let src = nodeMap[edge.source],
                  let tgt = nodeMap[edge.target],
                  let sc = src.communityID,
                  let tc = tgt.communityID,
                  sc != tc else { continue }

            // 类型不同的跨社区连接更""
            if src.pageType != tgt.pageType {
                surprising.insert(edge.source)
                surprising.insert(edge.target)
            }
        }
        return Array(surprising)
    }

    /// 计算节点连接的独立社区数量
    private static func countDistinctCommunities(
        node: UUID,
        nodeMap: [UUID: GraphNode],
        edges: [GraphEdge]
    ) -> Int {
        var communities: Set<Int> = []
        for edge in edges {
            let neighborID: UUID?
            if edge.source == node { neighborID = edge.target } else if edge.target == node { neighborID = edge.source } else { neighborID = nil }

            if let nid = neighborID, let comm = nodeMap[nid]?.communityID {
                communities.insert(comm)
            }
        }
        return communities.count
    }
}
