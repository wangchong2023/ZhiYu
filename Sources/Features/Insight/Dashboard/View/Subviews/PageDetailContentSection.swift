//
//  PageDetailContentSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：仪表盘：页面列表、知识统计、每周洞察、回链视图。
//
import SwiftUI

/// 页面详情内容展示与编辑区
struct PageDetailContentSection: View {
    @Binding var page: KnowledgePage
    @Binding var isEditing: Bool
    let onLinkTap: (String) -> Void
    
    /// 提示卡片背景透明度常数
    private let hintBgOpacity = 0.06
    
    var body: some View {
        Group {
            if isEditing {
                MarkdownEditorView(text: $page.content, placeholder: L10n.Editor.placeholder)
                    .padding(.top, DesignSystem.wide)
            } else if page.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyStateView
            } else {
                switch page.pageType {
                case .concept:
                    ConceptDetailBodyView(page: page, onLinkTap: onLinkTap)
                        .padding(.vertical)
                case .entity:
                    EntityDetailBodyView(page: page, onLinkTap: onLinkTap)
                        .padding(.vertical)
                case .source:
                    SourceDetailBodyView(page: page, onLinkTap: onLinkTap)
                        .padding(.vertical)
                case .comparison:
                    ComparisonDetailBodyView(page: page, onLinkTap: onLinkTap)
                        .padding(.vertical)
                case .raw:
                    MarkdownRendererView(content: page.content, isPrivate: page.isPrivate, onLinkTap: onLinkTap)
                        .padding(.vertical)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.pencilLine)
                .font(.system(size: DesignSystem.huge))
                .foregroundStyle(.appSecondary)
            Text(L10n.Knowledge.Page.empty)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
            Text(L10n.Knowledge.Page.emptyHint)
                .font(.caption)
                .foregroundStyle(.appAccent.opacity(DesignSystem.Opacity.overlay))
                .padding(.horizontal, DesignSystem.wide)
                .padding(.vertical, DesignSystem.small)
                .background(Color.appAccent.opacity(hintBgOpacity))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
        }
        .frame(maxWidth: .infinity, minHeight: Spacing.Grid.emptyStateHeight)
        .padding()
    }
}
