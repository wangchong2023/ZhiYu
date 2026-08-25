//
//  TagCloudMainContent.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：标签管理主界面的布局组合 —— 搜索输入卡、悬浮控制舱工具栏、标签云展示区与
//  关联页面列表区的垂直堆叠编排。
//

import SwiftUI

// MARK: - 主界面布局

extension TagCloudViewContent {

    /// 组合主界面布局
    var mainContent: some View {
        let isExp = appEnv.screenClass == .expansive

        return VStack(spacing: 0) {
            // 1. 搜索输入卡片
            if !coordinator.tags.isEmpty {
                searchInputCard
            }

            // 2. 悬浮毛玻璃控制舱 (Unified Toolbar Cabinet)
            unifiedToolbar(isExp: isExp)

            // 3. 标签云展示区（带标准边框的卡片）
            if coordinator.tags.isEmpty {
                emptyTagsView
            } else {
                tagCloudSection
            }

            // 4. 关联页面列表区
            relatedPagesSection

            // 添加弹性间距，确保内容不满一屏时背景色依然能覆盖全屏
            Spacer(minLength: 0)
        }
    }

    // MARK: - 搜索输入卡

    private var searchInputCard: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.search)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.appAccent)

            TextField(L10n.Search.filterTags, text: $coordinator.searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.appText)

            if !coordinator.searchText.isEmpty {
                Button(action: { coordinator.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, SystemSpacing.elementLarge)
        .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(DesignSystem.Opacity.medium), lineWidth: DesignSystem.borderWidth)
        )
        .padding(.horizontal, DesignSystem.huge)
        .padding(.top, DesignSystem.medium)
        .padding(.bottom, DesignSystem.tiny)
    }

    // MARK: - 悬浮控制舱

    private func unifiedToolbar(isExp: Bool) -> some View {
        HStack(spacing: SystemSpacing.medium) {
            Spacer()

            // 右侧动作按钮组：升级为带文字与图标的胶囊型按钮
            HStack(spacing: SystemSpacing.element) {
                if !coordinator.isEditMode {
                    // ➕ 新建按钮
                    Button(action: { coordinator.showAddTagDialog = true }) {
                        HStack(spacing: SystemSpacing.small) {
                            Image(systemName: "plus")
                                .font(.system(size: actionBtnIconFontSize, weight: .bold))
                            Text(L10n.Tag.Management.addNew)
                                .font(.system(size: viewModeFontSize - 1, weight: .semibold))
                        }
                        .foregroundStyle(Color.theme.white)
                        .padding(.horizontal, SystemSpacing.medium)
                        .frame(height: actionBtnDiameter)
                        .background(Color.appCard.opacity(actionBtnBgOpacity))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.appBorder.opacity(actionBtnBorderOpacity), lineWidth: SystemStroke.divider))
                    }
                    .buttonStyle(.plain)
                }

                // ✏️ 管理/编辑按钮 (匹配选择)
                Button(action: {
                    coordinator.isEditMode.toggle()
                    if !coordinator.isEditMode { coordinator.selectedTagsForBulk.removeAll() }
                }) {
                    HStack(spacing: SystemSpacing.small) {
                        Image(systemName: coordinator.isEditMode ? "checkmark" : "list.bullet.indent")
                            .font(.system(size: actionBtnIconFontSize, weight: .bold))
                        Text(coordinator.isEditMode ? L10n.Common.ok : L10n.Tag.Management.manageTitle)
                            .font(.system(size: viewModeFontSize - 1, weight: .semibold))
                    }
                    .foregroundStyle(coordinator.isEditMode ? .green : Color.theme.white)
                    .padding(.horizontal, SystemSpacing.medium)
                    .frame(height: actionBtnDiameter)
                    .background(Color.appCard.opacity(actionBtnBgOpacity))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.appBorder.opacity(actionBtnBorderOpacity), lineWidth: SystemStroke.divider))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SystemSpacing.medium)
        .padding(.vertical, SystemSpacing.element)
        .background(BlurView().background(Color.appCard.opacity(toolbarBgOpacity)))
        .clipShape(RoundedRectangle(cornerRadius: toolbarCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: toolbarCornerRadius).stroke(Color.appBorder.opacity(toolbarBorderOpacity), lineWidth: SystemStroke.divider))
        .padding(.horizontal, isExp ? DesignSystem.wide : DesignSystem.medium)
        .padding(.vertical, SystemSpacing.element)
    }

    // MARK: - 标签云展示区

    private var tagCloudSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack {
                AppSectionHeader(
                    title: L10n.Tag.allTags,
                    icon: DesignSystem.Icons.tag,
                    iconColor: .appAccent
                )
                Spacer()
                Text(L10n.Tag.tagCount(coordinator.filteredTags.count))
                    .font(.caption2).foregroundStyle(.appSecondary)
            }
            .padding(.horizontal, DesignSystem.tiny) // 4

            VStack(spacing: 0) {
                tagScrollView
            }
            .appContainer(background: Color.appCard.opacity(DesignSystem.glassOpacity), padding: false)
            .overlay(alignment: .bottom) {
                if coordinator.isEditMode && !coordinator.selectedTagsForBulk.isEmpty {
                    bulkActionBar
                }
            }
        }
        .padding(.horizontal, DesignSystem.huge)
        .padding(.bottom, DesignSystem.Layout.columnSpacing)
    }

    // MARK: - 关联页面列表区

    private var relatedPagesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack {
                AppSectionHeader(
                    title: L10n.Tag.relatedPagesTitle,
                    icon: DesignSystem.Icons.docOnDocFill,
                    iconColor: .appSource
                )
                Spacer()
                if coordinator.selectedTag != nil, !coordinator.isEditMode {
                    Text(L10n.Tag.Action.tagPages(coordinator.filteredPages.count))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
            }
            .padding(.horizontal, DesignSystem.tiny)

            pagesListView
                .appContainer(background: Color.appCard.opacity(DesignSystem.glassOpacity), padding: false)
                .frame(minHeight: DesignSystem.Metrics.sourceCardHeight)
        }
        .padding(.horizontal, DesignSystem.huge)
        .padding(.bottom, DesignSystem.Layout.columnSpacing)
    }
}
