//
//  GraphView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Graph 界面的 UI 视图层组件。
//
import SwiftUI
import Observation

// MARK: - 图谱容器
@MainActor
/// 知识图谱顶层容器
/// 负责管理图谱画布、统计信息、过滤器及详情卡片的组合布局
struct GraphContainerView: View {
    @Environment(AppStore.self) var appStore
    @Environment(KnowledgeStore.self) var store
    @Environment(Router.self) var router
    var heroNamespace: Namespace.ID
    @Binding var selectedTab: AppTab
    @EnvironmentObject var themeManager: ThemeManager
    @State private var viewModel = GraphViewModel()
    @StateObject private var tooltipManager = TooltipManager.shared

    /// 每个节点最多保留的重要连线数
    private var maxEdgesPerNode: Int { GraphConstants.maxEdgesPerNode }

    /// 动态过滤后的边列表：每节点仅保留最重要 K 条连线，避免密集时视觉混乱
    private var currentFilteredEdges: [GraphEdge] {
        let filteredNodes = viewModel.getFilteredNodes()
        let allEdges = viewModel.getFilteredEdges(for: filteredNodes)
        let filteredIDs = Set(filteredNodes.map(\.id))

        // 计算每条边的权重（两端节点 linkCount 之和）
        var edgeWeights: [UUID: Int] = [:]
        for edge in allEdges where filteredIDs.contains(edge.source) && filteredIDs.contains(edge.target) {
            let srcLinks = viewModel.nodes.first(where: { $0.id == edge.source })?.linkCount ?? 0
            let tgtLinks = viewModel.nodes.first(where: { $0.id == edge.target })?.linkCount ?? 0
            edgeWeights[edge.id] = srcLinks + tgtLinks
        }

        // 按每个 source 节点分组，取 Top K 权重边
        let groupedBySource = Dictionary(grouping: allEdges) { $0.source }
        let topEdges = groupedBySource.flatMap { _, edges in
            edges.sorted { (edgeWeights[$0.id] ?? 0) > (edgeWeights[$1.id] ?? 0) }
                .prefix(maxEdgesPerNode)
        }

        return topEdges
    }

    /// 是否正在截断连线
    private var isTruncatingEdges: Bool {
        let allEdges = viewModel.getFilteredEdges(for: viewModel.getFilteredNodes())
        let filteredIDs = Set(viewModel.getFilteredNodes().map(\.id))
        let relevantEdges = allEdges.filter { filteredIDs.contains($0.source) && filteredIDs.contains($0.target) }
        return relevantEdges.count > currentFilteredEdges.count
    }

