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

    func body(content: Content) -> some View {
        content
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    /// 应用卡片背景 + 圆角裁切（默认 cardRadius）
    func appCardClip(cornerRadius: CGFloat = DesignSystem.cardRadius) -> some View {
        modifier(AppCardClipModifier(cornerRadius: cornerRadius))
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

// MARK: - 日期格式化辅助

/// 页面元信息日期格式化辅助
/// 消除重复的 `date.formatted(.dateTime.year().month().day().locale(Localized.currentLocale))` 调用
enum PageDateFormatting {
    /// 格式化日期为本地化的年月日字符串
    static func formattedYearMonthDay(_ date: Date) -> String {
        date.formatted(
            .dateTime.year().month().day().locale(Localized.currentLocale)
        )
    }
}

// MARK: - 图标圆形容器

/// 图标圆形容器修饰符
/// 消除重复的 `Circle().fill(color.opacity(...)).frame(width: size, height: size)` + 图标组合
struct AppIconCircle: View {
    let icon: String
    let color: Color
    let size: CGFloat
    var iconFont: Font = .system(size: DesignSystem.subheadlineFontSize, weight: .bold)

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(DesignSystem.Opacity.glass))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(iconFont)
                .foregroundColor(color)
        }
    }
}

// MARK: - 行尾导航箭头

/// 行尾导航箭头视图
/// 消除重复的 `Image(systemName: DesignSystem.Icons.forward).font(.caption.weight(...)).foregroundStyle(.appSecondary.opacity(...))` 链
struct NavigationChevron: View {
    var weight: Font.Weight = .semibold
    var opacity: Double = DesignSystem.Opacity.disabled

    var body: some View {
        Image(systemName: DesignSystem.Icons.forward)
            .font(.caption.weight(weight))
            .foregroundStyle(.appSecondary.opacity(opacity))
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
