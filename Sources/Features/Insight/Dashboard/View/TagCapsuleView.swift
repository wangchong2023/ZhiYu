//
//  TagCapsuleView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：标签气泡微组件，负责展示单个标签字词及其词频，支持列表模式与气泡云双模式渲染，
//  包含编辑选中角标、几何位置驱动的鱼眼缩放形变与上下文菜单交互。
//

import SwiftUI
import UFPCore
import Dependencies

// MARK: - 标签气泡微组件

/// 标签气泡视图，负责展示单个标签字词及其词频，支持编辑选中和单选行为
struct TagCapsuleView: View {
    /// 标签及总数的元组
    let item: (tag: String, count: Int)

    /// 绑定的协调器
    @Bindable var coordinator: TagCloudCoordinator

    /// 词频插值比例
    var bubbleRatio: Double = 0.0

    /// 是否为气泡云显示模式
    var isBubbleMode: Bool = false

    @Dependency(\.deviceInfo) var deviceInfo: any DeviceInfoProtocol

    // ── 气泡及流式布局视觉参数常量 ──
    private let bubbleModeBaseFontSize: CGFloat = 10.0
    private let bubbleModeFontSizeDelta: CGFloat = 4.0
    private let listModeFontSize: CGFloat = 13.0

    private let bubbleModeBasePaddingH: CGFloat = 8.0
    private let bubbleModePaddingHDelta: CGFloat = 4.0
    private let listModePaddingH: CGFloat = 12.0

    private let bubbleModeBasePaddingV: CGFloat = 4.0
    private let bubbleModePaddingVDelta: CGFloat = 2.0
    private let listModePaddingV: CGFloat = 6.0

    private let bubbleModeMinOpacity = 0.08
    private let bubbleModeOpacityRange = 0.35

    private let bubbleModeBaseSize: CGFloat = 42.0
    private let bubbleModeSizeDelta: CGFloat = 32.0

    // ── 透明度和边框微调参数常量 (杜绝 magic_number) ──
    private let textBackgroundSelectedOpacity = 0.2
    private let textBackgroundUnselectedOpacity = 0.15
    private let bubbleSelectedFillOpacity = 0.85
    private let bubbleUnselectedFillOpacityBase = 0.1
    private let bubbleUnselectedFillOpacityFactor = 0.5
    private let bubbleBorderOpacityBase = 0.25
    private let bubbleBorderOpacityFactor = 0.15

    // ── 气泡云列表滚动弹性缩放形变参数常量 ──
    /// 气泡形变计算的屏幕中心点最大偏移影响距离
    private let listScrollMaxDistance: CGFloat = 280.0
    /// 气泡在屏幕中心时的最大缩放系数
    private let listScrollMaxScale: CGFloat = 1.12
    /// 气泡由于偏移中心导致的缩放衰减范围
    private let listScrollScaleRange: CGFloat = 0.52
    /// 气泡在屏幕中心时的最大不透明度
    private let listScrollMaxOpacity: CGFloat = 1.0
    /// 气泡由于偏移中心导致的不透明度衰减范围
    private let listScrollOpacityRange: CGFloat = 0.55

    // ── 计算属性 ──
    private var isSelected: Bool {
        coordinator.isEditMode ? coordinator.selectedTagsForBulk.contains(item.tag) : coordinator.selectedTag == item.tag
    }

    /// 将 bubbleRatio 限制在 [0, 1] 范围内，防止外部传入越界值导致视觉变形
    private var clampedBubbleRatio: Double {
        min(max(bubbleRatio, 0.0), 1.0)
    }

    private var fontSize: CGFloat {
        isBubbleMode ? bubbleModeBaseFontSize + CGFloat(clampedBubbleRatio * bubbleModeFontSizeDelta) : listModeFontSize
    }

    private var paddingH: CGFloat {
        isBubbleMode ? bubbleModeBasePaddingH + CGFloat(clampedBubbleRatio * bubbleModePaddingHDelta) : listModePaddingH
    }

    private var paddingV: CGFloat {
        isBubbleMode ? bubbleModeBasePaddingV + CGFloat(clampedBubbleRatio * bubbleModePaddingVDelta) : listModePaddingV
    }

