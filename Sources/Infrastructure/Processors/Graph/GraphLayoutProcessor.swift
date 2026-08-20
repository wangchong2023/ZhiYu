//
//  GraphLayoutProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation
import CoreGraphics

// MARK: - 图谱布局引擎
/// 力导向布局引擎，将 KnowledgePage 集合计算为带坐标的 GraphNode/GraphEdge。
struct GraphLayoutProcessor {

    /// 布局配置参数
    struct Config {
        var repulsion: CGFloat = GraphConstants.Physics.repulsionForce
        var attraction: CGFloat = GraphConstants.Physics.attractionForce
        var damping: CGFloat = GraphConstants.Physics.damping
        var centerGravity: CGFloat = GraphConstants.Physics.centerGravity
        var iterations: Int = GraphConstants.TwoD.simulationIterations
        var padding: CGFloat = DesignSystem.Graph.layoutPadding

        static let `default` = Config()
    }

    /// 对页面集合执行力导向布局，返回节点和边。
    static func layout(
        pages: [KnowledgePage],
        linkResolver: (String) -> KnowledgePage?,
        canvasSize: CGSize,
        config: Config = .default
    ) -> (nodes: [GraphNode], edges: [GraphEdge]) {
        guard !pages.isEmpty else { return ([], []) }

        let canvas = computeCanvasDimensions(canvasSize: canvasSize, nodeCount: pages.count)
        var nodes = createInitialCircularLayout(pages: pages, canvas: canvas)
        let edges = createEdges(pages: pages, linkResolver: linkResolver)

        for iteration in 0..<config.iterations {
            let progress = CGFloat(iteration) / CGFloat(config.iterations)
            let temperature = GraphConstants.Layout.temperatureBaseline - progress * GraphConstants.Layout.temperatureDecayFactor
            applyForces(nodes: &nodes, edges: edges, canvasWidth: canvas.width, canvasHeight: canvas.height, config: config, temperature: temperature)
        }

        applyLinkCounts(nodes: &nodes, edges: edges)
        centerGraph(nodes: &nodes, canvasSize: canvasSize)
        return (nodes, edges)
    }

    private struct CanvasDimensions {
        let width: CGFloat
        let height: CGFloat
        let centerX: CGFloat
        let centerY: CGFloat
        let radius: CGFloat
    }

    private static func computeCanvasDimensions(canvasSize: CGSize, nodeCount: Int) -> CanvasDimensions {
        let baseExpansion = 1.0 + CGFloat(max(0, CGFloat(nodeCount) - GraphConstants.TwoD.baseExpansionOffset)) * GraphConstants.TwoD.expansionFactor
        let width = canvasSize.width * baseExpansion
        let height = canvasSize.height * baseExpansion
        return CanvasDimensions(width: width, height: height, centerX: width / 2, centerY: height / 2, radius: min(width, height) * GraphConstants.Layout.canvasRadiusRatio)
    }

    private static func createInitialCircularLayout(pages: [KnowledgePage], canvas: CanvasDimensions) -> [GraphNode] {
        pages.enumerated().map { index, page in
            let angle = Double(index) / Double(pages.count) * 2 * .pi - .pi / 2
            return GraphNode(id: page.id, title: page.title, pageType: page.pageType, position: CGPoint(x: canvas.centerX + canvas.radius * cos(angle), y: canvas.centerY + canvas.radius * sin(angle)))
        }
    }

    private struct DirectedEdge: Hashable {
        let source: UUID
        let target: UUID
    }

    private static func createEdges(pages: [KnowledgePage], linkResolver: (String) -> KnowledgePage?) -> [GraphEdge] {
        var edges: [GraphEdge] = []
        var edgeSet: Set<DirectedEdge> = []
        let pageIDSet = Set(pages.map { $0.id })

        for page in pages {
            for link in page.outgoingLinks {
                guard let targetPage = linkResolver(link), pageIDSet.contains(targetPage.id) else { continue }
                let directed = DirectedEdge(source: page.id, target: targetPage.id)
                if page.id != targetPage.id && edgeSet.insert(directed).inserted {
                    edges.append(GraphEdge(source: page.id, target: targetPage.id))
                }
            }
            for relatedID in page.relatedPageIDs where pageIDSet.contains(relatedID) {
                let directed = DirectedEdge(source: page.id, target: relatedID)
                if page.id != relatedID && edgeSet.insert(directed).inserted {
                    edges.append(GraphEdge(source: page.id, target: relatedID))
                }
            }
        }
        return edges
    }

    private static func applyLinkCounts(nodes: inout [GraphNode], edges: [GraphEdge]) {
        var linkCounts: [UUID: Int] = [:]
        for edge in edges {
            linkCounts[edge.source, default: 0] += 1
            linkCounts[edge.target, default: 0] += 1
        }
        for i in nodes.indices {
            nodes[i].linkCount = linkCounts[nodes[i].id] ?? 0
        }
    }

    private static func centerGraph(nodes: inout [GraphNode], canvasSize: CGSize) {
        guard !nodes.isEmpty else { return }
        let minX = nodes.map { $0.position.x }.min() ?? 0
        let maxX = nodes.map { $0.position.x }.max() ?? 0
        let minY = nodes.map { $0.position.y }.min() ?? 0
        let maxY = nodes.map { $0.position.y }.max() ?? 0
        let graphCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = canvasCenter.x - graphCenter.x
        let dy = canvasCenter.y - graphCenter.y
        for i in nodes.indices {
            nodes[i].position.x += dx
            nodes[i].position.y += dy
        }
    }

