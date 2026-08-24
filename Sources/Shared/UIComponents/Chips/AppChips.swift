//
//  AppChips.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - App Chip

/// 胶囊形标签
/// 常用于显示页面类型、分类或简单的状态标识。
public struct AppChip: View {
    public let text: String
    public var color: Color = .appAccent
    public var backgroundOpacity: Double = Colors.glassOpacity
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(text: String, color: Color = .appAccent, backgroundOpacity: Double = Colors.glassOpacity) {
        self.text = text
        self.color = color
        self.backgroundOpacity = backgroundOpacity
    }

    /// 根据屏幕尺寸类自动适配字号
    private var chipFont: Font {
        horizontalSizeClass == .regular ? Typography.captionFont : Typography.caption2Font
    }

    public var body: some View {
        Text(text)
            .font(chipFont)
            .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
            .padding(.vertical, DesignSystem.Chip.verticalPadding)
            .background(color.opacity(backgroundOpacity))
            .clipShape(Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - App Icon Chip

/// 带图标的胶囊标签
/// 常用于侧边栏选择项、工具栏按钮或具有语义化图标的分类。
public struct AppIconChip: View {
    public let icon: String
    public let text: String
    public var color: Color = .appAccent
    public var isSelected: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(icon: String, text: String, color: Color = .appAccent, isSelected: Bool = false) {
        self.icon = icon
        self.text = text
        self.color = color
        self.isSelected = isSelected
    }

    /// 根据屏幕尺寸类自动适配字号
    private var chipFont: Font {
        horizontalSizeClass == .regular ? Typography.secondaryFont : Typography.captionFont
    }

    public var body: some View {
        HStack(spacing: Spacing.tiny + Spacing.atomic) { // 6
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(chipFont)
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, DesignSystem.small)
        .background(isSelected ? color.opacity(SystemOpacity.glassStrong) : Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
        .foregroundStyle(isSelected ? color : .appSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.smallRadius)
                .stroke(isSelected ? color.opacity(Colors.disabledOpacity) : Color.clear, lineWidth: Spacing.borderWidth)
        )
    }
}

// MARK: - App Badge

/// 信息徽章
/// 用于显示未读计数、等级或小型状态标记。
public struct AppBadge: View {
    public let text: String
    public var color: Color = .appAccent
    public var isPill: Bool = true

    public init(text: String, color: Color = .appAccent, isPill: Bool = true) {
        self.text = text
        self.color = color
        self.isPill = isPill
    }

    public var body: some View {
        Group {
            if isPill {
                Text(text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, text.count > 1 ? DesignSystem.Chip.horizontalPadding : DesignSystem.Chip.verticalPadding)
                    .padding(.vertical, DesignSystem.Chip.verticalPadding)
                    .background(color)
                    .clipShape(Capsule())
            } else {
                Text(text)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: Spacing.Decorator.badgeMinSize, height: Spacing.Decorator.badgeMinSize)
                    .background(color)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - App Scrollable Chips

/// 水平滚动的标签列表容器
/// 适用于过滤项选择或长列表的分类展示。
public struct AppScrollableChips<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    public let items: Data
    public let selectedItem: Data.Element?
    public let onSelect: (Data.Element) -> Void
    public var colorProvider: (Data.Element) -> Color = { _ in .appAccent }
    @ViewBuilder public let chipContent: (Data.Element) -> Content

    public init(
        items: Data,
        selectedItem: Data.Element?,
        onSelect: @escaping (Data.Element) -> Void,
        colorProvider: @escaping (Data.Element) -> Color = { _ in .appAccent },
        @ViewBuilder chipContent: @escaping (Data.Element) -> Content
    ) {
        self.items = items
        self.selectedItem = selectedItem
        self.onSelect = onSelect
        self.colorProvider = colorProvider
        self.chipContent = chipContent
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small) {
                ForEach(Array(items), id: \.self) { item in
                    Button(action: { onSelect(item) }) {
                        chipContent(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