    private var opacity: Double {
        isBubbleMode ? bubbleModeMinOpacity + clampedBubbleRatio * bubbleModeOpacityRange : SystemOpacity.overlay
    }

    private var size: CGFloat {
        bubbleModeBaseSize + CGFloat(clampedBubbleRatio * bubbleModeSizeDelta)
    }

    private var countTextBg: Color {
        let selectedTextBg = Color.theme.white.opacity(textBackgroundSelectedOpacity)
        let unselectedTextBg = Color.appSecondary.opacity(textBackgroundUnselectedOpacity)
        return isSelected ? selectedTextBg : unselectedTextBg
    }

    // ── 主视图主体 ──
    var body: some View {
        if isBubbleMode {
            bubbleModeView
        } else {
            listModeView
        }
    }

    // ── 气泡模式子视图 ──
    /// 气泡模式子视图，利用几何读取器（GeometryReader）根据视口位置动态计算缩放与透明度，实现 3D 浮动气泡效果
    @ViewBuilder
    private var bubbleModeView: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let screenHeight = deviceInfo.screenHeight
            // 计算屏幕中心 Y 轴坐标
            let centerY = screenHeight / FeatureConstants.TagBubbleCloud.canvasHalfDivisor
            // 计算当前气泡中心与屏幕中心的绝对 Y 轴距离
            let distance = abs(frame.midY - centerY)
            // 计算归一化的偏移比例（0.0 到 1.0 之间）
            let pct = max(0, min(1, distance / listScrollMaxDistance))

            // 根据与屏幕中心的距离动态计算气泡的缩放系数与透明度，使越接近中心的气泡越突出
            let scale = listScrollMaxScale - (pct * listScrollScaleRange)
            let fOpacity = listScrollMaxOpacity - (pct * listScrollOpacityRange)

