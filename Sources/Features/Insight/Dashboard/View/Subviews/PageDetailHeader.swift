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
        VStack(alignment: .leading, spacing: DesignSystem.small) {
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
        HStack(spacing: DesignSystem.tiny) {
            // AI Status Indicator
            if taskCenter.tasks.contains(where: { if case .running = $0.status { return true }; return false }) {
                HStack(spacing: DesignSystem.tiny) {
                    Image(systemName: DesignSystem.Icons.cpu)
                        .font(.system(size: DesignSystem.microFontSize))
                    Text(L10n.AI.Task.running)
                        .font(.system(size: DesignSystem.caption2FontSize, weight: .bold))
                }
                .foregroundStyle(.appAccent)
                .padding(.horizontal, DesignSystem.tightPadding)
                .padding(.vertical, DesignSystem.atomic)
                .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale))
            }

            if page.isPinned {
                Spacer()
                Image(systemName: DesignSystem.Icons.pinFill)
                    .font(.caption2)
                    .foregroundStyle(.appComparison)
            }
        }
    }
    
    // MARK: - Type / Status / Confidence Row
    private var typeStatusConfidenceRow: some View {
        HStack(spacing: SystemSpacing.element) {
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
            .font(.system(size: DesignSystem.titleFontSize, weight: .bold, design: .rounded))
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
                HStack(spacing: DesignSystem.small) {
                    ForEach(combinedTags, id: \.self) { item in
                        let isAlias = page.aliases.contains(item)
                        HStack(spacing: DesignSystem.tiny) {
                            if isAlias {
                                Image(systemName: DesignSystem.Icons.arrowBranch)
                                    .font(.system(size: DesignSystem.caption2FontSize))
                            } else {
                                Text(FeatureConstants.Decorator.hash)
                                    .font(.system(size: DesignSystem.caption2FontSize, weight: .bold))
                            }
                            Text(item)
                        }
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.vertical, DesignSystem.tiny)
                        .background(
                            isAlias ? 
                            Color.appSource.opacity(DesignSystem.Opacity.subtle) : 
                            Color.appAccent.opacity(DesignSystem.Opacity.subtle)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    isAlias ? 
                                    Color.appSource.opacity(DesignSystem.Opacity.medium) : 
                                    Color.appAccent.opacity(DesignSystem.Opacity.medium), 
                                    lineWidth: SystemStroke.hairline
                                )
                        )
                        .foregroundStyle(isAlias ? .appSource : .appAccent)
                    }
                }
                .padding(.vertical, DesignSystem.atomic)
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
        HStack(spacing: DesignSystem.tiny) {
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
        .padding(.horizontal, DesignSystem.small)
        .padding(.vertical, DesignSystem.tiny)
        .background(Color.fromModelColorName(page.pageType.colorName).opacity(DesignSystem.Opacity.medium))
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
        HStack(spacing: DesignSystem.tiny) {
            Circle()
                .fill(Color.fromModelColorName(page.status.colorName))
                .frame(width: DesignSystem.IconSize.atomic, height: DesignSystem.IconSize.atomic)
            Text(page.status.displayName)
                .font(.caption)
        }
        .padding(.horizontal, DesignSystem.small)
        .padding(.vertical, DesignSystem.tiny)
        .background(Color.fromModelColorName(page.status.colorName).opacity(DesignSystem.Opacity.glass))
        .clipShape(Capsule())
        .foregroundStyle(Color.fromModelColorName(page.status.colorName))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Knowledge.Page.statusAccessibility(page.status.displayName))
    }
}

// MARK: - Confidence Badge
/// 页面置信度标识徽章小组件
/// 负责展示内容的可靠性指标，通常由 AI 自动打分或人工审核确认
private struct ConfidenceBadge: View {
    let page: KnowledgePage
    
    var body: some View {
        HStack(spacing: DesignSystem.tiny) {
            Image(systemName: DesignSystem.Icons.cellularbars)
                .font(.caption2)
            Text(page.confidence.displayName)
                .font(.caption)
        }
        .padding(.horizontal, DesignSystem.small)
        .padding(.vertical, DesignSystem.tiny)
        .background(Color.fromModelColorName(page.confidence.colorName).opacity(DesignSystem.Opacity.glass))
        .clipShape(Capsule())
        .foregroundStyle(Color.fromModelColorName(page.confidence.colorName))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Knowledge.Page.confidenceAccessibility(page.confidence.displayName))
    }
}
