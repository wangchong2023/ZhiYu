//
//  QuickActionRow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
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
            HStack(spacing: Spacing.medium + Spacing.atomic * 2) { // 14
                // 渐变图标背景
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.small)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(Colors.glassOpacity * 2), color.opacity(Colors.glassOpacity * 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: Spacing.Metrics.iconBoxSize + 4, height: Spacing.Metrics.iconBoxSize + 4) // 44

                    Image(systemName: icon)
                        .font(.system(size: Spacing.titleIconSize, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: Spacing.atomic * 1.5) { // 3
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.appText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }

                Spacer()

                Image(systemName: DesignSystem.Icons.forward)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appSecondary.opacity(Colors.dimmedOpacity))
            }
            .padding(Spacing.standardPadding)
            .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.medium))
            .shadow(
                color: .black.opacity(isPressed ? Spacing.shadowOpacity : Spacing.shadowOpacity * 2), 
                radius: isPressed ? Spacing.shadowRadius / 2.5 : Spacing.shadowRadius / 1.25, 
                x: 0, 
                y: isPressed ? Spacing.shadowY / 2 : Spacing.shadowY
            )
            .scaleEffect(isPressed ? Animations.Interaction.pressScale : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}
