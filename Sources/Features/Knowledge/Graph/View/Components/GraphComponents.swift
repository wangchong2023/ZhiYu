//
//  GraphComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识图谱：3D 可视化、社区发现、力导向布局。
//
import SwiftUI

// MARK: - 图谱组件常量（组件特定尺寸，无对应命名 token）
private enum GraphViewConstants {
    /// 图谱节点徽章 Y 轴偏移 (36pt)
    static let badgeOffset: CGFloat = 36
}

// MARK: - Graph Node View
/// 图谱中的单个节点渲染组件。
/// 具备三级渲染能力：
/// 1. 选中高亮态：展示发光光晕与呼吸脉冲。
/// 2. 常规态：展示类型图标与标准尺寸。
/// 3. LOD 低细节态：远景下自动精简为纯色圆点，确保千级节点下的流畅度。
/// 知识图谱节点视图组件
/// 负责单个节点的视觉呈现、LOD (细节分级) 渲染、发光动画及交互反馈。
/// 知识图谱节点视图组件
/// 负责单个节点的视觉呈现、LOD (细节分级) 渲染、发光动画及交互反馈
struct GraphNodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isAnimating: Bool
    let linkCount: Int
    let clusters: [GraphClusteringService.Cluster]
    let useClustering: Bool
    let onSelect: () -> Void
    var heroNamespace: Namespace.ID
    @State private var isHovered = false
    @Environment(\.interfaceIdiom) private var idiom
    
    // 视口裁剪参数
    let viewportRect: CGRect? // 当前可见区域
    let scale: CGFloat
    
    private var isVisible: Bool {
        guard let rect = viewportRect else { return true }
        // 简单的包围盒检测
        let margin: CGFloat = DesignSystem.huge
        return rect.insetBy(dx: -margin, dy: -margin).contains(node.position)
    }

    private var nodeSize: CGFloat {
        isSelected ? 32 : max(18, min(30, 20 + CGFloat(linkCount) * 1.5))
    }

    var body: some View {
        Group {
            if isVisible {
                let nodeBaseColor: Color = {
                    if useClustering, let cluster = clusters.first(where: { $0.pageIDs.contains(node.id) }) {
                        return Color.fromModelColorName(cluster.colorName)
                    }
                    return Color.fromModelColorName(node.pageType.colorName)
                }()
                let isLowDetail = scale < AppConfig.UI.graphLODZoomThreshold
                
                ZStack {
                    if isLowDetail {
                        // LOD: 远景模式 - 仅显示纯色圆点，极致性能
                        Circle()
                            .fill(nodeBaseColor)
                            .frame(width: DesignSystem.iconSmall, height: DesignSystem.iconSmall)
                    } else {
                        nodeContent
                    }
                }
                .onTapGesture { 
                    HapticFeedback.shared.trigger(.link)
                    onSelect() 
                }
            }
        }
    }
    
    @ViewBuilder
    private var nodeContextMenu: some View {
        Button(action: { onSelect() }) {
            Label(L10n.Graph.viewDetail, systemImage: DesignSystem.Icons.weeklyInsight)
        }
        Button(action: {
            let link = "[[\(node.title)]]"
            AppPasteboard.string = link
        }) {
            Label(L10n.Graph.copyPageLink, systemImage: DesignSystem.Icons.link)
        }
        Divider()
        if idiom == .mac {
            Button(action: { }) {
                Label(L10n.Graph.openInNewWindow, systemImage: DesignSystem.Icons.macwindowBadgePlus)
            }
        }
    }
    
    private var nodeContent: some View {
        ZStack {
            let nodeBaseColor = useClustering ? (clusters.first(where: { $0.pageIDs.contains(node.id) }).map { Color.fromModelColorName($0.colorName) } ?? Color.fromModelColorName(node.pageType.colorName)) : Color.fromModelColorName(node.pageType.colorName)

            // 1. 深度发光 (Aura Effect)
            if isSelected {
                Circle()
                    .fill(nodeBaseColor.opacity(DesignSystem.glassOpacity))
                    .frame(width: nodeSize * 2.2, height: nodeSize * 2.2)
                    .blur(radius: DesignSystem.cardRadius)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            }

            // 2. 核心脉冲 (Core Pulse)
            if isSelected {
                Circle()
                    .stroke(nodeBaseColor.opacity(SystemOpacity.disabled), lineWidth: SystemStroke.divider)
                    .frame(width: nodeSize, height: nodeSize)
                    .scaleEffect(isAnimating ? 1.8 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isAnimating)
            }

            // 3. 节点本体 (Node Body)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [nodeBaseColor.opacity(DesignSystem.Opacity.pressed), nodeBaseColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .matchedGeometryEffectIfAvailable(id: node.id, in: heroNamespace, isSource: true)
                .frame(width: nodeSize, height: nodeSize)
                .onHoverIfAvailable { hovering in
                    withAnimation(.spring()) {
                        isHovered = hovering
                    }
                    if hovering {
                        HapticFeedback.shared.trigger(.selection)
                    }
                }
                .overlay {
                    hoverTooltip
                }
                .contextMenu { nodeContextMenu }
                .overlay(
                    Circle()
                        .stroke(.appGloss.opacity(SystemOpacity.glassStrong), lineWidth: DesignSystem.borderWidth)
                )
                .shadow(color: nodeBaseColor.opacity(isSelected ? SystemOpacity.textSecondary : SystemOpacity.disabled), radius: isSelected ? DesignSystem.standardPadding : SystemSpacing.small)
                .scaleEffect(isSelected ? 1.1 : 1.0)

            // 4. 类型图标
            Image(systemName: node.pageType.icon)
                .font(.system(size: isSelected ? DesignSystem.subheadlineFontSize : DesignSystem.microFontSize, weight: .bold))
                .foregroundStyle(.white)
        }
        .onTapGesture {
            HapticFeedback.shared.trigger(.link)
            onSelect()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.title), \(node.pageType.displayName)")
        .accessibilityValue(L10n.Graph.linksCountFormat(linkCount))
        .accessibilityHint(L10n.Graph.accessibility.nodeHint)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
        .accessibilityAction { onSelect() }
    }
    
    @ViewBuilder
    private var hoverTooltip: some View {
        if isHovered {
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(node.title)
                    .font(.caption.bold())
                Text(node.pageType.displayName)
                    .font(.system(size: Reference.FontSize.micro))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignSystem.small)
            .padding(.vertical, DesignSystem.tiny)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            .offset(y: -GraphViewConstants.badgeOffset)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Graph Node Label
/// 节点标题标签组件
/// 负责在节点下方渲染动态标题，具备自动 LOD（细节层次）切换能力。
/// 知识图谱节点标签组件
/// 负责在节点下方显示页面标题，并根据缩放比例（LOD）动态调整可见度与字号
struct GraphNodeLabel: View {
    /// 目标节点数据
    let node: GraphNode
    /// 选中状态，用于加粗字体与变色
    let isSelected: Bool
    /// 基础节点尺寸，用于计算垂直偏移
    let nodeSize: CGFloat
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 动态字号计算：针对不同屏幕尺寸进行微调
    /// 大屏幕（iPad）下字号从 11pt 提升到 9pt，手机端保持 8pt，确保视觉比例和谐
    private var fontSize: CGFloat {
        horizontalSizeClass == .regular ? 10 : 8
    }

    var body: some View {
        Text(node.title)
            .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? .appText : .appSecondary)
            .lineLimit(1)
            .position(x: node.position.x, y: node.position.y + nodeSize / 2 + DesignSystem.mediumRadius)
            .accessibilityHidden(true) // 节点图标已包含信息，标签设为隐藏以防冗余
    }
}

