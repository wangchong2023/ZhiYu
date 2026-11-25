//
//  Graph3DOverlayComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 3D 图谱浮层控件
//  核心职责：承载 3D 图谱的坐标点模型（CGPoint3D）、空间导航控制面板（Graph3DControlsOverlay）
//           与节点信息浮栏（Graph3DNodeInfoBar），与 SceneKit 底层宿主视图解耦。
//

import SwiftUI
import UFPDesignSystem

// MARK: - CGPoint3D

/// 3D 坐标空间点模型，负责定义节点在 SceneKit 笛卡尔坐标系中的 X/Y/Z 位置
struct CGPoint3D {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat
}

// MARK: - Graph3D Controls Overlay

/// 3D 图谱控制面板组件，提供相机对焦、全屏切换、自动旋转及页面类型过滤等空间导航控制功能
struct Graph3DControlsOverlay: View {
    @Binding var autoRotate: Bool
    @Binding var filterType: PageType?
    @Binding var isFullScreen: Bool
    @Binding var hideControls: Bool

    let onAutoRotateToggle: () -> Void
    let onResetCamera: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        let iconColor: Color = isFullScreen ? .white : .appText

        VStack(spacing: DesignTokens.Spacing.small) {
            // Fullscreen toggle
            controlButton(
                icon: isFullScreen ? DesignTokens.Icons.fullscreenExit : DesignTokens.Icons.fullscreenEnter,
                iconColor: iconColor,
                accessibilityID: FeatureConstants.GraphAccessibilityID.graph3dFullscreen
            ) {
                withAnimation(.spring()) {
                    isFullScreen.toggle()
                    showFilterPopup = false
                    if !isFullScreen { hideControls = false }
                }
            }

            // Hide controls toggle - 仅在全屏模式下显示
            if isFullScreen {
                controlButton(
                    icon: DesignTokens.Icons.eyeSlashOutline,
                    iconColor: iconColor,
                    accessibilityID: FeatureConstants.GraphAccessibilityID.graph3dHideControls
                ) {
                    withAnimation(.spring()) {
                        hideControls = true
                    }
                }
            }

            // Auto-rotate toggle - 仅在全屏模式下显示
            if isFullScreen {
                controlButton(
                    icon: autoRotate ? DesignTokens.Icons.refreshCircleFill : DesignTokens.Icons.refreshCircle,
                    iconColor: autoRotate ? Color.appAccent : iconColor,
                    accessibilityID: FeatureConstants.GraphAccessibilityID.graph3dAutoRotate
                ) {
                    onAutoRotateToggle()
                }
            }

            // Reset camera
            controlButton(
                icon: DesignTokens.Icons.scope,
                iconColor: iconColor,
                accessibilityID: FeatureConstants.GraphAccessibilityID.graph3dResetCamera
            ) {
                onResetCamera()
            }

            // Zoom In
            controlButton(
                icon: DesignTokens.Icons.plusMagnifyingglass,
                iconColor: iconColor,
                accessibilityID: FeatureConstants.GraphAccessibilityID.graph3dZoomIn
            ) {
                onZoomIn()
            }

            // Zoom Out
            controlButton(
                icon: DesignTokens.Icons.minusMagnifyingglass,
                iconColor: iconColor,
                accessibilityID: FeatureConstants.GraphAccessibilityID.graph3dZoomOut
            ) {
                onZoomOut()
            }

            // Filter - 全屏模式下隐藏
            if !isFullScreen {
                Button(action: { withAnimation(.spring(response: Graph3DSceneConfig.filterSpringResponse)) { showFilterPopup.toggle() } }) {
                    Image(systemName: DesignTokens.Icons.filterCircle)
                        .font(.title3)
                        .foregroundStyle(filterType == nil ? iconColor : Color.appAccent)
                        .padding(Graph3DUIConstants.controlPadding)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(filterType == nil ? 0 : DesignTokens.Colors.Opacity.dimmedOpacity), radius: DesignTokens.Spacing.tiny)
                }
                .overlay(alignment: .bottomTrailing) {
                    if showFilterPopup {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(L10n.Graph.filter)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.appSecondary)
                                .padding(.horizontal, DesignTokens.Spacing.medium)
                                .padding(.top, DesignTokens.SystemSpacing.tight)
                                .padding(.bottom, DesignTokens.Spacing.tightPadding)

                            Divider().background(Color.appBorder.opacity(DesignTokens.Opacity.shadow))

                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    filterPillRow(
                                        icon: DesignTokens.Icons.gridOutline,
                                        title: L10n.Graph.all,
                                        isSelected: filterType == nil
                                    ) {
                                        filterType = nil
                                        showFilterPopup = false
                                    }

                                    // 遍历用户可见页面类型，屏蔽 raw 选项
                                    ForEach(PageType.allVisibleCases) { type in
                                        filterPillRow(
                                            icon: type.icon,
                                            title: type.displayName,
                                            isSelected: filterType == type
                                        ) {
                                            filterType = type
                                            showFilterPopup = false
                                        }
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxHeight: DesignTokens.Spacing.Grid.emptyStateHeight)
                        }
                        .frame(width: DesignTokens.Metrics.graphControlWidth)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Spacing.largeRadius)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(DesignTokens.Opacity.glass), radius: Graph3DUIConstants.filterShadowRadius, x: Graph3DUIConstants.filterShadowX, y: Graph3DUIConstants.filterShadowY)
                        )
                        .offset(x: Graph3DUIConstants.filterOffsetX, y: Graph3DUIConstants.filterOffsetY)
                        .transition(.asymmetric(
                            insertion: .scale(scale: Graph3DUIConstants.filterPopupScale).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .accessibilityIdentifier("graph3d-filter")
            }
        }
        .onChange(of: isFullScreen) { _, _ in
            showFilterPopup = false
        }
    }

    @State private var showFilterPopup = false

    /// 3D 控制按钮，消除重复的 Image+padding+ultraThinMaterial+Circle 链
    @ViewBuilder
    private func controlButton(
        icon: String,
        iconColor: Color,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .padding(Graph3DUIConstants.controlPadding)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        // 自绘圆形材质按钮需关闭 macOS 默认 bezel。
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    /// 筛选 Pill 行，消除"全部"与各类型 Pill 的重复修饰符链
    @ViewBuilder
    private func filterPillRow(
        icon: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.footnote)
                Spacer()
                if isSelected {
                    Image(systemName: DesignTokens.Icons.check)
                        .font(.caption2.weight(.bold))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.SystemSpacing.tight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.appAccent : .appText)
    }
}

