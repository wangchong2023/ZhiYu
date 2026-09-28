//
//  SearchSheets.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：为 Search 搜索功能模块提供高品质、符合现代设计美学的弹出表单 (Sheet) 视图。
//           1. PagePreviewSheet: 用于快速预览知识卡片页面。
//           2. SearchDiagnosticSheet: 用于深度展示混合检索及 AI 查询重写的召回诊断指标。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 搜索诊断面板私有常量
private enum SearchDiagConstants {
    static let metricFontSize: CGFloat = 32
    static let labelFontSize: CGFloat = 10
    static let previewLineSpacing: CGFloat = 6
}

// MARK: - 页面预览弹出页
/// 知识库页面的快速预览表单
struct PagePreviewSheet: View {
    @Environment(ThemeManager.self) private var themeManager
    
    /// 待预览的知识卡片页面数据模型
    let page: KnowledgePage
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                    // ── 顶部物理解耦卡片横幅 ──
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        HStack {
                            Image(systemName: page.displayIcon)
                                .font(.title)
                                .foregroundStyle(page.pageType.color)
                                .padding(DesignTokens.Spacing.small)
                                .background(page.pageType.color.opacity(DesignTokens.Opacity.glass))
                                .clipShape(Circle())
                            
                            Spacer()
                            
                            // 状态与置信度胶囊
                            HStack(spacing: DesignTokens.Spacing.tiny) {
                                statusPill(text: page.status.displayName, color: page.status.color)
                                statusPill(text: page.confidence.displayName, color: page.confidence.color)
                            }
                        }
                        
                        Text(page.title)
                            .font(.title)
                            .bold()
                            .foregroundStyle(.primary)
                            .padding(.top, DesignTokens.Spacing.tiny)
                        
