//
//  Component.swift
//  ZhiYu
//
//  系统层级：[Shared] 共享标准层
//  核心职责：Layer 3 组件特定尺寸层 — 大值、组件语义映射、组件特定尺寸、图标尺寸。
//           依赖 System 层，禁止反向依赖。
//

import SwiftUI

// MARK: - ComponentSpacing（组件特定尺寸）
public enum ComponentSpacing {
    // MARK: 大值（超出 Layer 1 10档范围）
    public static let section: CGFloat = 20
    public static let sectionLarge: CGFloat = 24
    public static let huge: CGFloat = 32
    public static let ultra: CGFloat = 40
    public static let massive: CGFloat = 48
    public static let colossal: CGFloat = 64

    // MARK: 组件语义（从 System 映射）
    public static let cardPadding: CGFloat = SystemSpacing.content
    public static let listRowGap: CGFloat = SystemSpacing.element
    public static let iconTextGap: CGFloat = SystemSpacing.small
    public static let buttonInternalPadding: CGFloat = SystemSpacing.medium
    public static let chipPadding: CGFloat = SystemSpacing.tiny

    // MARK: 组件特定尺寸
    public static let toolbarHeight: CGFloat = 44
    public static let buttonHeight: CGFloat = 44
    public static let compactButtonHeight: CGFloat = 32
    public static let inputFieldHeight: CGFloat = 50
    public static let minTouchTarget: CGFloat = 44
    public static let capsuleHeight: CGFloat = 28
    public static let inputBarHeight: CGFloat = 54
    public static let chartHeight: CGFloat = 220
    public static let chartHeightCompact: CGFloat = 160

    // MARK: 图标尺寸（组件特定）
    public static let iconCompact: CGFloat = 18
    public static let iconStandard: CGFloat = 22
    public static let iconLarge: CGFloat = 24
    public static let iconDisplay: CGFloat = 48
    public static let iconHuge: CGFloat = 64
}
