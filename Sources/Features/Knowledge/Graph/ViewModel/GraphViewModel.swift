//
//  GraphViewModel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：管理 Graph 视图的状态绑定与数据交互逻辑。
//
import SwiftUI
import Observation

@MainActor
@Observable
final class GraphViewModel {
    var selectedNodeID: UUID?
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var graphSize: CGSize = .zero
    var scale: CGFloat = 1.0
    var lastScale: CGFloat = 1.0
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero
    var isAnimating = false {
        didSet {
            if isAnimating {
                startSimulation()
            } else {
                stopSimulation()
            }
        }
    }
    /// 是否正在执行布局计算。初始为 true 表示"尚未完成首次加载"，
    /// 避免首帧渲染时 nodes 为空被误判为"确认无数据"而闪烁空状态视图。
    var isLayouting = true
    var showLegend = false
    var showInsights = false
    var useClustering = false
    var show3D = false
    var filterType: PageType?
    var insightSurprising: [UUID] = []
    var insightOrphans: [UUID] = []
    var insightSparse: [UUID] = []
    var insightBridges: [UUID] = []

    private var simulationTask: Task<Void, Never>?

    /// 获取FilteredNodes
    /// - Returns: 列表
    func getFilteredNodes() -> [GraphNode] {
        guard let filter = filterType else { return nodes }
        return nodes.filter { $0.pageType == filter }
    }

    /// 获取FilteredEdges
    /// - Returns: 列表
    func getFilteredEdges(for filteredNodes: [GraphNode]) -> [GraphEdge] {
        guard filterType != nil else { return edges }
        let filteredIDs = Set(filteredNodes.map { $0.id })
        return edges.filter { edge in
            filteredIDs.contains(edge.source) && filteredIDs.contains(edge.target)
        }
    }

    // MARK: - 物理仿真循环
    
    /// 开启物理仿真循环
    private func startSimulation() {
        guard simulationTask == nil else { return }
        
        simulationTask = Task {
            while !Task.isCancelled && isAnimating {
                // 在后台执行物理计算，避免阻塞主线程
                let currentNodes = self.nodes
                let currentEdges = self.edges
                let currentSize = self.graphSize
                
                guard !currentNodes.isEmpty else { break }
                
                // 性能优化：节点过多时，降低物理模拟的复杂度
                let iterationTemp: CGFloat = currentNodes.count > 500 ? 0.02 : 0.08
                
                var updatedNodes = currentNodes
                GraphLayoutProcessor.applyForces(
                    nodes: &updatedNodes,
                    edges: currentEdges,
                    canvasWidth: currentSize.width,
                    canvasHeight: currentSize.height,
                    config: .default,
                    temperature: iterationTemp
                )
                
                // 回到主线程更新状态
                await MainActor.run {
                    // 只有在动画仍然开启的情况下才应用更新
                    if self.isAnimating {
                        self.nodes = updatedNodes
                    }
                }
                
                // 控制帧率约 60FPS
                try? await Task.sleep(for: .nanoseconds(16_000_000))
            }
        }
    }
    
    /// 停止物理仿真循环
    private func stopSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
    }
}
