//
//  AppAdaptiveComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 通用 UI 组件层
//  核心职责：跨平台自适应 UI 原语（AppAdaptiveGrid / AppAdaptiveActionButton），
//           统一内聚 iOS/macOS 布局与按钮差异，消除业务视图中散落的 idiom == .mac 分支。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 自适应多列网格原语

/// 自适应网格默认列数常量
public enum AdaptiveGridDefaults {
    public static let compactColumns = 2
    public static let desktopColumns = 4
    public static let minimumColumns = 1
}

/// 跨平台自适应网格：macOS 桌面宽屏自动展开为多列，iOS/iPadOS 保持紧凑列数。
public struct AppAdaptiveGrid<Content: View>: View {
    @Environment(\.interfaceIdiom) private var idiom

    private let compactColumns: Int
    private let desktopColumns: Int
    private let spacing: CGFloat
    private let content: () -> Content

    /// 初始化跨平台自适应网格
    /// - Parameters:
    ///   - compactColumns: iOS 紧凑形态列数（默认 2 列）
    ///   - desktopColumns: macOS 桌面宽屏列数（默认 4 列）
    ///   - spacing: 网格行列间距
    ///   - content: 网格子视图构建闭包
    public init(
        compactColumns: Int = AdaptiveGridDefaults.compactColumns,
        desktopColumns: Int = AdaptiveGridDefaults.desktopColumns,
        spacing: CGFloat = DesignTokens.Spacing.standardPadding,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.compactColumns = compactColumns
        self.desktopColumns = desktopColumns
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        let count = idiom == .mac ? desktopColumns : compactColumns
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: max(AdaptiveGridDefaults.minimumColumns, count)
        )
        LazyVGrid(columns: columns, spacing: spacing, content: content)
    }
}

// MARK: - 自适应操作按钮原语

/// 跨平台操作按钮语义样式
public enum AppActionButtonStyle {
    /// 主操作按钮（高对比强调色实心填充）
    case primary
    /// 次操作按钮（柔和强调色填充 + 细描边）
    case secondary
    /// 破坏性操作按钮（警示红弱填充）
    case destructive
}

/// 跨平台自适应操作按钮：
/// - macOS：遵循 Apple HIG，采用紧凑内容宽度（可配最小宽度）+ `.buttonStyle(.plain)` 去除系统灰框；
/// - iOS：自动延展为全宽大按钮，便于单手拇指触控。
public struct AppAdaptiveActionButton: View {
    @Environment(\.interfaceIdiom) private var idiom

    private let title: String
    private let systemImage: String?
    private let style: AppActionButtonStyle
    private let isDisabled: Bool
    private let desktopMinWidth: CGFloat?
    private let action: () -> Void

    public init(
        title: String,
        systemImage: String? = nil,
        style: AppActionButtonStyle = .primary,
        isDisabled: Bool = false,
        desktopMinWidth: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.isDisabled = isDisabled
        self.desktopMinWidth = desktopMinWidth
        self.action = action
    }

    public var body: some View {
        let cornerRadius = idiom == .mac ? DesignTokens.Spacing.mediumRadius : DesignTokens.SystemRadius.card
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.small) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(buttonFont)
            .foregroundStyle(foregroundColor)
            .frame(
                minWidth: idiom == .mac ? desktopMinWidth : nil,
                maxWidth: idiom == .mac ? nil : .infinity
            )
            .padding(.horizontal, DesignTokens.Spacing.wide)
            .padding(.vertical, idiom == .mac ? DesignTokens.Spacing.medium : DesignTokens.Spacing.standardPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: DesignTokens.Spacing.borderWidth)
            )
            .opacity(isDisabled ? DesignTokens.Opacity.soft : DesignTokens.Opacity.solid)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var buttonFont: Font {
        switch style {
        case .primary:
            return idiom == .mac ? .subheadline.weight(.semibold) : .headline
        case .secondary:
            return idiom == .mac ? .subheadline.weight(.medium) : .headline
        case .destructive:
            return .subheadline.weight(.medium)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: .appAccent
        case .destructive: Color.theme.red
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: .appAccent
        case .secondary: Color.appAccent.opacity(DesignTokens.Opacity.subtle)
        case .destructive: Color.theme.red.opacity(DesignTokens.Opacity.light)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: .clear
        case .secondary: Color.appAccent.opacity(DesignTokens.Opacity.medium)
        case .destructive: .clear
        }
    }
}
