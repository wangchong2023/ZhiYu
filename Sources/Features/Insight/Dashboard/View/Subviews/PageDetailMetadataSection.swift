//
//  PageDetailMetadataSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：仪表盘：页面列表、知识统计、每周洞察、回链视图。
//
import SwiftUI
import UFPCore
import Dependencies
import UFPDesignSystem

/// 页面详情元数据展示区
struct PageDetailMetadataSection: View {
    let page: KnowledgePage
    let backlinks: [KnowledgePage]
    let recommendations: [KnowledgePage]
    
    @State private var copiedUrl: String?
    
    @Dependency(\.pasteboard) var pasteboard: any PasteboardProtocol
    
    var body: some View {
        VStack(spacing: 0) {
            provenanceSection
            semanticRecommendationsSection
            backlinksSection
        }
    }
    
    private var provenanceSection: some View {
        Group {
            if let sourceURL = page.sourceURL, let url = URL(string: sourceURL) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
                    HStack {
                        Image(systemName: page.displaySourceIcon).foregroundStyle(.appAccent)
                        Text(L10n.Knowledge.Page.Source.title).font(.headline).foregroundStyle(.appText)
                        Spacer()
                        if page.isLocalFileSource {
                            Button(action: {
                                pasteboard.string = sourceURL
                                withAnimation(.spring()) {
                                    copiedUrl = sourceURL
                                }
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    withAnimation(.spring()) {
                                        if copiedUrl == sourceURL {
                                            copiedUrl = nil
                                        }
                                    }
                                }
                            }) {
                                HStack(spacing: DesignTokens.Spacing.tiny) {
                                    Text(copiedUrl == sourceURL ? L10n.Knowledge.Page.Source.copied : L10n.Knowledge.Page.Source.copyPath)
                                    Image(systemName: copiedUrl == sourceURL ? "checkmark.circle.fill" : "doc.on.doc")
                                }
                                .font(.caption)
                                .foregroundStyle(.appAccent)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Link(destination: url) {
                                HStack(spacing: DesignTokens.Spacing.tiny) {
                                    Text(L10n.Knowledge.Page.Source.open)
                                    Image(systemName: DesignTokens.Icons.arrowUpRightCircle)
                                }
                                .font(.caption)
                                .foregroundStyle(.appAccent)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
                        if page.isLocalFileSource {
                            sourceInfoText("\(L10n.Knowledge.Page.Source.localFile): \(page.displaySourceName)")
                        } else {
                            sourceInfoText(sourceURL)
                        }
                        
                        if let snippet = page.rawTextSnippet, !snippet.isEmpty {
                            Text(snippet)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                                .cardStyle(
                                    horizontalPadding: DesignTokens.Spacing.small,
                                    verticalPadding: DesignTokens.Spacing.small,
                                    backgroundOpacity: DesignTokens.Opacity.solid,
                                    cornerRadius: DesignTokens.Spacing.microRadius
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(3)
                        }
                    }
                    .appContainer(padding: true)
                }
                .padding()
            }
        }
    }
    
    private var semanticRecommendationsSection: some View {
        Group {
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        ZStack {
                            Circle().fill(Color.appAccent.opacity(DesignTokens.Opacity.subtle)).frame(width: DesignTokens.IconSize.standard, height: DesignTokens.IconSize.standard)
                            Image(systemName: DesignTokens.Icons.sparkles).font(.system(size: DesignTokens.Spacing.iconTiny)).foregroundStyle(.appAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(L10n.Knowledge.Page.AI.insights).font(.headline).foregroundStyle(.appText)
                            Text(L10n.Knowledge.Page.AI.insightsDesc).font(.caption2).foregroundStyle(.appSecondary)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.tiny)
                    
                    VStack(spacing: DesignTokens.Spacing.tightPadding) {
                        ForEach(recommendations) { recPage in
                            recommendationRow(for: recPage)
                        }
                    }
                }
                .aiRecommendationCardStyle(verticalPadding: DesignTokens.Spacing.standardPadding)
            }
        }
    }
    
    private func recommendationRow(for recPage: KnowledgePage) -> some View {
        NavigationLink(value: AppRoute.pageDetail(id: recPage.id)) {
            HStack {
                Image(systemName: recPage.displayIcon).foregroundStyle(Color.fromModelColorName(recPage.pageType.colorName))
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                    Text(recPage.title).font(.subheadline.weight(.medium))
                    let summaryText = String(recPage.content.prefix(FeatureConstants.PageDetailMetadata.summaryPrefixLength)) + "..."
                    Text(summaryText).font(.caption2).foregroundStyle(.appSecondary)
                }
                forwardArrow
            }
            .padding(DesignTokens.Spacing.medium)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.tightPadding))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Spacing.tightPadding).stroke(LinearGradient(colors: [.appAccent.opacity(DesignTokens.Opacity.shadow), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: DesignTokens.SystemStroke.divider))
        }
        .buttonStyle(.plain)
    }
    
    private var backlinksSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack {
                Image(systemName: DesignTokens.Icons.link).foregroundStyle(.appAccent)
                Text(L10n.Knowledge.Page.backlinks).font(.headline).foregroundStyle(.appText)
                Text("(\(backlinks.count))").font(.subheadline).foregroundStyle(.appSecondary)
            }
            
            if backlinks.isEmpty {
                Text(L10n.Knowledge.Page.noBackLinks).font(.caption).foregroundStyle(.appSecondary).padding(.vertical, DesignTokens.Spacing.small)
            } else {
                ForEach(backlinks) { linkedPage in
                    NavigationLink(value: AppRoute.pageDetail(id: linkedPage.id)) {
                        HStack(spacing: DesignTokens.Spacing.medium) {
                            pageTypeIcon(page: linkedPage)
                            Text(linkedPage.title).font(.subheadline).foregroundStyle(.appText)
                            forwardArrow
                        }
                        .cardStyle(
                            horizontalPadding: DesignTokens.Spacing.tightPadding,
                            verticalPadding: DesignTokens.Spacing.small,
                            backgroundOpacity: DesignTokens.Opacity.solid,
                            cornerRadius: DesignTokens.Spacing.smallRadius
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Knowledge.Page.backlinkAccessibility(linkedPage.title, linkedPage.pageType.displayName))
                    .accessibilityHint(L10n.Knowledge.Page.doubleTapToNavigate)
                }
            }
        }
        .padding()
    }

    /// 页面类型图标：displayIcon + 颜色背景 + 圆角裁剪
    @ViewBuilder
    private func pageTypeIcon(page: KnowledgePage) -> some View {
        InsightPageTypeIcon(page: page, size: DesignTokens.IconSize.medium)
    }

    /// 前进箭头：Spacer + forward 图标
    @ViewBuilder
    private var forwardArrow: some View {
        Spacer()
        Image(systemName: DesignTokens.Icons.forward).font(.caption2).foregroundStyle(.appSecondary)
    }

    /// 来源信息文本：caption2 + appSecondary + lineLimit(1) + truncationMode(.middle)
    @ViewBuilder
    private func sourceInfoText(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.appSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
