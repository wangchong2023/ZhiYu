//
//  GraphCommunityProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation

// MARK: - 社区发现
extension GraphLayoutProcessor {

    /// 检测Communities
    /// - Parameter nodes: nodes
    /// - Parameter edges: edges
    /// - Returns: 列表
    static func detectCommunities(nodes: [GraphNode], edges: [GraphEdge]) -> [GraphNode] {
        guard !nodes.isEmpty else { return [] }

        let graphStructures = buildGraphStructures(nodes: nodes, edges: edges)
        let m = Double(graphStructures.undirectedEdges.count)

        guard m > 0 else {
            return assignIndependentCommunities(nodes: nodes)
        }

        var (community, communityNodes) = initializeCommunities(nodes: nodes)

        refineCommunities(
            community: &community,
            communityNodes: &communityNodes,
            adjacency: graphStructures.adjacency,
            nodeDegree: graphStructures.nodeDegree,
            m: m
        )

        return finalizeCommunities(
            nodes: nodes,
            community: community,
            undirectedEdges: graphStructures.undirectedEdges
        )
    }

    // MARK: - 私有优化组件

    /// 构建图的邻接关系与度数信息
    private struct GraphStructures { var adjacency: [UUID: Set<UUID>]; var nodeDegree: [UUID: Int]; var undirectedEdges: Set<EdgePair> }
    private static func buildGraphStructures(nodes: [GraphNode], edges: [GraphEdge]) -> GraphStructures {
        let nodeIDs = Set(nodes.map { $0.id })
        var adjacency: [UUID: Set<UUID>] = [:]
        var nodeDegree: [UUID: Int] = [:]

        for nodeID in nodeIDs {
            adjacency[nodeID] = []
            nodeDegree[nodeID] = 0
        }

        var undirectedEdges: Set<EdgePair> = []
        for edge in edges {
            if nodeIDs.contains(edge.source) && nodeIDs.contains(edge.target) {
                let pair = EdgePair(min(edge.source, edge.target), max(edge.source, edge.target))
                if undirectedEdges.insert(pair).inserted {
                    adjacency[edge.source]?.insert(edge.target)
                    adjacency[edge.target]?.insert(edge.source)
                    nodeDegree[edge.source, default: 0] += 1
                    nodeDegree[edge.target, default: 0] += 1
                }
            }
        }
        return GraphStructures(adjacency: adjacency, nodeDegree: nodeDegree, undirectedEdges: undirectedEdges)
    }

    /// 当没有边时，为每个节点分配独立的社区
    private static func assignIndependentCommunities(nodes: [GraphNode]) -> [GraphNode] {
        var workingNodes = nodes
        for i in workingNodes.indices {
            workingNodes[i].communityID = i
            workingNodes[i].communityCohesion = 1.0
        }
        return workingNodes
    }

    /// 初始化社区分配，每个节点独立为一个社区
    private static func initializeCommunities(nodes: [GraphNode]) -> (community: [UUID: Int], communityNodes: [Int: Set<UUID>]) {
        var community: [UUID: Int] = [:]
        var communityNodes: [Int: Set<UUID>] = [:]
        for (index, node) in nodes.enumerated() {
            community[node.id] = index
            communityNodes[index] = [node.id]
        }
        return (community, communityNodes)
    }

