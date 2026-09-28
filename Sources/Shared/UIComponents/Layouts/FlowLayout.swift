//
//  FlowLayout.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

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