    var body: some View {
        // 强制 @Observable 追踪：确保 store.pages 变更时触发重绘
        ZStack {
            // 始终捕获画布尺寸，避免鸡-蛋死锁：
            // nodes 为空 → 不渲染 GraphCanvasView → GeometryReader 不触发
            // → graphSize=.zero → layoutGraph() 守卫失败 → nodes 永远为空
            GeometryReader { geometry in
                Color.clear
                    .onAppear { viewModel.graphSize = geometry.size }
                    .onChange(of: geometry.size) { _, newSize in viewModel.graphSize = newSize }
            }
            themeManager.pageBackground()
                .ignoresSafeArea()

            if viewModel.isLayouting {
                // 首次加载中：显示加载指示器，避免闪烁空状态视图
                VStack(spacing: DesignSystem.standardPadding) {
                    ProgressView()
                        .controlSize(.large)
                    Text(L10n.Common.loading)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                }
            } else if viewModel.nodes.isEmpty {
                GraphEmptyStateView(selectedTab: $selectedTab)
            } else {
                // 2. 主体布局：标题/过滤项 + 画布
                VStack(spacing: DesignSystem.medium) {
                    // 顶部非描边区域：统计与过滤器
                    VStack(alignment: .leading, spacing: DesignSystem.medium) {
                        graphStatsBar
                        
                        GraphFilterPillsView(
                            filterType: $viewModel.filterType,
                            tooltipManager: tooltipManager
                        )
                    }
                    .padding(.horizontal, DesignSystem.standardPadding)
                    .padding(.top, DesignSystem.medium)
                    .zIndex(10) // 确保在画布之上

                    // 核心绘图区：应用柔和边框与裁剪
                    ZStack {
                        GraphCanvasView(
                            nodes: $viewModel.nodes,
                            filteredEdges: currentFilteredEdges,
                            provider: appStore,
                            filterType: viewModel.filterType,
                            useClustering: viewModel.useClustering,
                            selectedNodeID: $viewModel.selectedNodeID,
                            isAnimating: $viewModel.isAnimating,
                            scale: $viewModel.scale,
                            lastScale: $viewModel.lastScale,
                            offset: $viewModel.offset,
                            lastOffset: $viewModel.lastOffset,
                            graphSize: $viewModel.graphSize,
                            heroNamespace: heroNamespace
                        ) { node in
                            handleNodeTap(node)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissCard()
                        }
                        // MARK: - A11y 专项适配
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(L10n.Graph.accessibility.canvasLabel)
                        .accessibilityHint(L10n.Graph.accessibility.canvasHint)
                    }
                    .background(DesignSystem.containerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                            .stroke(DesignSystem.containerBorder, lineWidth: DesignSystem.borderWidth)
                    )
                    .padding(.horizontal, DesignSystem.standardPadding)
                    .padding(.bottom, DesignSystem.standardPadding)
                }
            }
        }
        .onReceive(AppEventBus.shared.subscribe()) { event in
            switch event {
            case .pagesCleared, .graphRelayoutRequested:
                layoutGraph()
            default: break
            }
        }
        .appTabToolbar(title: L10n.Graph.title)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: store.pages.count) { _, _ in layoutGraph() }
        .onChange(of: viewModel.graphSize) { _, newSize in
            if newSize != .zero { layoutGraph() }
        }
        .task {
            layoutGraph()
        }
        .sheet(isPresented: $viewModel.showInsights) {
            insightsPanel
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $viewModel.show3D) {
            NavigationStack {
                Graph3DView(selectedNodeID: $viewModel.selectedNodeID, isFullScreen: $viewModel.show3D)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // 3. 动态联动的缩放工具栏
            if !viewModel.nodes.isEmpty {
                GraphZoomControls(
                    scale: $viewModel.scale,
                    lastScale: $viewModel.lastScale,
                    offset: $viewModel.offset,
                    lastOffset: $viewModel.lastOffset,
                    show3D: $viewModel.show3D,
                    onRelayout: layoutGraph,
                    onFitToScreen: fitToScreen
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.standardRadius).stroke(Color.appBorder.opacity(DesignSystem.disabledOpacity), lineWidth: DesignSystem.borderWidth))
                .padding(.trailing, DesignSystem.Graph.toolbarPaddingTrailing)
                .padding(.bottom, viewModel.selectedNodeID != nil ? DesignSystem.Graph.toolbarPaddingBottomExpanded : DesignSystem.Graph.toolbarPaddingBottomDefault)
                .animation(DesignSystem.standardAnimation, value: viewModel.selectedNodeID)
            }
        }
        .overlay(alignment: .bottom) {
            // 4. 详情卡片
            if let selectedID = viewModel.selectedNodeID,
               let page = store.pages.first(where: { $0.id == selectedID }) {
                GraphSelectedNodeCard(page: page)
                    .padding(.bottom, DesignSystem.loosePadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /**
     * @description: 关闭当前选中的节点详情卡片并停止高亮动画
     * @return {*}
     */
    private func dismissCard() {
        withAnimation(DesignSystem.Animation.standard) {
            viewModel.selectedNodeID = nil
            viewModel.isAnimating = false
        }
    }

    /**
     * @description: 处理节点点击事件：切换选中状态、相机自动聚焦定位、触发震动反馈
     * @param {GraphNode} node 被点击的节点对象
     * @return {*}
     */
    private func handleNodeTap(_ node: GraphNode) {
        withAnimation(DesignSystem.Animation.prominent) {
            if viewModel.selectedNodeID == node.id {
                viewModel.selectedNodeID = nil
                viewModel.isAnimating = false
            } else {
                viewModel.selectedNodeID = node.id
                viewModel.isAnimating = true
                
                // 聚焦逻辑：计算偏移量使节点居中
                // 核心修复：先平移后缩放，简化计算公式
                let centerX = viewModel.graphSize.width / 2
                let centerY = viewModel.graphSize.height / 2
                
                viewModel.offset = CGSize(
                    width: centerX - node.position.x,
                    height: centerY - node.position.y
                )
                viewModel.lastOffset = viewModel.offset
                if viewModel.scale < 1.0 { 
                    viewModel.scale = 1.2
                    viewModel.lastScale = 1.2 
                }
            }
        }
        HapticFeedback.shared.trigger(.selection)
    }

    /**
     * @description: 渲染图谱顶部的统计信息栏与洞察分析入口
     * @return {View}
     */
    private var graphStatsBar: some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            computeInsights()
            viewModel.showInsights = true
        }) {
            HStack(spacing: DesignSystem.tiny + DesignSystem.atomic) {
                Image(systemName: DesignSystem.Icons.sparkles)
                    .font(.system(size: DesignSystem.microFontSize, weight: .bold))
                    .foregroundStyle(.appAccent)
                
                Text(L10n.Graph.nodesConnections(viewModel.getFilteredNodes().count, currentFilteredEdges.count))
                    .font(.system(size: DesignSystem.microFontSize, weight: .bold))
                    .foregroundStyle(.appSecondary)

                if isTruncatingEdges {
                    Text(L10n.Graph.edgeTruncationHint(maxEdgesPerNode))
                        .font(.system(size: DesignSystem.microFontSize, weight: .regular))
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                }
                
                Image(systemName: DesignSystem.Icons.forward)
                    .font(.system(size: DesignSystem.microFontSize, weight: .bold))
                    .foregroundStyle(.appAccent.opacity(DesignSystem.softOpacity))
            }
            .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
            .padding(.vertical, DesignSystem.Chip.verticalPadding)
            .background(
                Capsule()
                    .fill(Color.appAccent.opacity(DesignSystem.glassOpacity * 0.5))
            )
            .overlay(
                Capsule()
                    .stroke(Color.appAccent.opacity(DesignSystem.disabledOpacity * 0.5), lineWidth: DesignSystem.borderWidth)
            )
            .shadow(color: .black.opacity(DesignSystem.ghostOpacity * 3), radius: DesignSystem.atomic * 2, x: 0, y: DesignSystem.borderWidth)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        // MARK: - A11y 专项适配
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Graph.accessibility.statsBarLabel)
        .accessibilityValue(L10n.Graph.nodesConnections(viewModel.getFilteredNodes().count, viewModel.getFilteredEdges(for: viewModel.getFilteredNodes()).count))
        .accessibilityHint(L10n.Graph.accessibility.statsBarHint)
    }