    /// 单次力迭代。
    static func applyForces(
        nodes: inout [GraphNode],
        edges: [GraphEdge],
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        config: Config,
        temperature: CGFloat = 1.0
    ) {
        let nodeCount = nodes.count
        guard nodeCount > 0 else { return }

        var forces = Array(repeating: CGPoint.zero, count: nodeCount)

        // 1. 斥力计算 (Grid-based O(N))
        computeRepulsionForces(nodes: nodes, forces: &forces, config: config)

        // 2. 引力计算 (Edge-based O(E))
        computeAttractionForces(nodes: nodes, edges: edges, forces: &forces, config: config)

        // 3. 向心力与社区引力计算
        computeCenterAndClusterForces(
            nodes: nodes,
            forces: &forces,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            temperature: temperature,
            config: config
        )

        // 4. 应用力、阻尼系数与边界约束
        applyForcesAndConstraints(
            nodes: &nodes,
            forces: forces,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            temperature: temperature,
            config: config
        )
    }

    // MARK: - 物理仿真子模块

    /// 计算节点间的网格斥力
    private static func computeRepulsionForces(nodes: [GraphNode], forces: inout [CGPoint], config: Config) {
        let gridSize = GraphConstants.Physics.gridSize
        var grid: [Int: [Int]] = [:]

        for i in nodes.indices {
            let gx = Int(nodes[i].position.x / gridSize)
            let gy = Int(nodes[i].position.y / gridSize)
            let key = (gx << GraphConstants.Layout.gridHashShift) | (gy & GraphConstants.Layout.gridHashMask)
            grid[key, default: []].append(i)
        }

        for i in nodes.indices {
            let gx = Int(nodes[i].position.x / gridSize)
            let gy = Int(nodes[i].position.y / gridSize)

            for ox in -1...1 {
                for oy in -1...1 {
                    let key = ((gx + ox) << GraphConstants.Layout.gridHashShift) | ((gy + oy) & GraphConstants.Layout.gridHashMask)
                    guard let neighbors = grid[key] else { continue }

                    for j in neighbors where i < j {
                        let dx = nodes[i].position.x - nodes[j].position.x
                        let dy = nodes[i].position.y - nodes[j].position.y
                        let distSq = dx * dx + dy * dy

                        if distSq > GraphConstants.Physics.maxRepulsionDistanceSq || distSq < GraphConstants.Physics.minDistanceSq { continue }

                        let dist = sqrt(distSq)
                        let collisionForce: CGFloat = dist < GraphConstants.Physics.collisionDistance ? GraphConstants.Physics.collisionForce : 0
                        let force = (config.repulsion / distSq) + collisionForce

                        let fx = (dx / dist) * force
                        let fy = (dy / dist) * force

                        forces[i].x += fx
                        forces[i].y += fy
                        forces[j].x -= fx
                        forces[j].y -= fy
                    }
                }
            }
        }
    }

    /// 计算节点间的吸引力（边）
    private static func computeAttractionForces(nodes: [GraphNode], edges: [GraphEdge], forces: inout [CGPoint], config: Config) {
        let nodeIndexMap = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.id, $0.offset) })

        for edge in edges {
            guard let i = nodeIndexMap[edge.source], let j = nodeIndexMap[edge.target] else { continue }
            let dx = nodes[j].position.x - nodes[i].position.x
            let dy = nodes[j].position.y - nodes[i].position.y

            let distSq = dx * dx + dy * dy
            if distSq < 1 { continue }
            let dist = sqrt(distSq)

            let force = dist * config.attraction
            let fx = (dx / dist) * force
            let fy = (dy / dist) * force

            forces[i].x += fx
            forces[i].y += fy
            forces[j].x -= fx
            forces[j].y -= fy
        }
    }

    /// 计算中心向心力与社区聚合力
    private static func computeCenterAndClusterForces(
        nodes: [GraphNode],
        forces: inout [CGPoint],
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        temperature: CGFloat,
        config: Config
    ) {
        let centerX = canvasWidth / 2
        let centerY = canvasHeight / 2
        let effectiveGravity = config.centerGravity + (GraphConstants.Layout.temperatureBaseline - temperature) * GraphConstants.Layout.temperatureGravityCompensation

        var communityCenters: [Int: (sum: CGPoint, count: Int)] = [:]
        for node in nodes {
            if let commID = node.communityID {
                var current = communityCenters[commID, default: (.zero, 0)]
                current.sum.x += node.position.x
                current.sum.y += node.position.y
                current.count += 1
                communityCenters[commID] = current
            }
        }

        for i in nodes.indices {
            forces[i].x += (centerX - nodes[i].position.x) * effectiveGravity
            forces[i].y += (centerY - nodes[i].position.y) * effectiveGravity

            if let commID = nodes[i].communityID, let centerData = communityCenters[commID] {
                let center = CGPoint(x: centerData.sum.x / CGFloat(centerData.count), y: centerData.sum.y / CGFloat(centerData.count))
                let dx = center.x - nodes[i].position.x
                let dy = center.y - nodes[i].position.y
                let clusterAttraction: CGFloat = 0.05
                forces[i].x += dx * clusterAttraction
                forces[i].y += dy * clusterAttraction
            }
        }
    }

    /// 应用最终力、阻尼系数并执行画布边界检查
    private static func applyForcesAndConstraints(
        nodes: inout [GraphNode],
        forces: [CGPoint],
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        temperature: CGFloat,
        config: Config
    ) {
        let effectiveDamping = config.damping * temperature
        for i in nodes.indices {
            nodes[i].position.x += forces[i].x * effectiveDamping
            nodes[i].position.y += forces[i].y * effectiveDamping

            nodes[i].position.x = max(config.padding, min(canvasWidth - config.padding, nodes[i].position.x))
            nodes[i].position.y = max(config.padding, min(canvasHeight - config.padding, nodes[i].position.y))
        }
    }
}
