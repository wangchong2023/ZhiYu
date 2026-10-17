//
//  SharedViewModifiers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：UIComponents 内部共享 ViewModifier，消除跨文件的 background+clipShape、GeometryReader 守卫、
//           面包屑分隔符、元信息日期格式化等高频重复修饰符链。
//

import SwiftUI
import UFPDesignSystem

// MARK: - GeometryReader 安全守卫修饰符

/// GeometryReader 尺寸守卫修饰符
/// 消除重复的 `GeometryReader { geo in if geo.size.width > 1 && geo.size.height > 1 { ... } }` 模式
struct SafeGeometryReader<Content: View>: View {
    @ViewBuilder let content: (GeometryProxy) -> Content

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 1 && geo.size.height > 1 {
                content(geo)
            }
        }
    }
}

// MARK: - 面包屑分隔符

/// 面包屑/导航分隔符视图
/// 消除重复的 `Image(systemName: DesignTokens.Icons.forward).font(.caption2).foregroundStyle(.appSecondary)` 链
struct BreadcrumbSeparator: View {
    var icon: String = DesignTokens.Icons.forward
    var font: Font = .caption2

    var body: some View {
        Image(systemName: icon)
            .font(font)
            .foregroundStyle(.appSecondary)
    }
}

// MARK: - 小节标题标签

/// 小节标题标签视图
/// 消除重复的 `Text(title).font(.caption.weight(.medium)).foregroundStyle(.appSecondary)` 链
struct SectionCaptionLabel: View {
    let title: String
    var weight: Font.Weight = .medium

    var body: some View {
        Text(title)
            .font(.caption.weight(weight))
            .foregroundStyle(.appSecondary)
    }
}

// MARK: - HIG 点击热区扩展

/// HIG 点击热区扩展修饰符
/// 消除重复的 `.frame(width: DesignTokens.IconSize.medium, height: DesignTokens.IconSize.medium)`
/// + `.frame(width: DesignTokens.IconSize.xlarge, height: DesignTokens.IconSize.xlarge)`
/// + `.contentShape(Rectangle())` 链
struct HIGTouchTargetModifier: ViewModifier {
    let iconSize: CGFloat
    let touchSize: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(width: iconSize, height: iconSize)
            .frame(width: touchSize, height: touchSize)
            .contentShape(Rectangle())
    }
}

extension View {
    /// 应用 HIG 推荐的 44x44 物理像素点击热区（默认 medium→xlarge）
    func higTouchTarget(
        iconSize: CGFloat = DesignTokens.IconSize.medium,
        touchSize: CGFloat = DesignTokens.IconSize.xlarge
    ) -> some View {
        modifier(HIGTouchTargetModifier(iconSize: iconSize, touchSize: touchSize))
    }
}
