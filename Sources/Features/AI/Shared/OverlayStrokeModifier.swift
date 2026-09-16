//
//  OverlayStrokeModifier.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：圆角边框描边 ViewModifier，消除 Features/AI 中重复的 overlay(RoundedRectangle().stroke()) 链。
//

import SwiftUI

/// 圆角边框描边修饰符，消除重复的 overlay(RoundedRectangle().stroke()) 链
struct OverlayStrokeModifier: ViewModifier {
    var cornerRadius: CGFloat
    var borderColor: Color
    var borderWidth: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }
}

extension View {
    /// 圆角边框描边
    func overlayStroke(
        cornerRadius: CGFloat = DesignSystem.standardRadius,
        borderColor: Color = Color.appBorder.opacity(DesignSystem.Opacity.subtle),
        borderWidth: CGFloat = DesignSystem.borderWidth
    ) -> some View {
        modifier(OverlayStrokeModifier(
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            borderWidth: borderWidth
        ))
    }
}
