//
//  Layouts.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] SPM Package — 物理归位
//  核心职责：通用布局容器组件集 —— 自动换行流式布局、标准分组区块、带动画展开区块。
//           沉淀自 ZhiYu App 层 Shared/UIComponents，供包内组件与上层共享。
//

import SwiftUI

// MARK: - Flow Layout

/// 自动换行布局容器
/// 适用于标签云、芯片列表及令牌输入框等需要动态排列的场景。
public struct FlowLayout: Layout {
    // MARK: - Properties

    /// 元素间的间距
    public var spacing: CGFloat = DesignTokens.Spacing.small

    // MARK: - Initialization

    public init(spacing: CGFloat = DesignTokens.Spacing.small) {
        self.spacing = spacing
    }

    // MARK: - Layout Implementation

    /// sizeThatFits
    /// - Parameter proposal: proposal
    /// - Parameter subviews: subviews
    /// - Parameter cache: 缓存
    /// - Returns: 返回值
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    /// placeSubviews
    /// - Parameter proposal: proposal
    /// - Parameter subviews: subviews
    /// - Parameter cache: 缓存
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    // MARK: - Private Methods

    /// 计算子视图的排列位置
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // 检查是否需要换行
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + rowHeight), positions)
    }
}

// MARK: - Standard Section

/// 标准卡片容器组件
/// 提供带标题和脚注的分组视图，内部内容自动应用玻璃拟态背景。
public struct StandardSection<Content: View>: View {
    // MARK: - Properties

    /// 顶部显示的标题文本
    public let title: String?
    /// 底部显示的辅助说明文本
    public let footer: String?
    /// 内容区域的视图闭包
    public let content: Content

    // MARK: - Initialization

    /// 初始化标准分段组件
    /// - Parameters:
    ///   - title: 可选标题
    ///   - footer: 可选脚注
    ///   - content: 视图内容
    public init(title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // 渲染标题
            if let title = title {
                Group {
                    Text(title)
                }
                .font(DesignTokens.Typography.captionFont)
                .foregroundStyle(.appSecondary)
                .padding(.leading, DesignTokens.Spacing.medium)
                .textCase(.uppercase)
            }

            // 渲染内容区域（带玻璃拟态背景）
            VStack(spacing: 0) {
                content
            }
            .appGlassCardStyle(opacity: DesignTokens.SystemOpacity.active, cornerRadius: DesignTokens.Spacing.cardRadius)

            // 渲染脚注
            if let footer = footer {
                Group {
                    Text(footer)
                }
                .font(DesignTokens.Typography.caption2Font)
                .foregroundStyle(.appSecondary)
                .padding(.horizontal, DesignTokens.Spacing.medium)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.standardPadding)
        .padding(.vertical, DesignTokens.Spacing.small)
    }
}

// MARK: - View 扩展

public extension View {
    /// 应用列表行样式
    /// 为视图添加标准的内边距和可选的底部分割线，通常用于 StandardSection 内部。
    /// - Parameter showDivider: 是否显示底部分割线
    /// - Returns: 包装后的视图
    func appListRowStyle(showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            self
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.vertical, DesignTokens.Spacing.medium)
                .contentShape(Rectangle()) // 确保整行可点击

            if showDivider {
                Divider()
                    .padding(.leading, DesignTokens.Spacing.medium)
                    .opacity(DesignTokens.Colors.Opacity.dividerOpacity)
            }
        }
    }
}

// MARK: - Animated Section

/// 带动画的展开/收起区块容器
/// 当状态发生变化时，自动应用平滑的转场动画。
public struct AnimatedSection<Content: View>: View {
    // MARK: - Properties

    /// 是否展开
    public let isExpanded: Bool
    /// 内容闭包
    @ViewBuilder public let content: () -> Content

    // MARK: - Initialization

    public init(isExpanded: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.isExpanded = isExpanded
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        if isExpanded {
            content()
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}