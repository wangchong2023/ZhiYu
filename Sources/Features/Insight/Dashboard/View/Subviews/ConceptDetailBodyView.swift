//
//  ConceptDetailBodyView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：渲染“主题 (Concept)”类型页面的差异化排版，包含交互式局部脑图、知识大纲树及认知碰撞卡片。
//

import SwiftUI
import UFPCore

/// [L3] 表现层：主题页面差异化详情视图
struct ConceptDetailBodyView: View {
    let page: KnowledgePage
    let onLinkTap: (String) -> Void
    
    @State private var frontmatter: ConceptFrontmatter?
    @State private var bodyText: String = ""
    @State private var expandedNodes: Set<String> = []
    
    // 布局微调常数，防止魔鬼数字与 frame/padding 写死
    private static let graphHeight: CGFloat = 160
    private static let outlineSpacing: CGFloat = 8
    private static let indentStep: CGFloat = 16
    private static let limitOutgoingCount = 5
    
    private static let nodeDotSize: CGFloat = 6
    private static let derivedDotSize: CGFloat = 4
    private static let tagIconSize: CGFloat = 8
    private static let insightBadgeSize: CGFloat = 9
    private static let connectionLineWidth: CGFloat = 1.5
    private static let centralNodeShadowRadius: CGFloat = 6.0
    private static let neighborNodeBorderWidth: CGFloat = 1.0
    private static let neighborNodeAngleScale: Double = 0.35
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
            // 1. 局部关系脑图 (Local Relation Graph)
            localRelationGraphSection
            
            // 2. 认知碰撞卡 (Surprising Insights)
            if let insights = frontmatter?.surprisingInsights, !insights.isEmpty {
                insightsSection(insights)
            }
            
            // 3. 知识脉络树 (Outlines Tree)
            outlinesTreeSection
            
