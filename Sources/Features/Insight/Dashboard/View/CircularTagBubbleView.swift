//
//  CircularTagBubbleView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层组件
//  核心职责：定义强制正圆比例、支持字号自适应压缩与尾部自动截断的单个标签气泡，杜绝魔鬼数字以保障设计系统标准的严格落地。
//

import SwiftUI

/// 正圆形标签气泡组件
struct CircularTagBubbleView: View {
    // ── 外部依赖数据 ──
    /// 标签及总数的元组
    let item: (tag: String, count: Int)
    
    /// 视图协调器依赖
    @Bindable var coordinator: TagCloudCoordinator
    
    /// 词频插值比例 (0.0 到 1.0)
    let bubbleRatio: Double
    
    /// 鱼眼引擎动态传入的实时缩放大小
    let interactiveScale: CGFloat
    
    /// 鱼眼引擎动态传入的实时透明度
    let interactiveOpacity: Double
    
    // ── 物理排版标准常量 (杜绝魔鬼数字) ──
    /// 最小气泡直径
    private let minBubbleDiameter: CGFloat = 68.0
    /// 气泡直径差值区间 (最大直径 = 68 + 38 = 106)
    private let diameterRange: CGFloat = 38.0
    /// 基础文本字号
    private let baseTextSize: CGFloat = 11.0
    /// 文本字号词频增长系数
    private let textSizeRange: CGFloat = 4.0
    /// 右上角编辑状态勾选框尺寸
    private let checkboxDiameter: CGFloat = 18.0
    /// 自适应文字缩小防溢出的极限阈值 (48%)
    private let minTextScaleLimit: CGFloat = 0.48
    
    // ── 透明度设计常量 (杜绝魔鬼数字) ──
    /// 气泡未选中时的基础透明度
    private let minBubbleOpacity = 0.12
    /// 气泡透明度随词频变化的增长系数
    private let bubbleOpacityRange = 0.48
    /// 气泡选中时的背景高亮透明度
    private let selectedBgOpacity = 0.9
    /// 气泡选中时的阴影透明度
    private let shadowGlowOpacity = 0.35
    /// 气泡选中时的阴影羽化半径
    private let shadowGlowRadius: CGFloat = 6.0
    /// 气泡选中时的阴影纵向偏置
    private let shadowGlowOffset: CGFloat = 3.0
    /// 未选中态的描边基础透明度系数
    private let borderBaseOpacity = 0.25
    /// 描边随词频变化的增长系数
    private let borderOpacityRange = 0.25
    /// 词频胶囊背景未选中时的透明度
    private let countBadgeUnselectedOpacity = 0.18
    /// 词频胶囊背景选中时的透明度
    private let countBadgeSelectedOpacity = 0.25
    
    var body: some View {
        let isSelected = coordinator.isEditMode ? 
            coordinator.selectedTagsForBulk.contains(item.tag) : 
            coordinator.selectedTag == item.tag
        
        // 依据词频物理插值计算气泡基础直径
        let baseSize: CGFloat = minBubbleDiameter + CGFloat(bubbleRatio * diameterRange)
        
        let textFontSize: CGFloat = baseTextSize + CGFloat(bubbleRatio * textSizeRange)
        
        Button(action: {
            // 点击气泡更新选中状态
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
            VStack(spacing: SystemSpacing.tight) {
                // 标签文本：首要保证单行显示，支持字体自适应缩小(最高压缩至48%)，仍溢出时尾部截断
                Text(item.tag.replacingOccurrences(of: "#", with: ""))
                    .font(.system(size: textFontSize, design: .rounded).weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(minTextScaleLimit)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SystemSpacing.small)
                
                // 词频指示数字胶囊
                Text("\(item.count)")
                    .font(.system(size: textFontSize * 0.75, weight: .bold, design: .monospaced))
                    .padding(.horizontal, SystemSpacing.tiny)
                    .padding(.vertical, SystemSpacing.divider)
                    .background(isSelected ? Color.theme.white.opacity(countBadgeSelectedOpacity) : Color.appSecondary.opacity(countBadgeUnselectedOpacity))
                    .clipShape(Capsule())
            }
            .frame(width: baseSize, height: baseSize)
            .foregroundStyle(isSelected ? .white : .appText)
            .background {
                // 正圆底板
                Circle()
                    .fill(isSelected ? Color.appAccent.opacity(selectedBgOpacity) : Color.appAccent.opacity(minBubbleOpacity + bubbleRatio * bubbleOpacityRange))
            }
            .overlay {
                // 正圆描边
                Circle()
                    .stroke(isSelected ? Color.appAccent : Color.appBorder.opacity(borderBaseOpacity + bubbleRatio * borderOpacityRange), lineWidth: SystemStroke.divider)
            }
            .shadow(color: isSelected ? Color.appAccent.opacity(shadowGlowOpacity) : Color.clear, radius: shadowGlowRadius, y: shadowGlowOffset)
            .scaleEffect(interactiveScale)
            .opacity(interactiveOpacity)
            .overlay(alignment: .topTrailing) {
                // 编辑状态下的右上角勾选框
                if coordinator.isEditMode {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.appCard)
                            .frame(width: checkboxDiameter, height: checkboxDiameter)
                        
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(Color.theme.white)
                        } else {
                            Circle()
                                .stroke(Color.appBorder, lineWidth: SystemStroke.divider)
                                .frame(width: checkboxDiameter, height: checkboxDiameter)
                        }
                    }
                    .offset(x: -2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            // 提供与列表模式对齐的右键管理上下文菜单
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
}