    /// 迭代优化社区分配
    private static func refineCommunities(
        community: inout [UUID: Int],
        communityNodes: inout [Int: Set<UUID>],
        adjacency: [UUID: Set<UUID>],
        nodeDegree: [UUID: Int],
        m: Double
    ) {
        var currentModularity = calculateModularity(community: community, adjacency: adjacency, nodeDegree: nodeDegree, m: m)
        var improved = true
        var iteration = 0
        let maxIterations = 10
        let nodeIDs = Array(community.keys)

        while improved && iteration < maxIterations {
            improved = false
            iteration += 1

            for nodeID in nodeIDs {
                guard let currentComm = community[nodeID] else { continue }
                let bestComm = findBestCommunity(
                    for: nodeID,
                    currentComm: currentComm,
                    community: community,
                    communityNodes: communityNodes,
                    adjacency: adjacency,
                    nodeDegree: nodeDegree,
                    m: m
                )

                if bestComm != currentComm {
                    communityNodes[currentComm]?.remove(nodeID)
                    communityNodes[bestComm, default: []].insert(nodeID)
                    community[nodeID] = bestComm
                    improved = true
                }
            }

            let newModularity = calculateModularity(community: community, adjacency: adjacency, nodeDegree: nodeDegree, m: m)
            if newModularity <= currentModularity {
                improved = false
            } else {
                currentModularity = newModularity
            }
        }
    }

    /// 寻找节点的最佳目标社区
    private static func findBestCommunity(
        for nodeID: UUID,
        currentComm: Int,
        community: [UUID: Int],
        communityNodes: [Int: Set<UUID>],
        adjacency: [UUID: Set<UUID>],
        nodeDegree: [UUID: Int],
        m: Double
    ) -> Int {
        var neighborCommunities: [Int: [UUID]] = [:]
        if let neighbors = adjacency[nodeID] {
            for neighbor in neighbors {
                guard let neighborComm = community[neighbor] else { continue }
                if neighborComm != currentComm {
                    neighborCommunities[neighborComm, default: []].append(neighbor)
                }
            }
        }

        var bestComm = currentComm
        var bestGain = 0.0

        for (targetComm, _) in neighborCommunities {
            let gain = calculateModularityGain(
                nodeID: nodeID,
                targetComm: targetComm,
                currentComm: currentComm,
                adjacency: adjacency,
                nodeDegree: nodeDegree,
                community: community,
                communityNodes: communityNodes,
                m: m
            )
            if gain > bestGain {
                bestGain = gain
                bestComm = targetComm
            }
        }
        return bestComm
    }

    /// 计算最终的内聚力并更新节点状态
    private static func finalizeCommunities(
        nodes: [GraphNode],
        community: [UUID: Int],
        undirectedEdges: Set<EdgePair>
    ) -> [GraphNode] {
        var workingNodes = nodes
        var communityInternalEdges: [Int: Int] = [:]
        var communityTotalEdges: [Int: Int] = [:]

        for edge in undirectedEdges {
            guard let comm0 = community[edge.source] else { continue }
            guard let comm1 = community[edge.target] else { continue }
            communityTotalEdges[comm0, default: 0] += 1
            communityTotalEdges[comm1, default: 0] += 1
            if comm0 == comm1 {
                communityInternalEdges[comm0, default: 0] += 1
            }
        }

        let nodeIndexMap = Dictionary(uniqueKeysWithValues: workingNodes.enumerated().map { ($0.element.id, $0.offset) })

        for (nodeID, comm) in community {
            let internalEdges = communityInternalEdges[comm] ?? 0
            let totalEdges = communityTotalEdges[comm] ?? 1
            let cohesion = Double(internalEdges) / Double(totalEdges)

            if let idx = nodeIndexMap[nodeID] {
                workingNodes[idx].communityID = comm
                workingNodes[idx].communityCohesion = cohesion
            }
        }

        return workingNodes
    }

    /// 计算模块度
    private static func calculateModularity(
        community: [UUID: Int],
        adjacency: [UUID: Set<UUID>],
        nodeDegree: [UUID: Int],
        m: Double
    ) -> Double {
        guard m > 0 else { return 0 }

        var modularity = 0.0
        for (nodeID, neighbors) in adjacency {
            let ki = Double(nodeDegree[nodeID] ?? 0)
            for neighborID in neighbors where nodeID < neighborID {
                let kj = Double(nodeDegree[neighborID] ?? 0)
                let sameCommunity = community[nodeID] == community[neighborID] ? 1.0 : 0.0
                modularity += (1.0 - (ki * kj) / (2 * m)) * sameCommunity
            }
        }
        return modularity / (2 * m)
    }

