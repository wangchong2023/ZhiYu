//
//  EntityDetailBodyView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：渲染“词条 (Entity)”类型页面的差异化排版，包含百科字典式的 Fact 释义板、别名芯片组、Wikipedia 属性网格和内容概述。
//

import SwiftUI
import UFPDesignSystem

/// [L3] 表现层：词条页面差异化详情视图
struct EntityDetailBodyView: View {
    let page: KnowledgePage
    let onLinkTap: (String) -> Void
    
    @State private var frontmatter: EntityFrontmatter?
    @State private var bodyText: String = ""
    
    // 布局微调常数，防止魔鬼数字
    private static let cardBorderWidth: CGFloat = 1.0
    private static let pronunciationOpacity: Double = 0.8
    private static let columns = [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.medium),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.medium)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
            // 1. 权威释义板 (Fact Summary) 与别名芯片 (Aliases)
            factSummarySection
            
            // 2. 右侧参数百科面板 (Wiki InfoBox)
            if let infobox = frontmatter?.infobox, !infobox.isEmpty {
                wikiInfoBoxSection(infobox)
            }
            
            // 3. 内容概述大纲 (Overview)
            if let overview = frontmatter?.overview, !overview.isEmpty {
                overviewSection(overview)
            }
            
            DetailBodyEpilogue(page: page, bodyText: bodyText, onLinkTap: onLinkTap)
        }
        .detailBodyOnAppear(
            content: page.content,
            frontmatterType: EntityFrontmatter.self,
            bodyText: $bodyText,
            frontmatter: $frontmatter
        )
    }
    
    // MARK: - 1. 权威释义板 (Fact Summary) 与 别名芯片组
    private var factSummarySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            // 读音与基本定义
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                if let pronunciation = frontmatter?.pronunciation, !pronunciation.isEmpty {
                    Text(pronunciation)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.appAccent.opacity(Self.pronunciationOpacity))
                }
                
                if let definition = frontmatter?.definition, !definition.isEmpty {
                    Text(definition)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.appText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard.opacity(DesignTokens.Opacity.ghost))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.appAccent.opacity(DesignTokens.Opacity.disabled), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: Self.cardBorderWidth
                    )
            )

            // 别名芯片列表
            let aliasList = frontmatter?.aliases ?? page.aliases
            if !aliasList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        ForEach(aliasList, id: \.self) { alias in
                            InsightTagChip(
                                text: alias,
                                icon: DesignTokens.Icons.pencilClipboard,
                                foregroundColor: .appSecondary,
                                style: InsightTagChipStyle(
                                    backgroundColor: .appCard,
                                    backgroundOpacity: DesignTokens.Opacity.subtle
                                )
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 2. 百科属性网格面板 (Wiki InfoBox)
    private func wikiInfoBoxSection(_ items: [EntityFrontmatter.InfoBoxItem]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            InsightSectionHeader(title: L10n.Onboarding.featureTitle, icon: DesignTokens.Icons.macwindowBadgePlus)
            
            LazyVGrid(columns: Self.columns, spacing: DesignTokens.Spacing.medium) {
                ForEach(items, id: \.key) { item in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                        Text(item.key)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                        
                        Text(item.value)
                            .font(.caption.bold())
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                    }
                    .infoCardStyle(backgroundOpacity: DesignTokens.Opacity.subtle, cornerRadius: DesignTokens.Spacing.smallRadius, useBorder: true)
                }
            }
        }
    }
    
    // MARK: - 3. 内容概述大纲 (Overview)
    private func overviewSection(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            InsightSectionHeader(title: L10n.Editor.outline, icon: DesignTokens.Icons.docTextBelowEcg)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, overviewItem in
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.small) {
                        Text("\(index + 1).")
                            .font(.caption.bold())
                            .foregroundStyle(.appAccent)
                        
                        Text(overviewItem)
                            .font(.caption)
                            .foregroundStyle(.appText)
                    }
                }
            }
            .infoCardStyle(backgroundOpacity: DesignTokens.Opacity.subtle, cornerRadius: DesignTokens.Spacing.smallRadius, useBorder: true)
        }
    }
}

// MARK: - 实体信息卡片修饰符
// 已迁移至 DesignSystem: View.infoCardStyle(backgroundOpacity:cornerRadius:useBorder:)
