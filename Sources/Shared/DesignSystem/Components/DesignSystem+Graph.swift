//
//  DesignSystem+Graph.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI
import CoreGraphics
import UFPDesignSystem

extension DesignSystem {

    // MARK: - 9. 图谱模式 (Graph)
    public enum Graph {
        public static let nodeSize: CGFloat = DesignTokens.Spacing.Graph.nodeSize
        public static let selectedNodeSize: CGFloat = DesignTokens.Spacing.Graph.selectedNodeSize
        public static let nodeSizeReference: CGFloat = DesignTokens.Spacing.Graph.nodeSizeReference
        public static let centralNodeSize: CGFloat = DesignTokens.Spacing.Graph.centralNodeSize
        public static let linkWidth: CGFloat = DesignTokens.Spacing.Graph.linkWidth
        public static let forceStrength: CGFloat = DesignTokens.Spacing.Graph.forceStrength
        public static let minScale: CGFloat = DesignTokens.Spacing.Graph.minScale
        public static let maxScale: CGFloat = DesignTokens.Spacing.Graph.maxScale
        public static let tightPadding: CGFloat = DesignTokens.Spacing.Graph.tightPadding
        public static let toolbarPaddingTrailing: CGFloat = DesignTokens.Spacing.Graph.toolbarPaddingTrailing
        public static let toolbarPaddingBottomExpanded: CGFloat = DesignTokens.Spacing.Graph.toolbarPaddingBottomExpanded
        public static let toolbarPaddingBottomDefault: CGFloat = DesignTokens.Spacing.Graph.toolbarPaddingBottomDefault
        public static let layoutPadding: CGFloat = DesignTokens.Spacing.Graph.layoutPadding
        public static let minLayoutDimension: CGFloat = DesignTokens.Spacing.Graph.minLayoutDimension
        public static let highlightedLineWidth: CGFloat = DesignTokens.Spacing.Graph.highlightedLineWidth
        public static let emptyIconSize: CGFloat = DesignTokens.Spacing.Graph.emptyIconSize
        
        public enum ThreeD {
            public static let baseNodeSize: CGFloat = DesignTokens.Spacing.Graph.ThreeD.baseNodeSize
            public static let minNodeSize: CGFloat = DesignTokens.Spacing.Graph.ThreeD.minNodeSize
            public static let maxNodeSize: CGFloat = DesignTokens.Spacing.Graph.ThreeD.maxNodeSize
            public static let nodeLinkWeight: Double = DesignTokens.Spacing.Graph.ThreeD.nodeLinkWeight
            public static let labelOffset: Float = DesignTokens.Spacing.Graph.ThreeD.labelOffset
            public static let labelScale: Float = DesignTokens.Spacing.Graph.ThreeD.labelScale
            public static let edgeRadius: CGFloat = DesignTokens.Spacing.Graph.ThreeD.edgeRadius
            public static let edgeRadiusHighlighted: CGFloat = DesignTokens.Spacing.Graph.ThreeD.edgeRadiusHighlighted
            public static let starRadius: CGFloat = DesignTokens.Spacing.Graph.ThreeD.starRadius
            public static let starFieldRadius: Float = DesignTokens.Spacing.Graph.ThreeD.starFieldRadius
        }
    }
}
