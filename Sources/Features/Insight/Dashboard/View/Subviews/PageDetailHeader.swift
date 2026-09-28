//
//  PageDetailHeader.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：仪表盘：页面列表、知识统计、每周洞察、回链视图。
//
import SwiftUI
import Dependencies
import UFPDesignSystem

// MARK: - Page Detail Header
/// Page detail header displaying type/status/confidence badges, title, aliases, tags, and meta info.
/// 页面详情顶栏组件
/// 负责展示知识页面的标题、类型标识、最近修改时间及操作入口（如书签、分享、删除）
/// 页面详情页顶部头部组件
/// 负责在详情页显著位置展示核心元数据（标题、类型、状态、置信度、别名、标签及统计信息），支持 Hero 动画
struct PageDetailHeader: View {
    let page: KnowledgePage
    var heroNamespace: Namespace.ID?
    @Dependency(\.taskCenter) private var taskCenter
    
    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = isMetaExpanded
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            breadcrumb
            typeStatusConfidenceRow
            titleView
            tagsAndAliasesView
            
            // Metadata section with industrial-grade collapsible control
            PageDetailMetaSectionView(page: page, isExpanded: $isMetaExpanded)
        }
        .padding()
    }
    
    @State private var isMetaExpanded = false
    
    // MARK: - Breadcrumb
    private var breadcrumb: some View {
        HStack(spacing: DesignTokens.Spacing.tiny) {
            // AI Status Indicator
            if taskCenter.tasks.contains(where: { if case .running = $0.status { return true }; return false }) {
                HStack(spacing: DesignTokens.Spacing.tiny) {
                    Image(systemName: DesignTokens.Icons.cpu)
                        .font(.system(size: DesignTokens.Typography.microFontSize))
                    Text(L10n.AI.Task.running)
                        .font(.system(size: DesignTokens.Typography.caption2FontSize, weight: .bold))
                }
                .foregroundStyle(.appAccent)
                .accentSubtleCapsule(
                    horizontalPadding: DesignTokens.Spacing.tightPadding,
                    verticalPadding: DesignTokens.Spacing.atomic
                )
                .transition(.opacity.combined(with: .scale))
            }

            if page.isPinned {
                Spacer()
                Image(systemName: DesignTokens.Icons.pinFill)
                    .font(.caption2)
                    .foregroundStyle(.appComparison)
            }
        }
    }
    
    // MARK: - Type / Status / Confidence Row
    private var typeStatusConfidenceRow: some View {
        HStack(spacing: DesignTokens.SystemSpacing.element) {
            // Type badge
            TypeBadge(page: page, heroNamespace: heroNamespace)
            
            // Status badge
            StatusBadge(page: page)
            
            // Confidence badge
            ConfidenceBadge(page: page)
            
            Spacer()
        }
    }
    
    // MARK: - Title
    private var titleView: some View {
        Text(page.title)
            .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.appText)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(L10n.Knowledge.Page.titleAccessibility(page.title))
    }
    
    // MARK: - Aliases & Tags (Unified Flow)
    @ViewBuilder
    private var tagsAndAliasesView: some View {
        let combinedTags = Array(Set(page.tags + page.aliases)).filter { $0 != page.title }.sorted()
        
        if !combinedTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(combinedTags, id: \.self) { item in
                        let isAlias = page.aliases.contains(item)
                        HStack(spacing: DesignTokens.Spacing.tiny) {
                            if isAlias {
                                Image(systemName: DesignTokens.Icons.arrowBranch)
                                    .font(.system(size: DesignTokens.Typography.caption2FontSize))
                            } else {
                                Text(FeatureConstants.Decorator.hash)
                                    .font(.system(size: DesignTokens.Typography.caption2FontSize, weight: .bold))
                            }
                            Text(item)
                        }
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, DesignTokens.Spacing.medium)
                        .padding(.vertical, DesignTokens.Spacing.tiny)
                        .background(
                            isAlias ? 
                            Color.appSource.opacity(DesignTokens.Opacity.subtle) : 
                            Color.appAccent.opacity(DesignTokens.Opacity.subtle)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    isAlias ? 
                                    Color.appSource.opacity(DesignTokens.Opacity.medium) : 
                                    Color.appAccent.opacity(DesignTokens.Opacity.medium), 
                                    lineWidth: DesignTokens.SystemStroke.hairline
                                )
                        )
                        .foregroundStyle(isAlias ? .appSource : .appAccent)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.atomic)
            }
        }
    }
    
}

// MARK: - Type Badge
/// 页面类型标识徽章小组件
/// 负责以胶囊形态展示页面所属分类图标及名称，并适配 Hero 动画转场标识
private struct TypeBadge: View {
    let page: KnowledgePage
    var heroNamespace: Namespace.ID?
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.tiny) {
            if let ns = heroNamespace {
                Image(systemName: page.displayIcon)
                    .font(.caption)
                    .matchedGeometryEffect(id: page.id, in: ns)
            } else {
                Image(systemName: page.displayIcon)
                    .font(.caption)
            }
            Text(page.pageType.displayName)
                .font(.caption.weight(.medium))
        }
        .commonContentPadding(horizontal: DesignTokens.Spacing.small, vertical: DesignTokens.Spacing.tiny)
        .background(Color.fromModelColorName(page.pageType.colorName).opacity(DesignTokens.Opacity.medium))
        .clipShape(Capsule())
        .foregroundStyle(Color.fromModelColorName(page.pageType.colorName))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Knowledge.Page.pageTypeAccessibility(page.pageType.displayName))
    }
}

// MARK: - Status Badge
/// 页面状态标识徽章小组件
/// 负责展示页面的生命周期状态（如草稿、已发布、已废弃），并提供颜色编码的视觉提示
private struct StatusBadge: View {
    let page: KnowledgePage
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.tiny) {
            Circle()
                .fill(Color.fromModelColorName(page.status.colorName))
                .frame(width: DesignTokens.IconSize.atomic, height: DesignTokens.IconSize.atomic)
            Text(page.status.displayName)
                .font(.caption)
        }
        .badgeCapsuleStyle(colorName: page.status.colorName, accessibilityLabel: L10n.Knowledge.Page.statusAccessibility(page.status.displayName))
    }
}

// MARK: - Confidence Badge
/// 页面置信度标识徽章小组件
/// 负责展示内容的可靠性指标，通常由 AI 自动打分或人工审核确认
private struct ConfidenceBadge: View {
    let page: KnowledgePage
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.tiny) {
            Image(systemName: DesignTokens.Icons.cellularbars)
                .font(.caption2)
            Text(page.confidence.displayName)
                .font(.caption)
        }
        .badgeCapsuleStyle(colorName: page.confidence.colorName, accessibilityLabel: L10n.Knowledge.Page.confidenceAccessibility(page.confidence.displayName))
    }
}

// MARK: - 徽章胶囊样式
private extension View {
    /// 徽章胶囊样式：padding + background + clipShape + foregroundStyle + accessibility
    func badgeCapsuleStyle(colorName: String, accessibilityLabel: String) -> some View {
        self
            .commonContentPadding(horizontal: DesignTokens.Spacing.small, vertical: DesignTokens.Spacing.tiny)
            .background(Color.fromModelColorName(colorName).opacity(DesignTokens.Opacity.glass))
            .clipShape(Capsule())
            .foregroundStyle(Color.fromModelColorName(colorName))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
    }
}