    /// 计算将节点从当前社区移动到目标社区的净模块度增益
    ///
    /// 标准 Louvain 增益公式（净增益 = 加入目标社区增益 - 离开当前社区损失）：
    ///   ΔQ = [k_i_in(C_target) - k_i_in(C_current)] / (2*m)
    ///        - k_i * [Σ_tot(C_target) - Σ_tot(C_current) + k_i] / (2*m)²
    ///
    /// 简化形式（移除当前社区后加入目标社区）：
    ///   ΔQ = k_i_in(C_target) / m
    ///        - k_i * Σ_tot(C_target) / (2*m²)
    ///        - [k_i_in(C_current) / m - k_i * Σ_tot(C_current) / (2*m²)]
    ///
    /// 其中：
    ///   - k_i_in(C_target)：节点与目标社区内部节点的连接数
    ///   - k_i_in(C_current)：节点与当前社区内部节点（不含自身）的连接数
    ///   - k_i：节点 i 的度数
    ///   - Σ_tot(C_target)：目标社区所有节点的度数之和（不含节点 i）
    ///   - Σ_tot(C_current)：当前社区所有节点的度数之和（不含节点 i）
    ///   - m：总边数
    private static func calculateModularityGain(
        nodeID: UUID,
        targetComm: Int,
        currentComm: Int,
        adjacency: [UUID: Set<UUID>],
        nodeDegree: [UUID: Int],
        community: [UUID: Int],
        communityNodes: [Int: Set<UUID>],
        m: Double
    ) -> Double {
        guard m > 0 else { return 0 }

        let ki = Double(nodeDegree[nodeID] ?? 0)

        // k_i_in(C_target)：节点与目标社区内部节点的连接数
        var kiInTarget = 0.0
        // k_i_in(C_current)：节点与当前社区内部节点（不含自身）的连接数
        var kiInCurrent = 0.0
        // Σ_tot(C_target)：目标社区所有节点的度数之和（不含节点 i）
        var sumTotTarget = 0.0
        // Σ_tot(C_current)：当前社区所有节点的度数之和（不含节点 i）
        var sumTotCurrent = 0.0

        if let neighbors = adjacency[nodeID] {
            for neighborID in neighbors {
                let neighborComm = community[neighborID]
                if neighborComm == targetComm {
                    kiInTarget += 1
                }
                if neighborComm == currentComm {
                    kiInCurrent += 1
                }
            }
        }

        if let targetNodes = communityNodes[targetComm] {
            for memberID in targetNodes where memberID != nodeID {
                sumTotTarget += Double(nodeDegree[memberID] ?? 0)
            }
        }

        if let currentNodes = communityNodes[currentComm] {
            for memberID in currentNodes where memberID != nodeID {
                sumTotCurrent += Double(nodeDegree[memberID] ?? 0)
            }
        }

        // 净增益 = 加入目标社区的增益 - 离开当前社区的损失
        let gainTarget = kiInTarget / m - (ki * sumTotTarget) / (2 * m * m)
        let lossCurrent = kiInCurrent / m - (ki * sumTotCurrent) / (2 * m * m)
        return gainTarget - lossCurrent
    }

    /// 获取低内聚力社区的节点 ID
    static func lowCohesionCommunities(nodes: [GraphNode], threshold: Double = GraphConstants.Community.lowCohesionThreshold) -> [UUID] {
        return nodes.filter { node in
            if let cohesion = node.communityCohesion {
                return cohesion < threshold
            }
            return false
        }.map { $0.id }
    }
}

// MARK: - 辅助类型

/// 无向边表示，用于去重
struct EdgePair: Hashable {
    let source: UUID
    let target: UUID

    init(_ source: UUID, _ target: UUID) {
        self.source = source
        self.target = target
    }
}
