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

// MARK: - 卡片背景 + 圆角裁切修饰符

/// 卡片背景 + 圆角裁切修饰符
/// 消除重复的 `.background(Color.appCard).clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))` 链
struct AppCardClipModifier: ViewModifier {
    let cornerRadius: CGFloat
    let backgroundOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(Color.appCard.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    /// 应用卡片背景 + 圆角裁切（默认 cardRadius，不透明背景）
    func appCardClip(cornerRadius: CGFloat = DesignSystem.cardRadius) -> some View {
        modifier(AppCardClipModifier(cornerRadius: cornerRadius, backgroundOpacity: DesignSystem.fullOpacity))
    }

    /// 应用卡片背景 + 圆角裁切（自定义背景透明度）
    func appCardClip(cornerRadius: CGFloat, backgroundOpacity: Double) -> some View {
        modifier(AppCardClipModifier(cornerRadius: cornerRadius, backgroundOpacity: backgroundOpacity))
    }
}

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
/// 消除重复的 `Image(systemName: DesignSystem.Icons.forward).font(.caption2).foregroundStyle(.appSecondary)` 链
struct BreadcrumbSeparator: View {
    var icon: String = DesignSystem.Icons.forward
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
/// 消除重复的 `.frame(width: DesignSystem.IconSize.medium, height: DesignSystem.IconSize.medium)`
/// + `.frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)`
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
        iconSize: CGFloat = DesignSystem.IconSize.medium,
        touchSize: CGFloat = DesignSystem.IconSize.xlarge
    ) -> some View {
        modifier(HIGTouchTargetModifier(iconSize: iconSize, touchSize: touchSize))
    }
}