// MARK: - Graph Zoom Controls
/// 缩放控制栏。
/// 图谱缩放与交互控制组件
/// 负责提供缩放、居中、刷新布局、适应屏幕及 3D 视图切换的一站式控制功能
struct GraphZoomControls: View {
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var show3D: Bool
    let onRelayout: () -> Void
    let onFitToScreen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation { scale = max(0.5, scale - 0.2) }
                lastScale = scale
            }) {
                Image(systemName: DesignSystem.Icons.minusMagnifyingglass)
                    .font(.body)
                    .foregroundStyle(.appSecondary)
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .background(Color.appCard)
            }
            .accessibilityIdentifier("zoom-out")
            .accessibilityLabel(L10n.Graph.accessibility.zoomOutLabel)
            .accessibilityHint(L10n.Graph.accessibility.zoomOutHint)

            Button(action: {
                withAnimation { scale = min(3.0, scale + 0.2) }
                lastScale = scale
            }) {
                Image(systemName: DesignSystem.Icons.plusMagnifyingglass)
                    .font(.body)
                    .foregroundStyle(.appSecondary)
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .background(Color.appCard)
            }
            .accessibilityIdentifier("zoom-in")
            .accessibilityLabel(L10n.Graph.accessibility.zoomInLabel)
            .accessibilityHint(L10n.Graph.accessibility.zoomInHint)

            Divider().frame(width: DesignSystem.borderWidth, height: DesignSystem.iconLarge).background(Color.appBorder)

            Button(action: {
                withAnimation {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }) {
                Image(systemName: DesignSystem.Icons.scope)
                    .font(.body)
                    .foregroundStyle(.appSecondary)
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .background(Color.appCard)
            }
            .accessibilityIdentifier("reset")
            .accessibilityLabel(L10n.Graph.accessibility.resetLabel)
            .accessibilityHint(L10n.Graph.accessibility.resetHint)

            Divider().frame(width: DesignSystem.borderWidth, height: DesignSystem.iconLarge).background(Color.appBorder)

            Button(action: {
                withAnimation(.spring(response: 0.5)) { onFitToScreen() }
            }) {
                Image(systemName: DesignSystem.Icons.viewfinder)
                    .font(.body)
                    .foregroundStyle(.appSecondary)
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .background(Color.appCard)
            }
            .accessibilityIdentifier("fit-to-screen")
            .accessibilityLabel(L10n.Graph.accessibility.fitToScreenLabel)
            .accessibilityHint(L10n.Graph.accessibility.fitToScreenHint)

            Divider().frame(width: DesignSystem.borderWidth, height: DesignSystem.iconLarge).background(Color.appBorder)

            Button(action: {
                withAnimation(.spring(response: 0.6)) { onRelayout() }
            }) {
                Image(systemName: DesignSystem.Icons.refresh)
                    .font(.body)
                    .foregroundStyle(.appSecondary)
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .background(Color.appCard)
            }
            .accessibilityIdentifier("relayout")
            .accessibilityLabel(L10n.Graph.accessibility.relayoutLabel)
            .accessibilityHint(L10n.Graph.accessibility.relayoutHint)

            Divider().frame(width: DesignSystem.borderWidth, height: DesignSystem.iconLarge).background(Color.appBorder)

            Button(action: { show3D = true }) {
                Image(systemName: DesignSystem.Icons.view3d)
                    .font(.body)
                    .foregroundStyle(.appSecondary)
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .background(Color.appCard)
            }
            .accessibilityIdentifier("graph-3d")
            .accessibilityLabel(L10n.Graph.accessibility.threeDLabel)
            .accessibilityHint(L10n.Graph.accessibility.threeDHint)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        .shadow(color: .black.opacity(DesignSystem.Opacity.ghost), radius: 5, y: 2)
    }
}
