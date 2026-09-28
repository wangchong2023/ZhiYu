//
//  DesignSystem.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统组件别名与容器颜色。Token 令牌已迁移至 UFPDesignSystem.DesignTokens。
//
import SwiftUI
import UFPDesignSystem

/// 智宇设计系统 (ZhiYu Design System)
/// 组件 typealias 与容器颜色。所有 Token 令牌请使用 `DesignTokens.*`。
public enum DesignSystem {

    // MARK: - 容器颜色 (Container Colors)
    public static var containerBackground: Color { Color.appCard }
    public static var containerBorder: Color { Color.appBorder }
    public static var containerMaterial: Color { Color.appCard }

    // MARK: - 组件兼容性别名 (Component Aliases)
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
