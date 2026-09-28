//
//  StatCard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

/// 统计指标卡片小组件
/// 负责以紧凑网格形式展示关键业务指标（如页面总数、最近新增、同步成功率等）。
public struct StatCard: View {
    // MARK: - Properties
    
    public let title: String
    public let value: String
    public let icon: String
    public let color: Color

    // MARK: - Initialization
    
    public init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }

    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium - DesignTokens.Spacing.atomic) { // 10
            // 带发光效果的图标
            ZStack {
                Circle()
                    .fill(color.opacity(DesignTokens.SystemOpacity.glassStrong))
                    .frame(width: DesignTokens.Spacing.Sidebar.backButtonWidth, height: DesignTokens.Spacing.Sidebar.backButtonWidth)

                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(DesignTokens.Colors.Opacity.secondaryOpacity)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(value)
                .font(.system(size: DesignTokens.Metrics.heroValueSize - 2, weight: .bold, design: .rounded)) // 30
                .foregroundStyle(.appText)

            Text(title)
                .font(.caption)
                .foregroundStyle(.appSecondary)
        }
        .frame(maxWidth: .infinity)
        .appPadding(.vertical, .standardPadding)
        .background(Color.appCard.opacity(DesignTokens.Colors.Opacity.surfaceOpacity))
        .appCornerRadius(.medium)
        .shadow(color: .black.opacity(DesignTokens.SystemOpacity.faint), radius: DesignTokens.SystemSpacing.medium, x: 0, y: DesignTokens.Spacing.shadowY)
    }
}
