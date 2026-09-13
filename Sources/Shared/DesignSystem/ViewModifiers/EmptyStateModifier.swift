//
//  EmptyStateModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：空状态/错误状态 ViewModifier，消除 Features 中重复的 VStack{Image+Text+Text} 空状态展示链。
//

import SwiftUI

/// 空状态修饰符，消除重复的 VStack { Image + Text + Text } 空状态展示
struct EmptyStateModifier: ViewModifier {
    let icon: String
    let title: String
    let message: String
    var iconSize: CGFloat = DesignSystem.Gallery.itemSize
    var spacing: CGFloat = SystemSpacing.small

    func body(content: Content) -> some View {
        content
            .overlay {
                VStack(spacing: spacing) {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.appText)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(DesignSystem.standardPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}

extension View {
    /// 空状态/错误状态覆盖层
    func emptyState(
        icon: String,
        title: String,
        message: String,
        iconSize: CGFloat = DesignSystem.Gallery.itemSize,
        spacing: CGFloat = SystemSpacing.small
    ) -> some View {
        modifier(EmptyStateModifier(
            icon: icon,
            title: title,
            message: message,
            iconSize: iconSize,
            spacing: spacing
        ))
    }
}
