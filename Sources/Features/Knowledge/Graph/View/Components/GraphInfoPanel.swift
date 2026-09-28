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
import UFPDesignSystem

// MARK: - Graph Selected Node Card
/// 选中节点的详情卡片。
/**
 * @description: 节点选中状态下的详情预览卡片，包含标题、类型、统计信息及跳转箭头
 * @return {View}
 */
/// 图谱选中节点详情卡片组件
/// 负责在选中节点时于底部弹出信息摘要卡片，展示页面核心元数据并提供跳转入口

/// 详情行组件：标题 + 副标题 + 箭头，消除 GraphSelectedNodeCard 与 GraphInsightsPanel 的重复布局
@ViewBuilder
private func detailChevronRow(title: String, subtitle: String, titleWeight: Font.Weight = .semibold) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
        Text(title)
            .font(.subheadline.weight(titleWeight))
            .foregroundStyle(.appText)
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.appSecondary)
    }
    Spacer()
    Image(systemName: DesignTokens.Icons.forward)
        .foregroundStyle(.appSecondary)
}

/// 标题 + 描述文本对，消除 guideRow 与 insightSectionExpandedContent 的重复 Text 链
@ViewBuilder
private func titleDescPair(title: String, desc: String) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(.appText)
        Text(desc)
            .font(.caption)
            .foregroundStyle(.appSecondary)
            .lineSpacing(DesignTokens.Spacing.atomic)
    }
}

struct GraphSelectedNodeCard: View {
    let page: KnowledgePage
    var heroNamespace: Namespace.ID?

    var body: some View {
        NavigationLink(value: AppRoute.pageDetail(id: page.id)) {
            cardContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignTokens.Spacing.standardPadding)
        .padding(.bottom, DesignTokens.Spacing.standardPadding)
    }

    /**
     * @description: 渲染卡片内部的主体布局与阴影装饰
     * @return {View}
     */
    private var cardContent: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: page.displayIcon)
                .foregroundStyle(Color.fromModelColorName(page.pageType.colorName))
                .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                .background(Color.fromModelColorName(page.pageType.colorName).opacity(DesignTokens.Colors.Opacity.glassOpacity))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))

            detailChevronRow(
                title: page.title,
                subtitle: "\(page.pageType.displayName)  \(page.wordCount) \(L10n.Knowledge.Page.wordCountUnit)  \(page.outgoingLinks.count) \(L10n.Knowledge.Page.outLinkUnit)"
            )
        }
        .cardStyle(
            horizontalPadding: DesignTokens.Spacing.standardPadding,
            verticalPadding: DesignTokens.Spacing.standardPadding,
            backgroundOpacity: DesignTokens.Opacity.dim,
            cornerRadius: DesignTokens.Spacing.mediumRadius
        )
        .shadow(color: Color.theme.black.opacity(DesignTokens.SystemOpacity.glassStrong), radius: DesignTokens.Spacing.mediumRadius)
    }
}

// MARK: - Graph Insights Panel
/// 图谱洞察面板，显示知识库的发现结果：意外关联、孤立页面、稀疏社区、桥接节点。
/// 知识图谱洞察分析面板
/// 集中展示图谱布局中的孤点、异常连接、聚类中心等核心发现。
/// 知识图谱洞察分析面板组件
/// 负责展示基于布局分析产生的深度发现，如意外关联、知识孤岛及核心桥接节点等
struct GraphInsightsPanel: View {
    let surprising: [UUID]
    let orphans: [UUID]
    let sparse: [UUID]
    let bridges: [UUID]
    let nodes: [GraphNode]
    let onSelectNode: (UUID) -> Void
    
