//
//  QuickActionRow.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：快速操作行通用组件，提供图标、主标题、副标题及进入指示器与按下缩放效果。
//

import SwiftUI

/// 快速操作行组件
/// 提供图标、主标题、副标题及进入指示器，支持按下缩放效果。
public struct QuickActionRow: View {
    // MARK: - Properties

    public let icon: String
    public let title: String
    public let subtitle: String
    public let color: Color
    public let action: () -> Void

    @State private var isPressed = false

    // MARK: - Initialization

    public init(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.SystemSpacing.contentMedium) {
                // 渐变图标背景
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Spacing.small)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(DesignTokens.SystemOpacity.glassStrong),
                                    color.opacity(DesignTokens.SystemOpacity.faint)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DesignTokens.ComponentSpacing.buttonHeight, height: DesignTokens.ComponentSpacing.buttonHeight)

                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.Spacing.titleIconSize, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tight) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.appText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }

                Spacer()

                Image(systemName: DesignTokens.Icons.forward)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appSecondary.opacity(DesignTokens.Colors.dimmedOpacity))
            }
            .padding(DesignTokens.Spacing.standardPadding)
            .appCardClip(cornerRadius: DesignTokens.Spacing.medium, backgroundOpacity: DesignTokens.Opacity.prominent)
            .shadow(
                color: .black.opacity(isPressed ? DesignTokens.SystemOpacity.ghost : DesignTokens.SystemOpacity.faint),
                radius: isPressed ? DesignTokens.SystemSpacing.tiny : DesignTokens.SystemSpacing.element,
                x: 0,
                y: isPressed ? DesignTokens.SystemSpacing.atomic : DesignTokens.Spacing.shadowY
            )
            .scaleEffect(isPressed ? DesignTokens.Animations.Interaction.pressScale : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: DesignTokens.Animations.microDuration)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: DesignTokens.Animations.microDuration)) { isPressed = false }
                }
        )
    }
}
