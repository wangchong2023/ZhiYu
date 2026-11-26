//
//  SharedViewModifiers.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：通用原子视图与修饰器集合，提供 GeometryReader 安全守卫、面包屑分隔符、
//           小节标题标签与 HIG 44x44 点击热区扩展。
//

import SwiftUI

// MARK: - GeometryReader 安全守卫修饰符

/// GeometryReader 尺寸守卫修饰符
/// 消除重复的 `GeometryReader { geo in if geo.size.width > 1 && geo.size.height > 1 { ... } }` 模式
public struct SafeGeometryReader<Content: View>: View {
    public let content: (GeometryProxy) -> Content

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            if geo.size.width > 1 && geo.size.height > 1 {
                content(geo)
            }
        }
    }
}

// MARK: - 面包屑分隔符

/// 面包屑/导航分隔符视图
public struct BreadcrumbSeparator: View {
    public var icon: String
    public var font: Font

    public init(icon: String = DesignTokens.Icons.forward, font: Font = .caption2) {
        self.icon = icon
        self.font = font
    }

    public var body: some View {
        Image(systemName: icon)
            .font(font)
            .foregroundStyle(.appSecondary)
    }
}

// MARK: - 小节标题标签

/// 小节标题标签视图
public struct SectionCaptionLabel: View {
    public let title: String
    public var weight: Font.Weight

    public init(_ title: String, weight: Font.Weight = .medium) {
        self.title = title
        self.weight = weight
    }

    public init(title: String, weight: Font.Weight = .medium) {
        self.title = title
        self.weight = weight
    }

    public var body: some View {
        Text(title)
            .font(.caption.weight(weight))
            .foregroundStyle(.appSecondary)
    }
}

// MARK: - HIG 点击热区扩展

/// HIG 点击热区扩展修饰符
public struct HIGTouchTargetModifier: ViewModifier {
    public let iconSize: CGFloat
    public let touchSize: CGFloat

    public init(iconSize: CGFloat, touchSize: CGFloat) {
        self.iconSize = iconSize
        self.touchSize = touchSize
    }

    public func body(content: Content) -> some View {
        content
            .frame(width: iconSize, height: iconSize)
            .frame(width: touchSize, height: touchSize)
            .contentShape(Rectangle())
    }
}

public extension View {
    /// 应用 HIG 推荐的 44x44 物理像素点击热区（默认 medium→xlarge）
    func higTouchTarget(
        iconSize: CGFloat = DesignTokens.IconSize.medium,
        touchSize: CGFloat = DesignTokens.IconSize.xlarge
    ) -> some View {
        modifier(HIGTouchTargetModifier(iconSize: iconSize, touchSize: touchSize))
    }
}
