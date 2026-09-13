//
//  SidebarNavigationHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：提供侧边栏与顶层自适应布局的数据转换、角标格式化、颜色解析与标题兜底保护。
//

import SwiftUI
import UFPCore

/// 侧边栏与自适应导航辅助类
public enum SidebarNavigationHelper {
    
    /// 格式化侧边栏角标（通知数/未读数）
    /// - Parameter count: 角标原始数值
    /// - Returns: 当 count <= 0 时返回 nil；当 count > 99 时返回 "99+"；其余返回字符表示
    public static func formatBadgeCount(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        if count > AppConstants.Formatting.badgeMax {
            return AppConstants.Formatting.badgeOverflowText
        }
        return "\(count)"
    }
    
    /// 格式化分类条目数量文本（支持上限截断）
    /// - Parameter count: 原始数量
    /// - Returns: 格式化后的字符串
    public static func formatCountText(_ count: Int) -> String {
        guard count > 0 else { return "0" }
        if count > AppConstants.Formatting.badgeMax {
            return AppConstants.Formatting.badgeOverflowText
        }
        return "\(count)"
    }
    
    /// 解析知识宇宙/分类导航行图标色彩
    /// - Parameter colorName: 颜色名称字符串（若为 "accent" 则使用系统强调色）
    /// - Returns: SwiftUI Color
    public static func resolveIconColor(colorName: String) -> Color {
        if colorName == "accent" {
            return .appAccent
        }
        return Color.fromModelColorName(colorName)
    }
    
    /// 解析知识页面在侧边栏的展示标题，防止空标题或纯空格造成视觉空白
    /// - Parameter title: 页面原始标题
    /// - Returns: 修剪后的有效标题，若为空则返回默认兜底标题
    public static func resolvePageTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.Knowledge.Page.title : trimmed
    }
    
    /// 判断是否属于紧凑型屏幕模式（手机等）
    /// - Parameter screenClass: 屏幕类别
    /// - Returns: 是否为紧凑布局
    public static func isCompactScreen(_ screenClass: ScreenClass) -> Bool {
        screenClass == .compact
    }
}