// MARK: - Graph3D Node Info Bar

/// 3D 节点详情浮栏组件，在选中 3D 节点时提供轻量级的信息摘要及进入详情页的快速入口
struct Graph3DNodeInfoBar: View {
    let page: KnowledgePage
    let onViewPage: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Circle()
                .fill(Color.fromModelColorName(page.pageType.colorName))
                .frame(width: DesignSystem.Timeline.indicatorSize, height: DesignSystem.Timeline.indicatorSize)
                .overlay {
                    Image(systemName: page.displayIcon)
                        .font(.caption)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                Text(page.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)
                Text(page.pageType.displayName)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }

            Spacer()

            Button(action: onViewPage) {
                Text(L10n.Graph.viewDetail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appAccent)
                    .padding(.horizontal, DesignTokens.Spacing.medium)
                    .padding(.vertical, DesignTokens.Spacing.tightPadding)
                    .background(Color.appAccent.opacity(DesignTokens.Opacity.glass))
                    .clipShape(Capsule())
            }
            // 自绘胶囊按钮需关闭 macOS 默认 bezel，避免双层外框。
            .buttonStyle(.plain)
            .accessibilityIdentifier("graph3d-view-page")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.largeRadius))
        .padding(.horizontal)
        .padding(.bottom, DesignTokens.Spacing.small)
    }
}
