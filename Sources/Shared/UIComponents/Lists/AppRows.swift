//
//  AppRows.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - App Section Header

/// 统一的章节标题组件
/// 支持左侧图标、标题文本及右侧自定义工具栏。
public struct AppSectionHeader: View {
    public let title: String
    public var icon: String?
    public var iconColor: Color = .appSource
    public var trailing: AnyView?

    public init(title: String, icon: String? = nil, iconColor: Color = .appSource, trailing: AnyView? = nil) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = trailing
    }

    public var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.appText)
            Spacer()
            if let trailing = trailing {
                trailing
            }
        }
    }
}

// MARK: - App Labeled Row

/// 带标签和值的行
/// 常用于设置页面、属性展示或信息摘要。
public struct AppLabeledRow: View {
    public let label: String
    public let value: String
    public var valueColor: Color = .appText

    public init(label: String, value: String, valueColor: Color = .appText) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - App Step Row

/// 带数字序号的步骤行
/// 提供视觉强调的圆形序号标识。
public struct AppStepRow: View {
    public let number: Int
    public let text: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(number: Int, text: String) {
        self.number = number
        self.text = text
    }

    /// 根据屏幕尺寸类自动适配字号
    private var stepFont: Font {
        horizontalSizeClass == .regular ? Typography.secondaryFont : Typography.captionFont
    }

    public var body: some View {
        HStack(spacing: Spacing.medium - Spacing.atomic) { // 10
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: Spacing.smallIconSize + Spacing.atomic * 2, height: Spacing.smallIconSize + Spacing.atomic * 2) // 22
                .background(Circle().fill(Color.appAccent))

            Text(text)
                .font(stepFont)
                .foregroundStyle(.appText)
        }
    }
}

// MARK: - App Divider

/// 带标题和图标的分隔线
/// 用于视觉层级的横向切割与引导。
public struct AppDivider: View {
    public var icon: String?
    public var title: String?
    public var color: Color = .appBorder

    public init(icon: String? = nil, title: String? = nil, color: Color = .appBorder) {
        self.icon = icon
        self.title = title
        self.color = color
    }

    public var body: some View {
        HStack(spacing: Spacing.medium) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
            if let title = title {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appSecondary)
            }
            Rectangle()
                .fill(color)
                .frame(height: DesignSystem.Metrics.dividerThickness)
        }
    }
}

// MARK: - App Accent Line

/// 垂直强调线
/// 用于引导视觉焦点，通常放在卡片或列表项的侧边。
public struct AppAccentLine: View {
    public var color: Color = .appAccent
    public var width: CGFloat = Spacing.Decorator.accentLineWidth

    public init(color: Color = .appAccent, width: CGFloat = Spacing.Decorator.accentLineWidth) {
        self.color = color
        self.width = width
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.tiny))
    }
}

// MARK: - App Icon Box

/// 圆角图标容器
/// 为图标提供带半透明背景的容器，增加视觉丰富度。
public struct AppIconBox: View {
    public let icon: String
    public var color: Color = .appAccent
    public var size: CGFloat = Spacing.Gallery.iconSize

    public init(icon: String, color: Color = .appAccent, size: CGFloat = Spacing.Gallery.iconSize) {
        self.icon = icon
        self.color = color
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Spacing.small)
                .fill(color.opacity(DesignSystem.Opacity.subtle))

            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