    /**
     * @description: 调用 GraphLayoutProcessor 计算知识图谱的发现与洞察信息
     * @return {*}
     */
    private func computeInsights() {
        let insights = GraphLayoutProcessor.detectInsights(
            nodes: viewModel.nodes,
            edges: viewModel.edges,
            pages: store.pages
        )
        viewModel.insightSurprising = insights.surprising
        viewModel.insightOrphans = insights.orphans
        viewModel.insightSparse = insights.sparse
        viewModel.insightBridges = insights.bridges
    }

    /**
     * @description: 执行核心布局算法：将 KnowledgePages 转换为 GraphNodes 与 Edges，并应用自适应缩放
     * @return {*}
     */
    private func layoutGraph() {
        guard viewModel.graphSize != .zero else { return }
        let pages = store.pages
        if pages.isEmpty {
            viewModel.nodes = []
            viewModel.edges = []
            viewModel.isLayouting = false
            return
        }

        viewModel.isLayouting = true
        Task {
            let canvasSize = viewModel.graphSize
            let result = await Task.detached {
                return GraphLayoutProcessor.layout(
                    pages: pages,
                    linkResolver: { t in pages.first(where: { $0.title == t }) },
                    canvasSize: canvasSize
                )
            }.value
            await MainActor.run {
                viewModel.nodes = result.nodes
                viewModel.edges = result.edges
                viewModel.isLayouting = false
                fitToScreen()
            }
        }
    }

    /**
     * @description: 计算最佳缩放比例与偏移量，使所有节点完整展示在屏幕视野内
     * @return {*}
     */
    private func fitToScreen() {
        guard !viewModel.nodes.isEmpty else { return }
        let minX = viewModel.nodes.map(\.position.x).min() ?? 0
        let maxX = viewModel.nodes.map(\.position.x).max() ?? 0
        let minY = viewModel.nodes.map(\.position.y).min() ?? 0
        let maxY = viewModel.nodes.map(\.position.y).max() ?? 0
        let padding: CGFloat = DesignSystem.Graph.layoutPadding
        let scaleX = (viewModel.graphSize.width - padding * 2) / max(maxX - minX, DesignSystem.Graph.minLayoutDimension)
        let scaleY = (viewModel.graphSize.height - padding * 2) / max(maxY - minY, DesignSystem.Graph.minLayoutDimension)
        let targetScale = min(max(min(scaleX, scaleY), DesignSystem.Graph.minScale), DesignSystem.Graph.maxScale)
        let targetOffsetX = (viewModel.graphSize.width / 2 - (minX + maxX) / 2) * targetScale
        let targetOffsetY = (viewModel.graphSize.height / 2 - (minY + maxY) / 2) * targetScale
        withAnimation(.spring()) {
            viewModel.scale = targetScale
            viewModel.offset = CGSize(width: targetOffsetX, height: targetOffsetY)
            viewModel.lastScale = targetScale
            viewModel.lastOffset = viewModel.offset
        }
    }
    
    /**
     * @description: 渲染图谱洞察侧边面板
     * @return {View}
     */
    private var insightsPanel: some View {
        NavigationStack {
            GraphInsightsPanel(
                surprising: viewModel.insightSurprising,
                orphans: viewModel.insightOrphans,
                sparse: viewModel.insightSparse,
                bridges: viewModel.insightBridges,
                nodes: viewModel.nodes,
                onSelectNode: { nodeID in
                    if let node = viewModel.nodes.first(where: { $0.id == nodeID }) {
                        handleNodeTap(node)
                    }
                    viewModel.showInsights = false
                }
            )
            .navigationTitle(L10n.Graph.insights)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { viewModel.showInsights = false }
                }
            }
        }
    }
}
