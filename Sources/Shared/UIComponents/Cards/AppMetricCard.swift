//
//  AppMetricCard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：统一指标卡片组件——消除 LintView/DeveloperSettingsView 中的重复 metricCard 定义。
//
import SwiftUI

/// 统一指标卡片
/// 用于展示带图标、标题、数值的指标摘要。
@MainActor
public struct AppMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var iconSize: CGFloat
    var fontSize: Font

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
        iconSize: CGFloat = DesignSystem.Metrics.iconBoxSize - DesignSystem.small,
        fontSize: Font = .system(size: DesignSystem.subheadlineFontSize, weight: .bold)
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.iconSize = iconSize
        self.fontSize = fontSize
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(DesignSystem.Opacity.glass))
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
        .padding(DesignSystem.medium)
        .appCardClip(cornerRadius: DesignSystem.mediumRadius)
    }
}
