//
//  VaultTheme.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义笔记本主题 (VaultTheme) 的领域模型，包含主题配色、字体与样式配置。
//
import Foundation

/// 笔记本视觉主题模型
/// 决定具体笔记本在 UI 列表、导航栏与渐变背景上的展现形式。
public struct VaultTheme: Codable, Equatable, Sendable {
    /// 唯一识别的样式配置 ID
    public var id: String
    /// 主题的名称（如“极地之光”、“落日余晖”）
    public var name: String
    /// 主题类型（如线性渐变、径向渐变或网格效果）
    public var style: String
    /// 主题关联的颜色十六进制数组
    public var primaryColors: [String]
    /// 文字或高亮部分的点缀色十六进制
    public var accentColor: String
    
    /// 初始化笔记本主题
    /// - Parameters:
    ///   - id: 样式唯一标识
    ///   - name: 主题名称
    ///   - style: 渲染样式类型
    ///   - primaryColors: 主色调渐变数组
    ///   - accentColor: 点缀色
    public init(id: String, name: String, style: String = "linear", primaryColors: [String], accentColor: String) {
        self.id = id
        self.name = name
        self.style = style
        self.primaryColors = primaryColors
        self.accentColor = accentColor
    }
}

// MARK: - 预设主题列表
extension VaultTheme {
    /// 默认浅蓝色极简主题
    public static let standard = VaultTheme(
        id: "default_blue",
        name: L10n.Shared.themeStandard,
        style: "linear",
        primaryColors: ["#007AFF", "#5AC8FA"],
        accentColor: "#007AFF"
    )
    
    /// 充满活力的落日橙红主题
    public static let sunset = VaultTheme(
        id: "sunset_glow",
        name: L10n.Shared.themeSunset,
        style: "linear",
        primaryColors: ["#FF9500", "#FF2D55"],
        accentColor: "#FF2D55"
    )
    
    /// 深邃魔幻的霓虹深紫主题
    public static let neonPurple = VaultTheme(
        id: "neon_purple",
        name: L10n.Shared.themeNeonPurple,
        style: "mesh",
        primaryColors: ["#5856D6", "#AF52DE"],
        accentColor: "#AF52DE"
    )
}
