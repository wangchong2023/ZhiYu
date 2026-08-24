//
//  System.swift
//  ZhiYu
//
//  系统层级：[Shared] 共享标准层
//  核心职责：Layer 2 语义映射层 — 将 Reference 原子值映射为语义名，按用途分类。
//           视图代码主要引用此层。禁止引用 Component 层。
//

import SwiftUI

// MARK: - SystemSpacing（语义间距）
public enum SystemSpacing {
    public static let none: CGFloat = Reference.Spacing.zero
    public static let hairline: CGFloat = Reference.Spacing.half
    public static let divider: CGFloat = Reference.Spacing.one
    public static let atomic: CGFloat = Reference.Spacing.two
    public static let tight: CGFloat = Reference.Spacing.three
    public static let tiny: CGFloat = Reference.Spacing.four
    public static let small: CGFloat = Reference.Spacing.six
    public static let element: CGFloat = Reference.Spacing.eight
    public static let medium: CGFloat = Reference.Spacing.twelve
    public static let content: CGFloat = Reference.Spacing.sixteen
}

// MARK: - SystemOpacity（语义透明度）
public enum SystemOpacity {
    // 交互状态
    public static let hidden: Double = Reference.Opacity.zero
    public static let ghost: Double = Reference.Opacity.five
    public static let faint: Double = Reference.Opacity.ten
    public static let glass: Double = Reference.Opacity.fifteen
    public static let glassStrong: Double = Reference.Opacity.thirty
    public static let overlay: Double = Reference.Opacity.sixty
    public static let disabled: Double = Reference.Opacity.forty
    public static let active: Double = Reference.Opacity.full

    // 文本层级
    public static let textSecondary: Double = Reference.Opacity.eighty
    public static let textTertiary: Double = Reference.Opacity.seventy
}

// MARK: - SystemRadius（语义圆角）
public enum SystemRadius {
    public static let none: CGFloat = Reference.Radius.zero
    public static let micro: CGFloat = Reference.Radius.two
    public static let chip: CGFloat = Reference.Radius.four
    public static let small: CGFloat = Reference.Radius.eight
    public static let card: CGFloat = Reference.Radius.twelve
    public static let large: CGFloat = Reference.Radius.sixteen
    public static let section: CGFloat = Reference.Radius.twenty
    public static let capsule: CGFloat = Reference.Radius.full
}

// MARK: - SystemStroke（语义描边）
public enum SystemStroke {
    public static let none: CGFloat = Reference.Stroke.zero
    public static let hairline: CGFloat = Reference.Stroke.half
    public static let border: CGFloat = Reference.Stroke.thin
    public static let divider: CGFloat = Reference.Stroke.one
    public static let emphasis: CGFloat = Reference.Stroke.oneHalf
    public static let selected: CGFloat = Reference.Stroke.two
    public static let heavy: CGFloat = Reference.Stroke.four
}

// MARK: - SystemFontSize（语义字号）
public enum SystemFontSize {
    public static let micro: CGFloat = Reference.FontSize.micro
    public static let caption: CGFloat = Reference.FontSize.caption
    public static let footnote: CGFloat = Reference.FontSize.footnote
    public static let subheadline: CGFloat = Reference.FontSize.subheadline
    public static let body: CGFloat = Reference.FontSize.body
    public static let headline: CGFloat = Reference.FontSize.headline
    public static let title3: CGFloat = Reference.FontSize.title3
    public static let title2: CGFloat = Reference.FontSize.title2
    public static let title: CGFloat = Reference.FontSize.title
    public static let largeTitle: CGFloat = Reference.FontSize.largeTitle
    public static let display: CGFloat = Reference.FontSize.display
    public static let hero: CGFloat = Reference.FontSize.hero
}

// MARK: - SystemShadow（语义阴影）
public enum SystemShadow {
    public static let radiusSmall: CGFloat = Reference.Spacing.four
    public static let radiusMedium: CGFloat = Reference.Spacing.eight
    public static let offsetSmall: CGFloat = Reference.Spacing.four
}
