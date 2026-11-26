//
//  AccentIconBox.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：Accent 图标块通用原子组件，统一带主题色底框的 SF Symbol 视觉容器。
//

import SwiftUI

/// Accent 图标块组件
public struct AccentIconBox: View {
    public let iconName: String
    public var fontSize: CGFloat
    public var boxSize: CGFloat
    public var cornerRadius: CGFloat
    public var backgroundOpacity: Double

    public init(
        iconName: String,
        fontSize: CGFloat = DesignTokens.Spacing.large,
        boxSize: CGFloat = DesignTokens.Metrics.largeIconBoxSize,
        cornerRadius: CGFloat = DesignTokens.Spacing.smallRadius,
        backgroundOpacity: Double = DesignTokens.Colors.Opacity.glassOpacity
    ) {
        self.iconName = iconName
        self.fontSize = fontSize
        self.boxSize = boxSize
        self.cornerRadius = cornerRadius
        self.backgroundOpacity = backgroundOpacity
    }

    public var body: some View {
        Image(systemName: iconName)
            .font(.system(size: fontSize))
            .foregroundStyle(.appAccent)
            .frame(width: boxSize, height: boxSize)
            .background(Color.appAccent.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
