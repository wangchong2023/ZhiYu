//
//  AppMetricCard.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/06/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：统一指标卡片通用组件，消除多视图中重复的 metricCard 定义。
//

import SwiftUI

/// 统一指标卡片
/// 用于展示带图标、标题、数值的指标摘要。
@MainActor
public struct AppMetricCard: View {
    public let title: String
    public let value: String
    public let icon: String
    public let color: Color
    public var iconSize: CGFloat
    public var fontSize: Font

    /// 创建指标卡片
    /// - Parameters:
    ///   - title: 指标名称
    ///   - value: 指标值（已格式化字符串）
    ///   - icon: SF Symbol 图标名
    ///   - color: 主题色
    ///   - iconSize: 图标容器尺寸
    ///   - fontSize: 图标字体
    public init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        iconSize: CGFloat = DesignTokens.ComponentSpacing.huge,
        fontSize: Font = .system(size: DesignTokens.Typography.subheadlineFontSize, weight: .bold)
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.iconSize = iconSize
        self.fontSize = fontSize
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(DesignTokens.Opacity.glass))
                        .frame(width: iconSize, height: iconSize)
                    Image(systemName: icon)
                        .font(fontSize)
                        .foregroundColor(color)
                }
                Spacer()
            }
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.appText)
            Text(title)
                .font(.caption)
                .foregroundStyle(.appSecondary)
        }
        .padding(DesignTokens.Spacing.medium)
        .appCardClip(cornerRadius: DesignTokens.Spacing.mediumRadius)
    }
}