            DetailBodyEpilogue(page: page, bodyText: bodyText, onLinkTap: onLinkTap)
        }
        .onAppear {
            let result = DetailBodyFrontmatterHelper.parse(content: page.content, frontmatterType: ConceptFrontmatter.self)
            self.bodyText = result.bodyText
            self.frontmatter = result.frontmatter
        }
    }
    
    // MARK: - 1. 局部关系脑图 (Local Relation Graph)
    private var localRelationGraphSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            InsightSectionHeader(title: L10n.Graph.title, icon: "point.3.connected.trianglepath.dotted")
            
            ZStack {
                // 脑图背景卡片
                RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                    .fill(Color.appCard.opacity(DesignSystem.Opacity.ghost))
                    .frame(height: Self.graphHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                            .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                    )
                
                let outgoing = Array(page.outgoingLinks.prefix(Self.limitOutgoingCount))
                
                if outgoing.isEmpty {
                    Text(L10n.Search.noResults)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                } else {
                    // 精巧自适应 SwiftUI 交互式圆形拓扑脑图
                    GeometryReader { geo in
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        // 动态根据几何视图宽高计算周边节点推离半径，防止碰撞挤压
                        let radius = min(geo.size.width, geo.size.height) * Self.neighborNodeAngleScale
                        
                        // 1. 绘制连接线
                        Path { path in
                            for index in 0..<outgoing.count {
                                let point = neighborNodePoint(index: index, total: outgoing.count, center: center, radius: radius)
                                path.move(to: center)
                                path.addLine(to: point)
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [.appAccent, .appAccent.opacity(DesignSystem.Opacity.disabled)],
                                startPoint: .center,
                                endPoint: .trailing
                            ),
                            lineWidth: Self.connectionLineWidth
                        )
                        
                        // 2. 绘制周边关联词条节点 (按极坐标角度分布)
                        ForEach(Array(outgoing.enumerated()), id: \.offset) { index, link in
                            let nodePoint = neighborNodePoint(index: index, total: outgoing.count, center: center, radius: radius)

                            Button(action: {
                                onLinkTap(link)
                            }) {
                                HStack(spacing: DesignSystem.tightPadding) {
                                    Image(systemName: DesignSystem.Icons.tagFill)
                                        .font(.system(size: Self.tagIconSize))
                                    Text(link)
                                        .font(.caption2.weight(.medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.appText)
                                .padding(.horizontal, DesignSystem.medium)
                                .padding(.vertical, DesignSystem.tightPadding)
                                .background(Color.appCard)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.appAccent.opacity(DesignSystem.Opacity.prominent), lineWidth: Self.neighborNodeBorderWidth)
                                )
                                .shadow(color: Color.appText.opacity(DesignSystem.Opacity.shadow), radius: 3)
                            }
                            .position(nodePoint)
                        }

                        // 3. 绘制中心主题节点 (自适应长宽胶囊，防截断)
                        Button {
                            // Center node action
                        } label: {
                            HStack(spacing: DesignSystem.tightPadding) {
                                Circle()
                                    .fill(Color.appCard)
                                    .frame(width: DesignSystem.iconTiny, height: DesignSystem.iconTiny)
                                Text(page.title)
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                            }
                            .accentCapsuleStyle(
                                horizontalPadding: DesignSystem.standardPadding,
                                verticalPadding: DesignSystem.tightPadding,
                                gradientEndOpacity: DesignSystem.Opacity.prominent
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.appAccent.opacity(DesignSystem.Opacity.medium), lineWidth: Self.neighborNodeBorderWidth)
                            )
                            .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: Self.centralNodeShadowRadius)
                        }
                        .position(center)
                    }
                }
            }
            .frame(height: Self.graphHeight)
        }
    }
    
    // MARK: - 2. 认知碰撞卡 (Surprising Insights)
    private func insightsSection(_ insights: [ConceptFrontmatter.SurprisingInsight]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            InsightSectionHeader(title: L10n.Dashboard.stats.citationAccuracy, icon: DesignSystem.Icons.sparkles, color: Color.theme.orange)
            
            ForEach(insights, id: \.insightTitle) { insight in
                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                    HStack {
                        Text(insight.insightTitle)
                            .font(.caption.bold())
                            .foregroundStyle(.appText)
                        Spacer()
                        Button(action: {
                            onLinkTap(insight.linkedConceptID)
                        }) {
                            Text(insight.linkedConceptID)
                                .font(.system(size: Self.insightBadgeSize, weight: .bold))
                                .foregroundStyle(Color.theme.orange)
                                .padding(.horizontal, Spacing.tiny)
                                .padding(.vertical, Spacing.atomic)
                                .background(Color.theme.orange.opacity(DesignSystem.subtleFillOpacity))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(insight.reason)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
                .borderedCardStyle(
                    horizontalPadding: DesignSystem.medium,
                    verticalPadding: DesignSystem.medium,
                    backgroundOpacity: DesignSystem.Opacity.soft,
                    cornerRadius: DesignSystem.standardRadius,
                    borderWidth: Self.neighborNodeBorderWidth,
                    borderColor: Color.theme.orange,
                    borderOpacity: DesignSystem.Opacity.disabled
                )
            }
        }
    }
    
    // MARK: - 3. 知识脉络树 (Outlines Tree)
    private var outlinesTreeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            InsightSectionHeader(title: L10n.Editor.toc, icon: DesignSystem.Icons.listBulletIndent)
            
            if let outlines = frontmatter?.outlines, !outlines.isEmpty {
                // 如果 Frontmatter 解析出了层级大纲
                VStack(alignment: .leading, spacing: Self.outlineSpacing) {
                    ForEach(outlines) { node in
                        HStack(spacing: Spacing.small) {
                            Spacer()
                                .frame(width: CGFloat(node.level - 1) * Self.indentStep)
                            
                            Image(systemName: node.level == 1 ? "circle.fill" : "circle")
                                .font(.system(size: Self.nodeDotSize))
                                .foregroundStyle(.appAccent)
                            
                            if let pageID = node.associatedPageID, !pageID.isEmpty {
                                Button(action: {
                                    onLinkTap(node.title)
                                }) {
                                    Text(node.title)
                                        .font(.caption.bold())
                                        .foregroundStyle(.appAccent)
                                        .underline()
                                }
                            } else {
                                Text(node.title)
                                    .font(.caption)
                                    .foregroundStyle(.appText)
                            }
                        }
                    }
                }
                .insightOutlineCardStyle()
            } else {
                // 降级兜底：扫描 Markdown 的 Header 来生成动态大纲
                let derivedOutlines = deriveOutlinesFromMarkdown()
                if derivedOutlines.isEmpty {
                    Text(L10n.Knowledge.Page.empty)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                } else {
                    VStack(alignment: .leading, spacing: Self.outlineSpacing) {
                        ForEach(derivedOutlines) { item in
                            HStack(spacing: Spacing.small) {
                                Spacer()
                                    .frame(width: CGFloat(item.level - 1) * Self.indentStep)
                                
                                Image(systemName: DesignSystem.Icons.squareFill)
                                    .font(.system(size: Self.derivedDotSize))
                                    .foregroundStyle(.appSecondary)
                                
                                Text(item.title)
                                    .font(.caption)
                                    .foregroundStyle(.appText)
                            }
                        }
                    }
                    .insightOutlineCardStyle()
                }
            }
        }
    }
    
    // 降级辅助：从 Markdown 提取 Header 列表
    private struct DerivedOutline: Identifiable {
        let id = UUID()
        let title: String
        let level: Int
    }
    
    private func deriveOutlinesFromMarkdown() -> [DerivedOutline] {
        let lines = bodyText.components(separatedBy: .newlines)
        var list: [DerivedOutline] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(SystemConstants.MarkdownSyntax.h3Prefix) {
                list.append(DerivedOutline(title: String(trimmed.dropFirst(4)), level: 3))
            } else if trimmed.hasPrefix(SystemConstants.MarkdownSyntax.h2Prefix) {
                list.append(DerivedOutline(title: String(trimmed.dropFirst(3)), level: 2))
            } else if trimmed.hasPrefix(SystemConstants.MarkdownSyntax.h1Prefix) {
                list.append(DerivedOutline(title: String(trimmed.dropFirst(2)), level: 1))
            }
        }
        return list
    }

    /// 计算周边节点的极坐标位置
    private func neighborNodePoint(index: Int, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = Double(index) * (2 * Double.pi / Double(total)) - (Double.pi / 2)
        let x = center.x + CGFloat(cos(angle)) * radius
        let y = center.y + CGFloat(sin(angle)) * radius
        return CGPoint(x: x, y: y)
    }
}
