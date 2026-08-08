//
//  DesignSystem.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI

/// 智宇设计系统 (ZhiYu Design System)
/// 统一管理应用内的间距、圆角、排版、颜色与动效规范。
public enum DesignSystem {

    // MARK: - 1. 原子间距 (Spacing)
    public static let atomic: CGFloat = Spacing.atomic
    public static let tiny: CGFloat = Spacing.tiny
    public static let small: CGFloat = Spacing.small
    public static let medium: CGFloat = Spacing.medium
    public static let standardPadding: CGFloat = Spacing.standardPadding
    public static let large: CGFloat = Spacing.large
    public static let wide: CGFloat = Spacing.wide
    public static let giant: CGFloat = Spacing.giant
    public static let huge: CGFloat = Spacing.huge
    public static let inputBarHeight: CGFloat = Spacing.inputBarHeight
    public static let loosePadding: CGFloat = Spacing.loosePadding
    public static let widePadding: CGFloat = Spacing.widePadding
    public static let tightPadding: CGFloat = Spacing.tightPadding
    
    // 兼容原 DesignSystem.microRadius 等命名
    public static let microRadius: CGFloat = Spacing.microRadius
    public static let smallRadius: CGFloat = Spacing.smallRadius
    public static let mediumRadius: CGFloat = Spacing.mediumRadius
    public static let cardRadius: CGFloat = Spacing.cardRadius
    public static let standardRadius: CGFloat = Spacing.standardRadius
    public static let largeRadius: CGFloat = Spacing.largeRadius
    public static let chipRadius: CGFloat = Spacing.chipRadius
    
    // 兼容原 DesignSystem.iconTiny 等命名
    public static let iconTiny: CGFloat = Spacing.iconTiny
    public static let iconSmall: CGFloat = Spacing.iconSmall
    public static let iconMedium: CGFloat = Spacing.iconMedium
    public static let iconLarge: CGFloat = Spacing.iconLarge
    public static let iconHuge: CGFloat = Spacing.iconHuge
    public static let iconDisplay: CGFloat = Spacing.iconDisplay
    public static let smallIconSize: CGFloat = Spacing.smallIconSize
    public static let titleIconSize: CGFloat = Spacing.titleIconSize
    public static let largeIconSize: CGFloat = Spacing.largeIconSize
    public static let microIconSize: CGFloat = Spacing.microIconSize
    public static let captionIconSize: CGFloat = Spacing.captionIconSize

    // MARK: - 18. 排版规范 (Typography)
    public typealias HeadingLevel = Typography.HeadingLevel
    public static let microFontSize: CGFloat = Typography.microFontSize
    public static let captionFontSize: CGFloat = Typography.captionFontSize
    public static let caption2FontSize: CGFloat = Typography.caption2FontSize
    public static let subheadlineFontSize: CGFloat = Typography.subheadlineFontSize
    public static let bodyFontSize: CGFloat = Typography.bodyFontSize
    public static let standardFontSize: CGFloat = Typography.standardFontSize
    public static let headlineFontSize: CGFloat = Typography.headlineFontSize
    public static let titleFontSize: CGFloat = Typography.titleFontSize
    public static let title2FontSize: CGFloat = Typography.HeadingLevel.h2.size
    public static let displayFontSize: CGFloat = Typography.displayFontSize
    public static var captionFont: Font { Typography.captionFont }
    public static var caption2Font: Font { Typography.caption2Font }
    public static var secondaryFont: Font { Typography.secondaryFont }
    public static var subheadlineFont: Font { Typography.secondaryFont }
    public static var titleFont: Font { Typography.titleFont }

    // MARK: - 19. 视觉风格常数 (Styling)
    public static let borderWidth: CGFloat = Spacing.borderWidth
    public static let shadowRadius: CGFloat = Spacing.shadowRadius
    public static let shadowY: CGFloat = Spacing.shadowY
    public static let shadowOpacity: Double = Spacing.shadowOpacity
    public static let shadowColor = Colors.Opacity.shadowColor
    public static let glassOpacity: Double = Colors.Opacity.glassOpacity
    public static let subtleOpacity: Double = Colors.subtleOpacity
    public static let subtleFillOpacity: Double = Colors.subtleFillOpacity
    public static let halfOpacity: Double = Colors.halfOpacity
    public static let fullOpacity: Double = Colors.Opacity.fullOpacity
    public static let disabledOpacity: Double = Colors.Opacity.disabledOpacity
    public static let pressedOpacity: Double = Colors.Opacity.pressedOpacity
    public static let dimmedOpacity: Double = Colors.Opacity.dimmedOpacity
    public static let secondaryOpacity: Double = Colors.Opacity.secondaryOpacity
    public static let coachMarkBackgroundOpacity: Double = Colors.Opacity.coachMarkBackgroundOpacity
    
    public static let surfaceOpacity: Double = Colors.Opacity.surfaceOpacity
    public static let cardOpacity: Double = Colors.Opacity.cardOpacity
    public static let translucentOpacity: Double = Colors.Opacity.translucentOpacity
    public static let softOpacity: Double = Colors.Opacity.softOpacity
    public static let ghostOpacity: Double = Colors.Opacity.ghostOpacity
    
    public static let dividerOpacity: Double = Colors.Opacity.dividerOpacity
    public static let accentStrokeOpacity: Double = Colors.Opacity.accentStrokeOpacity
    
    // MARK: - 20. 容器颜色 (Container Colors)
    public static var containerBackground: Color { Color.appCard }
    public static var containerBorder: Color { Color.appBorder }
    public static var containerMaterial: Color { Color.appCard } 

    // MARK: - 21. 动效常数 (Legacy Animation Bridge)
    public static var standardAnimation: SwiftUI.Animation { Animations.Interaction.standardAnimation }
    public static var fastAnimation: SwiftUI.Animation { Animations.Interaction.fastAnimation }
    
    // MARK: - 21. 组件兼容性别名 (Component Aliases)
    #if !WIDGET && !os(watchOS)
    public typealias AppSection<Content: View> = StandardSection<Content>
    public typealias Card<Content: View> = AppCard<Content>
    public typealias BorderedCard<Content: View> = AppBorderedCard<Content>
    public typealias GlassCard<Content: View> = AppGlassCard<Content>
    public typealias PrimaryButton = AppPrimaryButton
    public typealias CapsuleButton = AppCapsuleButton
    public typealias TextField = AppTextField
    public typealias TagField = AppTagField
    public typealias MonospacedEditor = AppMonospacedEditor
    public typealias IconChip = AppIconChip
    public typealias Badge = AppBadge
    public typealias ScrollableChips<Data: RandomAccessCollection, Content: View> = AppScrollableChips<Data, Content> where Data.Element: Hashable
    public typealias SectionHeader = AppSectionHeader
    public typealias LabeledRow = AppLabeledRow
    public typealias StepRow = AppStepRow
    public typealias Divider = AppDivider
    public typealias AccentLine = AppAccentLine
    public typealias PulseDot = AppPulseDot
    public typealias Glow = AppGlow
    public typealias Skeleton = AppSkeleton
    public typealias SkeletonBox = AppSkeleton
    public typealias DotPattern = AppDotPattern
    public typealias IconBox = AppIconBox
    
    public typealias EmptyState = AppEmptyState
    public typealias LoadingOverlay = AppLoadingOverlay
    public typealias Toast = AppToast
    #endif
}
