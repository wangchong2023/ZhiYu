//
//  AppButtons.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - App Primary Button

/// 品牌色主操作按钮
/// 支持渐变背景、加载指示器及图标显示。
public struct AppPrimaryButton: View {
    public let title: String
    public var icon: String?
    public var isLoading: Bool = false
    public var gradientColors: [Color] = [.appAccent, .appAccent.opacity(DesignSystem.subtleOpacity)]
    public var maxWidth: CGFloat? = .infinity
    public let action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        gradientColors: [Color] = [.appAccent, .appAccent.opacity(DesignSystem.subtleOpacity)],
        maxWidth: CGFloat? = .infinity,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.gradientColors = gradientColors
        self.maxWidth = maxWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            AppButtonLabel(title: title, icon: icon, isLoading: isLoading, fontWeight: .semibold)
                .frame(maxWidth: maxWidth)
                .padding(.vertical, Spacing.medium)
                .padding(.horizontal, Spacing.large)
                .background(
                    LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                .foregroundStyle(.white)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - App Bordered Button

/// 品牌色边框按钮
/// 适用于次要但依然重要的操作，替代系统默认的 .bordered 样式以解决白边问题。
public struct AppBorderedButton: View {
    public let title: String
    public var icon: String?
    public var color: Color = .appAccent
    public var maxWidth: CGFloat? = .infinity
    public let action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        color: Color = .appAccent,
        maxWidth: CGFloat? = .infinity,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.maxWidth = maxWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            AppButtonLabel(title: title, icon: icon, isLoading: false, fontWeight: .medium)
                .frame(maxWidth: maxWidth)
                .padding(.vertical, Spacing.medium)
                .padding(.horizontal, Spacing.large)
                .background(color.opacity(SystemOpacity.ghost))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cardRadius)
                        .stroke(color.opacity(DesignSystem.softOpacity), lineWidth: Spacing.borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                .foregroundStyle(color)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 共享按钮标签

/// 按钮内部标签（图标 + 标题 + 可选加载指示器），消除 AppPrimaryButton / AppBorderedButton 间重复的 HStack + Image/ProgressView + Text 组合。
private struct AppButtonLabel: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let fontWeight: Font.Weight

    var body: some View {
        HStack(spacing: Spacing.small) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let icon {
                Image(systemName: icon)
            }
            Text(title)
                .fontWeight(fontWeight)
        }
    }
}

// MARK: - App Capsule Button

/// 胶囊形组件
/// - 无 action 时：纯展示标签，适用于状态徽章、功能标识。
/// - 有 action 时：可交互按钮，自动携带 VoiceOver `.isButton` 无障碍特征（符合 HIG）。
public struct AppCapsuleButton: View {
    public let title: String
    public var icon: String?
    public var isPrimary: Bool = true
    public var color: Color = .appAccent
    /// 可选操作闭包；提供时视图包装为 Button，自动获得 .isButton 无障碍特征
    public var action: (() -> Void)?

    public init(
        title: String,
        icon: String? = nil,
        isPrimary: Bool = true,
        color: Color = .appAccent,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.isPrimary = isPrimary
        self.color = color
        self.action = action
    }

    public var body: some View {
        if let action {
            // 有操作时使用 Button，VoiceOver 自动识别为可点击控件
            Button(action: action) {
                capsuleLabel
            }
            .buttonStyle(.plain)
        } else {
            // 纯展示时保持普通 View，不干扰无障碍树
            capsuleLabel
        }
    }
    
    // MARK: - 胶囊样式内容
    private var capsuleLabel: some View {
        HStack(spacing: Spacing.tiny) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, DesignSystem.small)
        .background(isPrimary ? color : Color.appCard)
        .foregroundStyle(isPrimary ? .white : .appSecondary)
        .clipShape(Capsule())
    }
}

// MARK: - Button Styles

/// 点击缩放交互样式
/// 为按钮提供物理反馈效果。
public struct ScaleButtonStyle: ButtonStyle {
    public init() {}

    /// 创建Body
    /// - Parameter configuration: configuration
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Animations.Interaction.pressScale : 1.0)
            .animation(.easeOut(duration: Spacing.Action.animationDuration), value: configuration.isPressed)
    }
}

// MARK: - 清除按钮

/// 搜索框清除按钮，消除多处重复的 Image + foregroundStyle 修饰符链
public struct ClearSearchButton: View {
    public init() {}

    public var body: some View {
        Image(systemName: DesignSystem.Icons.errorCircle)
            .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
    }
}

// MARK: - 来源 Badge 胶囊

/// 来源 Badge 胶囊组件，消除多处重复的 Label + font + padding + Capsule 修饰符链
public struct SourceBadge: View {
    let label: String
    let icon: String
    let color: Color

    public init(label: String, icon: String, color: Color) {
        self.label = label
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.bold))
            .padding(.horizontal, DesignSystem.medium)
            .padding(.vertical, DesignSystem.tightPadding)
            .background(Capsule().fill(color.opacity(DesignSystem.Opacity.subtle)))
            .foregroundStyle(color)
    }
}
