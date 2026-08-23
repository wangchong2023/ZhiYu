//
//  DesignSystem+Stroke.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：描边宽度、字间距等可视化常量。
//
import SwiftUI
import CoreGraphics

extension DesignSystem {

    // MARK: - 22. 描边与字间距令牌 (Stroke & Tracking)

    /// 描边宽度令牌，统一管理 `lineWidth` / `strokeWidth` 等描边参数。
    public enum Stroke {
        /// 极细描边 (0.5px) — 用于细微装饰线条
        public static let hairline: CGFloat = 0.5
        /// 细描边 (0.8px) — 标准边框宽度（与 `DesignSystem.borderWidth` 对齐）
        public static let thin: CGFloat = Spacing.borderWidth
        /// 标准描边 (1px) — 用于分隔线、卡片描边
        public static let standard: CGFloat = 1
        /// 中等描边 (1.5px) — 用于强调描边
        public static let medium: CGFloat = 1.5
        /// 加粗描边 (2px) — 用于选中态描边
        public static let bold: CGFloat = 2
        /// 强调描边 (3px) — 用于重点高亮描边（与 `Spacing.Decorator.accentLineWidth` 对齐）
        public static let accent: CGFloat = Spacing.Decorator.accentLineWidth
        /// 进度环描边 (10px) — 用于环形进度指示器
        public static let progressRing: CGFloat = 10
    }

    /// 字间距令牌，统一管理 `kerning` / `tracking` 参数。
    public enum Tracking {
        /// 标准字间距 (0px) — 默认字间距
        public static let standard: CGFloat = 0
        /// 紧凑字间距 (1px) — 用于标题微调
        public static let tight: CGFloat = 1
        /// 宽松字间距 (2px) — 用于装饰性标题
        public static let loose: CGFloat = 2
    }
}