            buttonContent(isSelected: isSelected)
                .scaleEffect(scale)
                .opacity(fOpacity)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.75, blendDuration: 0), value: scale)
        }
        .fixedSize()
    }

    // ── 列表模式子视图 ──
    /// 列表模式下的标签按钮视图
    @ViewBuilder
    private var listModeView: some View {
        buttonContent(isSelected: isSelected)
    }

    // ── 共享 Button 结构 ──
    @ViewBuilder
    private func buttonContent(isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.prominent) {
                if coordinator.isEditMode {
                    if coordinator.selectedTagsForBulk.contains(item.tag) {
                        coordinator.selectedTagsForBulk.remove(item.tag)
                    } else {
                        coordinator.selectedTagsForBulk.insert(item.tag)
                    }
                } else {
                    coordinator.selectedTag = coordinator.selectedTag == item.tag ? nil : item.tag
                }
            }
            HapticFeedback.shared.trigger(.selection)
        }) {
            labelContent(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .appAccent : .appText)
        .contextMenu {
            if !coordinator.isEditMode {
                Button(action: {
                    coordinator.tagToRename = item.tag
                    coordinator.newTagName = item.tag
                }) {
                    Label(L10n.Common.rename, systemImage: DesignSystem.Icons.edit)
                }
                Button(role: .destructive, action: {
                    coordinator.tagToDelete = item.tag
                    coordinator.showDeleteConfirm = true
                }) {
                    Label(L10n.Common.delete, systemImage: DesignSystem.Icons.delete)
                }
            }
        }
    }

    // ── 共享 Label 内部渲染 ──
    @ViewBuilder
    private func labelContent(isSelected: Bool) -> some View {
        if isBubbleMode {
            VStack(spacing: DesignSystem.tiny) {
                Text(item.tag.replacingOccurrences(of: "#", with: ""))
                    .font(.system(size: fontSize, design: .rounded).weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)

                Text("\(item.count)")
                    .font(.system(size: fontSize * FeatureConstants.TagBubbleCloud.capsuleCountFontScale, weight: .bold, design: .monospaced))
                    .padding(.horizontal, SystemSpacing.tiny)
                    .padding(.vertical, FeatureConstants.TagBubbleCloud.capsuleCountVerticalPadding)
                    .background(countTextBg)
                    .clipShape(Capsule())
            }
            .padding(clampedBubbleRatio > FeatureConstants.TagBubbleCloud.capsuleBubbleRatioThreshold ? DesignSystem.medium : DesignSystem.small)
            .frame(minWidth: size * FeatureConstants.TagBubbleCloud.capsuleBubbleRatioThreshold)
            .background {
                Circle()
                    .fill(isSelected ? Color.appAccent.opacity(bubbleSelectedFillOpacity) : Color.appAccent.opacity(bubbleUnselectedFillOpacityBase + clampedBubbleRatio * bubbleUnselectedFillOpacityFactor))
            }
            .overlay {
                Circle()
                    .stroke(isSelected ? Color.appAccent : Color.appBorder.opacity(bubbleBorderOpacityBase + clampedBubbleRatio * bubbleBorderOpacityFactor), lineWidth: DesignSystem.borderWidth)
            }
            .scaleEffect(isSelected ? DesignSystem.Gallery.hoverScale : 1.0)
            .shadow(color: isSelected ? Color.appAccent.opacity(SystemOpacity.faint) : Color.appAccent.opacity(clampedBubbleRatio * FeatureConstants.TagBubbleCloud.capsuleShadowOpacityFactor), radius: clampedBubbleRatio > FeatureConstants.TagBubbleCloud.capsuleBubbleRatioThreshold ? DesignSystem.shadowRadius : FeatureConstants.TagBubbleCloud.capsuleShadowRadius, y: clampedBubbleRatio > FeatureConstants.TagBubbleCloud.capsuleBubbleRatioThreshold ? DesignSystem.shadowY : FeatureConstants.TagBubbleCloud.capsuleShadowY)
            .overlay(alignment: .topTrailing) {
                if coordinator.isEditMode {
                    editBadgeView(isSelected: isSelected)
                }
            }
        } else {
            HStack(spacing: DesignSystem.Layout.listRowSpacing) {
                Text(item.tag.replacingOccurrences(of: "#", with: ""))
                    .font(.system(size: fontSize, design: .rounded).weight(isSelected ? .semibold : .regular))

                Text("\(item.count)")
                    .font(.system(size: DesignSystem.microFontSize, weight: .bold, design: .monospaced))
                    .padding(.horizontal, SystemSpacing.tiny)
                    .padding(.vertical, SystemSpacing.divider)
                    .background(isSelected ? Color.appAccent.opacity(SystemOpacity.glass) : Color.appSecondary.opacity(SystemOpacity.ghost))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background {
                Capsule()
                    .fill(isSelected ? Color.appAccent.opacity(SystemOpacity.glass) : Color.appCard.opacity(opacity))
            }
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.appAccent.opacity(SystemOpacity.textSecondary) : Color.appBorder.opacity(SystemOpacity.overlay), lineWidth: SystemStroke.divider)
            }
            .scaleEffect(isSelected ? DesignSystem.Gallery.hoverScale : 1.0)
            .shadow(color: isSelected ? Color.appAccent.opacity(SystemOpacity.faint) : Color.appAccent.opacity(clampedBubbleRatio * FeatureConstants.TagBubbleCloud.capsuleShadowOpacityFactor), radius: clampedBubbleRatio > FeatureConstants.TagBubbleCloud.capsuleBubbleRatioThreshold ? DesignSystem.shadowRadius : FeatureConstants.TagBubbleCloud.capsuleShadowRadius, y: clampedBubbleRatio > FeatureConstants.TagBubbleCloud.capsuleBubbleRatioThreshold ? DesignSystem.shadowY : FeatureConstants.TagBubbleCloud.capsuleShadowY)
            .overlay(alignment: .topTrailing) {
                if coordinator.isEditMode {
                    editBadgeView(isSelected: isSelected)
                }
            }
        }
    }

    // ── 编辑角标 ──
    @ViewBuilder
    private func editBadgeView(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.appAccent : Color.appCard)
                .frame(width: DesignSystem.headlineFontSize, height: DesignSystem.headlineFontSize)

            if isSelected {
                Image(systemName: DesignSystem.Icons.check)
                    .font(.system(size: DesignSystem.microFontSize, weight: .black))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                    .frame(width: DesignSystem.headlineFontSize, height: DesignSystem.headlineFontSize)
            }
        }
        .offset(
            x: isBubbleMode ? -DesignSystem.small : DesignSystem.small,
            y: isBubbleMode ? DesignSystem.small : -DesignSystem.small
        )
    }
}
