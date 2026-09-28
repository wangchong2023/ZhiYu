//
//  AppDecorators.swift
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

// MARK: - App Dot Pattern

/// 工业级点阵背景
/// 使用 Canvas 高性能渲染重复的圆点模式，常用于背景装饰。
public struct AppDotPattern: View {
    public var dotColor: Color = .appBorder
    public var spacing: CGFloat = DesignTokens.Spacing.wide
    public var dotSize: CGFloat = DesignTokens.Spacing.atomic

    public init(dotColor: Color = .appBorder, spacing: CGFloat = DesignTokens.Spacing.wide, dotSize: CGFloat = DesignTokens.Spacing.atomic) {
        self.dotColor = dotColor
        self.spacing = spacing
        self.dotSize = dotSize
    }

    public var body: some View {
        Canvas { context, size in
            guard size.width > 1 && size.height > 1 else { return }
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(dotColor.opacity(DesignTokens.Opacity.disabled))
                    )
                }
            }
        }
    }
}
