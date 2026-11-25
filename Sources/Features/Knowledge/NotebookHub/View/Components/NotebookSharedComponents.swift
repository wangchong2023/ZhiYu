//
//  NotebookSharedComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：笔记本中心共享组件，消除 NotebookCard 与 NotebookListRow 之间重复的 defaultIcon 与 notebookContextMenu。
//

import SwiftUI
import UFPDesignSystem

/// 笔记本共享组件扩展，收拢 NotebookCard 与 NotebookListRow 的重复逻辑
extension Vault {
    /// 获取根据笔记本 ID 哈希值计算出来的兜底默认 Emoji 图标，收拢至强类型设计令牌
    var defaultEmojiIcon: String {
        let index = abs(id.hashValue) % DesignTokens.Icons.Notebook.options.count
        return DesignTokens.Icons.Notebook.options[index]
    }
}

/// 笔记本上下文菜单构建器，消除 NotebookCard 与 NotebookListRow 的重复菜单代码
struct NotebookContextMenu: View {
    let notebook: Vault
    let viewModel: NotebookHubViewModel

    var body: some View {
        Group {
            Button {
                viewModel.prepareEdit(notebook)
            } label: {
                Label(L10n.Vault.edit, systemImage: DesignTokens.Icons.edit)
            }
            Button(role: .destructive) {
                viewModel.deleteNotebook(id: notebook.id)
            } label: {
                Label(L10n.Vault.deleteNotebook, systemImage: DesignTokens.Icons.delete)
            }
        }
    }
}

/// 笔记本图标视图，消除 NotebookCard 与 NotebookListRow 的重复 ZStack + Emoji 布局
struct NotebookIconView<S: Shape>: View {
    let emoji: String
    let backgroundShape: S
    let backgroundColor: Color

    var body: some View {
        ZStack {
            backgroundShape
                .fill(backgroundColor)
                .frame(width: DesignTokens.IconSize.xlarge, height: DesignTokens.IconSize.xlarge)

            Text(emoji)
                .font(.title2)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - macOS 方案 A：统一工作台 Hero 条与快速模板区

/// macOS 笔记本工作台顶部 Hero 概览条（标题 + 真实资产统计胶囊 + 紧凑搜索 + 主 CTA）
struct NotebookHubDesktopHeroBar: View {
    @Bindable var viewModel: NotebookHubViewModel
    let notebookCount: Int
    let totalPageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.standardPadding) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                    Text(L10n.Vault.homeTitle)
                        .font(.system(size: DesignTokens.SystemFontSize.hero, weight: .bold, design: .rounded))
                        .foregroundStyle(.appText)

                    Text(L10n.Vault.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                }

                Spacer(minLength: DesignTokens.Spacing.standardPadding)

                HStack(spacing: DesignTokens.Spacing.medium) {
                    desktopStatPill(
                        icon: DesignTokens.Icons.knowledge,
                        value: "\(notebookCount)",
                        label: L10n.Vault.homeTitle,
                        tint: Color.appAccent
                    )
                    desktopStatPill(
                        icon: DesignTokens.Icons.document,
                        value: "\(totalPageCount)",
                        label: L10n.Vault.pageCountSuffix,
                        tint: Color.theme.purple
                    )

                    // 紧凑桌面搜索框
                    HStack(spacing: DesignTokens.Spacing.small) {
                        Image(systemName: DesignTokens.Icons.search)
                            .font(.subheadline)
                            .foregroundStyle(.appSecondary)
                        TextField(L10n.Search.base, text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                        if !viewModel.searchText.isEmpty {
                            Button { viewModel.searchText = "" } label: {
                                ClearSearchButton()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.medium)
                    .padding(.vertical, DesignTokens.Spacing.small)
                    .frame(width: DesignTokens.Metrics.macSidebarWidth)
                    .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous)
                            .strokeBorder(Color.appBorder.opacity(DesignTokens.Opacity.soft), lineWidth: DesignTokens.Spacing.borderWidth)
                    )

                    // 主 CTA：新建笔记本
                    Button {
                        viewModel.isShowingCreateSheet = true
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.small) {
                            Image(systemName: DesignTokens.Icons.plus)
                                .font(.subheadline.weight(.semibold))
                            Text(L10n.Vault.new)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                        .padding(.vertical, DesignTokens.Spacing.small)
                        .background(Color.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Vault.homePadding)
        .padding(.top, DesignTokens.Spacing.standardPadding)
    }

    private func desktopStatPill(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.appText)
            Text(label)
                .font(.caption)
                .foregroundStyle(.appSecondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.small)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.appBorder.opacity(DesignTokens.Opacity.medium), lineWidth: DesignTokens.Spacing.borderWidth)
        )
    }
}