    @State private var expandedSections: Set<String> = ["surprising", "orphans", "sparse", "bridges"]
    @State private var showGuide = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.standardPadding) {
                // 概念图解指南入口卡片 (Glassmorphism + Hover effect)
                Button {
                    showGuide = true
                } label: {
                    HStack(spacing: DesignTokens.Spacing.medium) {
                        Image(systemName: DesignTokens.Icons.questionmarkCircleFill)
                            .font(.title2)
                            .foregroundStyle(.appAccent)
                        
                        detailChevronRow(
                            title: L10n.Graph.guide.entryTitle,
                            subtitle: L10n.Graph.guide.entrySubtitle,
                            titleWeight: .bold
                        )
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous)
                            .stroke(Color.appAccent.opacity(DesignTokens.SystemOpacity.faint), lineWidth: DesignTokens.SystemStroke.hairline)
                    )
                    .shadow(color: Color.theme.black.opacity(DesignTokens.SystemOpacity.ghost), radius: DesignTokens.Spacing.shadowRadius, x: 0, y: DesignTokens.SystemShadow.offsetSmall)
                }
                .buttonStyle(.plain)
                .padding(.bottom, DesignTokens.Spacing.small)
                .sheet(isPresented: $showGuide) {
                    GraphConceptGuideSheet()
                }

                insightSection(
                    id: "surprising",
                    icon: DesignTokens.Icons.link,
                    title: L10n.Graph.insightSurprising,
                    count: surprising.count,
                    description: L10n.Graph.insightSurprisingDesc,
                    color: .appComparison
                )
                
                insightSection(
                    id: "orphans",
                    icon: DesignTokens.Icons.questionCircle,
                    title: L10n.Graph.insightOrphans,
                    count: orphans.count,
                    description: L10n.Graph.insightOrphansDesc,
                    color: .appSecondary
                )
                
                insightSection(
                    id: "sparse",
                    icon: DesignTokens.Icons.chartBarXaxis,
                    title: L10n.Graph.insightSparse,
                    count: sparse.count,
                    description: L10n.Graph.insightSparseDesc,
                    color: Color.theme.orange
                )
                
                insightSection(
                    id: "bridges",
                    icon: DesignTokens.Icons.arrowTriangleBranch,
                    title: L10n.Graph.insightBridges,
                    count: bridges.count,
                    description: L10n.Graph.insightBridgesDesc,
                    color: .appAccent
                )
            }
            .padding()
        }
        .background(PageBackgroundView(accentColor: .appAccent))
    }
    
    /// 提取 Header view 以缩短函数长度，完美打消 SwiftLint 警告
    @ViewBuilder
    private func sectionHeader(title: String, icon: String, count: Int, color: Color, isExpanded: Bool) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: DesignTokens.Spacing.iconLarge)
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.appText)
            
            // 饱和渐变发光 Badge
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.Chip.iconSpacing)
                .padding(.vertical, DesignTokens.Spacing.Chip.verticalPadding)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(DesignTokens.SystemOpacity.glassStrong)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: color.opacity(DesignTokens.Colors.Opacity.disabledOpacity), radius: DesignTokens.Spacing.smallRadius, x: 0, y: DesignTokens.Spacing.atomic)
            
            Spacer()
            
            Image(systemName: isExpanded ? DesignTokens.Icons.down : DesignTokens.Icons.forward)
                .font(.footnote)
                .foregroundStyle(.appSecondary)
        }
        .contentShape(Rectangle())
    }
    
    /// 渲染图分析报告中的单项洞察板块 (Glassmorphic + soft borders)
    private func insightSection(id: String, icon: String, title: String, count: Int, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.mediumRadius) {
            // Section header
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if expandedSections.contains(id) {
                        expandedSections.remove(id)
                    } else {
                        expandedSections.insert(id)
                    }
                }
            }) {
                sectionHeader(title: title, icon: icon, count: count, color: color, isExpanded: expandedSections.contains(id))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("insight-\(id)")
            
            if expandedSections.contains(id) {
                insightSectionExpandedContent(id: id, description: description, color: color)
                    .transition(.opacity.combined(with: .move(edge: .top)).animation(.easeInOut(duration: DesignTokens.Colors.Opacity.dimmedOpacity)))
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous)
                .fill(Color.appCard.opacity(DesignTokens.SystemOpacity.glassStrong))
        )
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(DesignTokens.SystemOpacity.glassStrong), color.opacity(DesignTokens.SystemOpacity.ghost)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DesignTokens.Spacing.borderWidth
                )
        )
        .shadow(color: Color.theme.black.opacity(DesignTokens.SystemOpacity.ghost), radius: DesignTokens.Spacing.mediumRadius, x: 0, y: DesignTokens.Spacing.smallRadius)
    }

    /// 渲染已展开分析板块的详情和节点推荐 Chips (微交互 & Hover 效果)
    private func insightSectionExpandedContent(id: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.mediumRadius) {
            Text(description)
                .font(.footnote)
                .foregroundStyle(.appSecondary)
                .padding(.leading, DesignTokens.Spacing.huge)
                .lineSpacing(DesignTokens.SystemSpacing.tight)
            
            // Node chips
            let nodeIDs = getNodeIDs(for: id)
            if !nodeIDs.isEmpty {
                FlowLayout(spacing: DesignTokens.Spacing.small) {
                    ForEach(nodeIDs, id: \.self) { nodeID in
                        if let node = nodes.first(where: { $0.id == nodeID }) {
                            Button(action: {
                                HapticFeedback.shared.trigger(.selection)
                                onSelectNode(nodeID)
                            }) {
                                HStack(spacing: DesignTokens.Spacing.Chip.iconSpacing) {
                                    Image(systemName: node.pageType.icon)
                                        .font(.caption)
                                    Text(node.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, DesignTokens.Spacing.medium)
                                .padding(.vertical, DesignTokens.Spacing.tiny)
                                .background(color.opacity(DesignTokens.SystemOpacity.ghost))
                                .overlay(
                                    Capsule()
                                        .stroke(color.opacity(DesignTokens.Colors.Opacity.dimmedOpacity), lineWidth: DesignTokens.Spacing.borderWidth)
                                )
                                .clipShape(Capsule())
                                .foregroundStyle(color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.leading, DesignTokens.Spacing.huge)
            }
        }
    }
    
    private func getNodeIDs(for section: String) -> [UUID] {
        switch section {
        case FeatureConstants.GraphInsightType.surprising: return surprising
        case FeatureConstants.GraphInsightType.orphans: return orphans
        case FeatureConstants.GraphInsightType.sparse: return sparse
        case FeatureConstants.GraphInsightType.bridges: return bridges
        default: return []
        }
    }
}

// MARK: - Graph Concept Guide Sheet
/// 知识图谱概念大白话指南弹窗 Sheet (双列卡片网格布局，信息结构清晰美观)
struct GraphConceptGuideSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.huge) {
                // 1. 头部标题
                HStack {
                    Label(L10n.Graph.guide.sheetTitle, systemImage: DesignTokens.Icons.infoCircleFill)
                        .font(.headline)
                        .foregroundStyle(.appAccent)
                    Spacer()
                    PanelCloseButton()
                }
                .padding(.bottom, DesignTokens.Spacing.medium)
                
                // 2. 3D 概念指南干净的图示
                VStack(spacing: 0) {
                    Image("graph_concepts_guide_clean")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius))
                        .shadow(color: Color.theme.black.opacity(DesignTokens.Colors.Opacity.translucentOpacity), radius: DesignTokens.Spacing.shadowRadius)
                }
                .appContainer(background: Color.appCard.opacity(DesignTokens.Colors.Opacity.surfaceOpacity), padding: false)
                
                // 3. SwiftUI 图例对照与大白话描述 (适配 iPad/Mac 的双列卡片网格布局，颜色与上图严格呼应)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DesignTokens.Spacing.medium),
                        GridItem(.flexible(), spacing: DesignTokens.Spacing.medium)
                    ],
                    spacing: DesignTokens.Spacing.medium
                ) {
                    guideRow(color: .appAccent, icon: "circle.fill", title: L10n.Graph.guide.legendNodeTitle, desc: L10n.Graph.guide.legendNodeDesc)
                    guideRow(color: .appSecondary, icon: "minus", title: L10n.Graph.guide.legendLinkTitle, desc: L10n.Graph.guide.legendLinkDesc)
                    guideRow(color: .appAccent, icon: "circle.fill", title: L10n.Graph.guide.typeConceptTitle, desc: L10n.Graph.guide.typeConceptDesc) // 对应图中蓝色左大簇
                    guideRow(color: .appEntity, icon: "circle.fill", title: L10n.Graph.guide.typeEntityTitle, desc: L10n.Graph.guide.typeEntityDesc) // 对应图中金色右大簇
                    guideRow(color: Color.theme.purple, icon: "circle.fill", title: L10n.Graph.guide.bridgeTitle, desc: L10n.Graph.guide.bridgeDesc) // 对应中间的紫色桥点
                    guideRow(color: Color.theme.orange, icon: "circle.fill", title: L10n.Graph.guide.sparseTitle, desc: L10n.Graph.guide.sparseDesc) // 对应左上角稀疏橙色簇
                    guideRow(color: Color.theme.gray, icon: "circle.fill", title: L10n.Graph.guide.orphanTitle, desc: L10n.Graph.guide.orphanDesc) // 对应右下角孤立灰色点
                    guideRow(color: .appComparison, icon: "bolt.fill", title: L10n.Graph.guide.surprisingTitle, desc: L10n.Graph.guide.surprisingDesc) // 对应中间粉红桥接线
                }
                
                Spacer(minLength: DesignTokens.Spacing.huge)
            }
            .padding(DesignTokens.Spacing.huge)
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
    }
    
    /// 实色饱满圆形 + 高对比度白图标的高阶排版，在深浅色模式下都拥有完美的色彩表现力与无障碍阅读对比度
    private func guideRow(color: Color, icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: DesignTokens.Spacing.iconHuge, height: DesignTokens.Spacing.iconHuge)
                Image(systemName: icon)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
            }
            
            titleDescPair(title: title, desc: desc)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .borderedCardStyle(
            horizontalPadding: DesignTokens.Spacing.standardPadding,
            verticalPadding: DesignTokens.Spacing.standardPadding,
            backgroundOpacity: DesignTokens.SystemOpacity.glass,
            cornerRadius: DesignTokens.Spacing.mediumRadius
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous)
                .stroke(Color.appBorder.opacity(DesignTokens.SystemOpacity.overlay), lineWidth: DesignTokens.SystemStroke.hairline)
        )
    }
}