                        Text(page.pageType.displayName)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(page.pageType.color)
                            .padding(.horizontal, DesignTokens.Spacing.small)
                            .padding(.vertical, DesignTokens.SystemSpacing.atomic)
                            .background(page.pageType.color.opacity(DesignTokens.Opacity.subtle))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius))
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                page.pageType.color.opacity(DesignTokens.Opacity.light),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius))
                    
                    // ── 标签胶囊流式布局 (使用设计系统内建的 FlowLayout) ──
                    if !page.tags.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                            Text(L10n.Tag.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .bold()
                            
                            FlowLayout(spacing: DesignTokens.Spacing.tiny) {
                                ForEach(page.tags, id: \.self) { tag in
                                    statusPill(text: "#\(tag)", color: .secondary, backgroundOpacity: DesignTokens.Opacity.subtle)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // ── 正文内容预览 ──
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        Text(L10n.Knowledge.Page.content)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if page.content.isEmpty {
                            Text(L10n.Search.noResultsHint)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(page.content)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineSpacing(SearchDiagConstants.previewLineSpacing)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, DesignTokens.Spacing.huge)
                }
            }
            .background(themeManager.pageBackground())
            .navigationTitle(L10n.Search.base)
            .doneDismissToolbar()
        }
    }

    /// 状态/标签胶囊，消除 status/confidence/tag pill 的重复修饰符链
    @ViewBuilder
    private func statusPill(text: String, color: Color, backgroundOpacity: Double = DesignTokens.Opacity.glass) -> some View {
        Text(text)
            .font(.caption2)
            .bold()
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
            .background(color.opacity(backgroundOpacity))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - 搜索检索诊断面板
/// 集中式多维度混合检索与 AI 重写查询的诊断卡片弹出页
struct SearchDiagnosticSheet: View {
    @Environment(ThemeManager.self) private var themeManager
    
    /// 诊断数据包结构体
    let info: SearchDiagnosticInfo
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.large) {
                    
                    // ── 1. AI 查询重写诊断卡 ──
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        HStack {
                            Image(systemName: DesignTokens.Icons.sparkles)
                                .foregroundStyle(Color.theme.purple)
                                .font(.headline)
                            Text(L10n.Search.Diag.rewrite)
                                .font(.headline)
                                .bold()
                        }
                        
                        Divider()
                            .background(Color.secondary.opacity(DesignTokens.Opacity.medium))
                        
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                            Text(L10n.Search.Diag.originalQuery)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .bold()
                            Text(info.query)
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.primary)
                                .padding(DesignTokens.Spacing.small)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(DesignTokens.Opacity.subtle))
                                .cornerRadius(DesignTokens.Spacing.smallRadius)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                            Text(L10n.Search.Diag.rewrittenQuery)
                                .font(.caption2)
                                .foregroundStyle(Color.theme.purple)
                                .bold()
                            Text(info.rewrittenQuery)
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(Color.theme.purple)
                                .padding(DesignTokens.Spacing.small)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.theme.purple.opacity(DesignTokens.Opacity.subtle))
                                .cornerRadius(DesignTokens.Spacing.smallRadius)
                        }
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(DesignTokens.Spacing.cardRadius)
                    .shadow(color: DesignTokens.Colors.Opacity.shadowColor.opacity(DesignTokens.Opacity.atomic), radius: DesignTokens.Spacing.shadowRadius, y: DesignTokens.Spacing.shadowY)
                    .padding(.horizontal)
                    
                    // ── 2. 多源召回对比圆环/指标面板 ──
                    HStack(spacing: DesignTokens.Spacing.large) {
                        // 全文检索召回卡
                        recallMetricCard(
                            rankLabel: L10n.Search.Diag.ftsRank,
                            count: info.ftsCount,
                            engineLabel: L10n.Search.Diag.ftsEngine,
                            countColor: Color.theme.blue,
                            engineColor: .blue.opacity(DesignTokens.Opacity.prominent),
                            gradientColors: [Color.theme.blue.opacity(DesignTokens.Opacity.ghost), Color.theme.blue.opacity(DesignTokens.Opacity.atomic)],
                            borderColor: Color.theme.blue.opacity(DesignTokens.Opacity.glass)
                        )
                        
                        // 向量检索召回卡
                        recallMetricCard(
                            rankLabel: L10n.Search.Diag.vectorRank,
                            count: info.vectorCount,
                            engineLabel: L10n.Search.Diag.vectorEngine,
                            countColor: Color.theme.green,
                            engineColor: .green.opacity(DesignTokens.Opacity.prominent),
                            gradientColors: [Color.theme.green.opacity(DesignTokens.Opacity.ghost), Color.theme.green.opacity(DesignTokens.Opacity.atomic)],
                            borderColor: Color.theme.green.opacity(DesignTokens.Opacity.glass)
                        )
                    }
                    .padding(.horizontal)
                    
                    // ── 3. RRF (Reciprocal Rank Fusion) 重排精细得分列表 ──
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        HStack {
                            Image(systemName: DesignTokens.Icons.listNumber)
                                .foregroundStyle(Color.theme.orange)
                            Text(L10n.Search.Diag.rrfDetail)
                                .font(.headline)
                                .bold()
                        }
                        .padding(.horizontal)
                        
                        if info.rrfTopResults.isEmpty {
                            Text(L10n.Search.noResults)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(info.rrfTopResults.enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: DesignTokens.Spacing.medium) {
                                        // 序号标识
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .bold()
                                            .foregroundStyle(Color.theme.orange)
                                            .frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
                                            .background(Color.theme.orange.opacity(DesignTokens.Opacity.subtle))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
                                            Text(item.title)
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            
                                            HStack(spacing: DesignTokens.Spacing.small) {
                                                // FTS 排位
                                                rankBadge(
                                                    prefix: L10n.Search.Diag.ftsPrefix,
                                                    rank: item.ftsRank,
                                                    activeColor: Color.theme.blue
                                                )

                                                // 向量排位
                                                rankBadge(
                                                    prefix: L10n.Search.Diag.vecPrefix,
                                                    rank: item.vectorRank,
                                                    activeColor: Color.theme.green
                                                )
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // 综合 RRF 打分
                                        Text(String(format: L10n.Search.Diag.scoreFormat, item.finalScore))
                                            .font(.system(.subheadline, design: .monospaced))
                                            .bold()
                                            .foregroundStyle(Color.theme.orange)
                                            .padding(.horizontal, DesignTokens.Spacing.small)
                                            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                                            .background(Color.theme.orange.opacity(DesignTokens.Opacity.subtle))
                                            .cornerRadius(DesignTokens.Spacing.microRadius)
                                    }
                                    .padding(.vertical, DesignTokens.Spacing.small)
                                    .padding(.horizontal)
                                    
                                    if index < info.rrfTopResults.count - 1 {
                                        Divider()
                                            .background(Color.secondary.opacity(DesignTokens.Opacity.subtle))
                                            .padding(.leading, DesignTokens.ComponentSpacing.massive)
                                    }
                                }
                            }
                            .background(Color.appCard)
                            .cornerRadius(DesignTokens.Spacing.cardRadius)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.small)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(themeManager.pageBackground())
            .navigationTitle(L10n.Search.Diag.title)
            .doneDismissToolbar()
        }
    }

    /// 召回指标卡，消除 FTS/向量召回卡的重复修饰符链
    @ViewBuilder
    private func recallMetricCard(
        rankLabel: String,
        count: Int,
        engineLabel: String,
        countColor: Color,
        engineColor: Color,
        gradientColors: [Color],
        borderColor: Color
    ) -> some View {
        VStack(spacing: DesignTokens.Spacing.tiny) {
            Text(rankLabel)
                .font(.caption2)
                .bold()
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.system(size: SearchDiagConstants.metricFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(countColor)

            Text(engineLabel)
                .font(.system(size: SearchDiagConstants.labelFontSize, weight: .bold))
                .foregroundStyle(engineColor)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignTokens.Spacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius)
                .stroke(borderColor, lineWidth: DesignTokens.Spacing.borderWidth)
        )
    }

    /// 排位 Badge，消除 FTS/向量排位的重复修饰符链
    @ViewBuilder
    private func rankBadge(prefix: String, rank: Int, activeColor: Color) -> some View {
        HStack(spacing: DesignTokens.SystemSpacing.atomic) {
            Text(prefix)
            Text(rank > 0 ? "#\(rank)" : L10n.Search.Diag.miss)
        }
        .font(.system(size: SearchDiagConstants.labelFontSize))
        .foregroundStyle(rank > 0 ? activeColor : Color.secondary)
    }
}
