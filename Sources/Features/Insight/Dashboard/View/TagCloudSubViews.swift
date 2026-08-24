//
//  TagCloudSubViews.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：标签管理界面的子视图组件 —— 批量操作底栏、空状态占位、标签滚动列表（列表/气泡双模式）
//  与关联页面列表渲染。
//

import SwiftUI

// MARK: - 子视图组件

extension TagCloudViewContent {

    var bulkActionBar: some View {
        HStack {
            Text(L10n.Tag.Management.selectedCount(coordinator.selectedTagsForBulk.count))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Spacer()
            Button(role: .destructive, action: { showBulkDeleteConfirm = true }) {
                Text(L10n.Common.Misc.bulkDelete)
                    .padding(.horizontal, DesignSystem.large)
                    .padding(.vertical, DesignSystem.small - DesignSystem.atomic) // 6
                    .background(Color.theme.red)
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(BlurView().background(Color.appAccent.opacity(DesignSystem.surfaceOpacity)))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    var emptyTagsView: some View {
        VStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.tag)
                .font(.system(size: DesignSystem.iconHuge))
                .foregroundStyle(.appSecondary)
            Text(L10n.Tag.Action.noTags)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
            Text(L10n.Tag.Action.noTagsHint)
                .font(.caption)
                .foregroundStyle(.appSecondary.opacity(DesignSystem.subtleOpacity))
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }

    func bubbleRatio(for count: Int) -> Double {
        let counts = coordinator.filteredTags.map { $0.count }
        guard let maxVal = counts.max(), let minVal = counts.min() else { return 0.0 }
        let diff = maxVal - minVal
        guard diff > 0 else { return 0.5 }
        return Double(count - minVal) / Double(diff)
    }

    var tagScrollView: some View {
        let isListMode = displayMode == .list
        let tags = coordinator.filteredTags
        let shouldCollapse = isListMode && tags.count > 12 && !isExpanded
        let displayedTags = shouldCollapse ? Array(tags.prefix(12)) : tags

        return VStack(spacing: 0) {
            if isListMode {
                ScrollView {
                    FlowLayout(spacing: DesignSystem.Grid.flowSpacing) {
                        ForEach(displayedTags, id: \.tag) { tagItem in
                            TagCapsuleView(
                                item: tagItem,
                                coordinator: coordinator,
                                bubbleRatio: bubbleRatio(for: tagItem.count),
                                isBubbleMode: false
                            )
                        }
                    }
                    .padding(DesignSystem.medium)
                }
                .frame(maxHeight: isExpanded ? .infinity : DesignSystem.Metrics.maxTagCloudHeight)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .bottom) {
                    if shouldCollapse {
                        LinearGradient(
                            colors: [.clear, Color.appCard.opacity(listCollapseGradientOpacity), Color.appCard],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: listCollapseGradientHeight)
                        .allowsHitTesting(false)
                    }
                }
            } else {
                // 气泡云模式：直接挂载新实现的双向鱼眼蜂窝画布，并撑满布局容器
                TagBubbleCloudCanvas(coordinator: coordinator)
                    .frame(minHeight: bubbleCanvasMinHeight, maxHeight: .infinity)
            }

            if isListMode && tags.count > 12 {
                expandCollapseButton
            }
        }
    }

    private var expandCollapseButton: some View {
        HStack {
            Spacer()
            if !isExpanded {
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded = true
                    }
                }) {
                    HStack(spacing: DesignSystem.tiny) {
                        Text(L10n.Tag.expandAll)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.appAccent)
                    .padding(.horizontal, DesignSystem.large)
                    .padding(.vertical, DesignSystem.small)
                    .background(Color.appCard)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.appAccent.opacity(DesignSystem.Opacity.light), lineWidth: SystemStroke.divider)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, DesignSystem.small)
            } else {
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded = false
                    }
                }) {
                    HStack(spacing: DesignSystem.tiny) {
                        Text(L10n.Tag.collapse)
                        Image(systemName: "chevron.up")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.appSecondary)
                    .padding(.horizontal, DesignSystem.large)
                    .padding(.vertical, DesignSystem.small)
                    .background(Color.appCard)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.appBorder.opacity(DesignSystem.Opacity.light), lineWidth: SystemStroke.divider)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, DesignSystem.small)
            }
            Spacer()
        }
    }

    var pagesListView: some View {
        Group {
            if coordinator.selectedTag != nil, !coordinator.isEditMode {
                List {
                    Section {
                        ForEach(coordinator.filteredPages) { page in
                            Button {
                                Router.shared.path.append(AppRoute.pageDetail(id: page.id))
                            } label: {
                                PageRowView(page: page, compact: true)
                                    .padding(.vertical, DesignSystem.tiny)
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                                    .fill(Color.appCard.opacity(DesignSystem.softOpacity))
                                    .padding(.horizontal, DesignSystem.small)
                                    .padding(.vertical, DesignSystem.tiny)
                            )
                            .skipOnWatch { $0.listRowSeparator(.hidden) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: DesignSystem.medium) {
                    Image(systemName: coordinator.isEditMode ? DesignSystem.Icons.checklist : DesignSystem.Icons.tag)
                        .font(.system(size: DesignSystem.iconHuge))
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.translucentOpacity))
                    Text(coordinator.isEditMode ? L10n.Tag.Management.selectToManage : L10n.Tag.Cloud.selectTag)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: DesignSystem.Metrics.sourceCardHeight)
                .background(Color.appBackground.opacity(DesignSystem.ghostOpacity))
                .onTapGesture {
                    if coordinator.isEditMode { coordinator.isEditMode = false }
                }
            }
        }
    }
}
