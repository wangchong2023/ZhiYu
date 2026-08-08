//
//  GraphCanvasView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 GraphCanvas 界面的 UI 视图层组件。
//
import SwiftUI

/// 知识图谱画布视图
/// 负责 2D 环境下的节点渲染、连线绘制及平移/缩放手法交互处理
struct GraphCanvasView: View {
    @Binding var nodes: [GraphNode]
    let filteredEdges: [GraphEdge]
    let provider: any GraphDataProvider
    let filterType: PageType?
    let useClustering: Bool
    @Binding var selectedNodeID: UUID?
    @Binding var isAnimating: Bool
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var graphSize: CGSize
    var heroNamespace: Namespace.ID
    let onNodeTap: (GraphNode) -> Void

    @Environment(\.interfaceIdiom) private var idiom

    var body: some View {
        if idiom == .watch {
            WatchFeaturePlaceholderView(placeholderMessage: L10n.Watch.graphCanvasPlaceholder)
        } else {
            GeometryReader { geometry in
                ZStack {
                    // 渲染边
                    Canvas { context, size in
                        drawEdges(in: context, size: size)
                    }
                    .frame(width: max(geometry.size.width, graphSize.width), height: max(geometry.size.height, graphSize.height))

                    // 渲染节点
                    let isLowDetail = scale < AppConfig.UI.graphLODZoomThreshold

                    ForEach(nodes.filter { filterType == nil || $0.pageType == filterType }) { node in
                        renderNode(node)

                        if !isLowDetail {
                            GraphNodeLabel(
                                node: node,
                                isSelected: selectedNodeID == node.id,
                                nodeSize: DesignSystem.Graph.nodeSizeReference
                            )
                        }
                    }
                }
                .offset(offset)
                .scaleEffect(scale)
                .gesture(zoomGesture)
                .simultaneousGesture(dragGesture)
                .onAppear { graphSize = geometry.size }
                .onChange(of: geometry.size) { _, newSize in
                    graphSize = newSize
                }
            }
        }
    }

    private func renderNode(_ node: GraphNode) -> some View {
        let isSelected = selectedNodeID == node.id
        // 简单高亮邻居判断
        let isNeighbor = selectedNodeID != nil && filteredEdges.contains { $0.source == selectedNodeID && $0.target == node.id || $0.target == selectedNodeID && $0.source == node.id }
        let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
        
        return GraphNodeView(
            node: node,
            isSelected: isSelected,
            isAnimating: isAnimating,
            linkCount: node.linkCount,
            clusters: provider.clusters,
            useClustering: useClustering,
            onSelect: { onNodeTap(node) },
            heroNamespace: heroNamespace,
            viewportRect: nil,
            scale: scale
        )
        .position(node.position)
        .opacity(isDimmed ? DesignSystem.dimmedOpacity : DesignSystem.fullOpacity)
    }
    
    private func drawEdges(in context: GraphicsContext, size _: CGSize) {
        let nodeLookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let isAnySelected = selectedNodeID != nil
        
        for edge in filteredEdges {
            guard let s = nodeLookup[edge.source], let t = nodeLookup[edge.target] else { continue }
            
            let isHighlighted = selectedNodeID == edge.source || selectedNodeID == edge.target
            let opacity = isHighlighted ? DesignSystem.secondaryOpacity : (isAnySelected ? DesignSystem.glassOpacity * 0.33 : DesignSystem.dimmedOpacity)
            let lineWidth: CGFloat = isHighlighted ? DesignSystem.Graph.highlightedLineWidth : 1.0
            
            var path = Path()
            path.move(to: s.position)
            path.addLine(to: t.position)
            
            if isHighlighted {
                let gradient = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [Color.fromModelColorName(s.pageType.colorName), Color.fromModelColorName(t.pageType.colorName)]),
                    startPoint: s.position, endPoint: t.position
                )
                context.stroke(path, with: gradient, lineWidth: lineWidth)
            } else {
                context.stroke(path, with: .color(.appBorder.opacity(opacity)), lineWidth: DesignSystem.borderWidth)
            }
        }
    }

    private var zoomGesture: some Gesture {
        if idiom == .watch {
            AnyGesture(TapGesture().map { _ in CGFloat(1.0) })
        } else {
            AnyGesture(MagnificationGesture().onChanged { v in scale = lastScale * v }.onEnded { _ in lastScale = scale })
        }
    }
    private var dragGesture: some Gesture {
        DragGesture().onChanged { v in offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height) }.onEnded { _ in lastOffset = offset }
    }
}
