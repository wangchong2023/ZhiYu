//
//  Colors.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI
import Dependencies

#if canImport(UIKit)
import UIKit
import UFPCore
#endif

/// 智宇颜色令牌 (Color Tokens)
/// 包含全局语义颜色、透明度分级及环境色扩展。
public enum Colors {
    
    // MARK: - 1. 透明度令牌 (Opacity Tokens)
    
    /// 玻璃拟态透明度 (0.15)
    public static let glassOpacity: Double = 0.15
    /// 较淡的透明度 (0.7)
    public static let subtleOpacity: Double = 0.7
    /// 完全不透明度 (1.0)
    public static let fullOpacity: Double = 1.0
    /// 禁用状态透明度 (0.3)
    public static let disabledOpacity: Double = 0.3
    /// 按下状态透明度 (0.9)
    public static let pressedOpacity: Double = 0.9
    /// 暗淡/背景化状态透明度 (0.2)
    public static let dimmedOpacity: Double = 0.2
    /// 次要状态透明度 (0.8)
    public static let secondaryOpacity: Double = 0.8
    /// 中等透明度 (0.5)
    public static let halfOpacity: Double = 0.5
    /// 标准阴影透明度 (0.1)
    public static let shadowOpacity: Double = 0.1
    /// 功能引导背景透明度 (0.6)
    public static let coachMarkBackgroundOpacity: Double = 0.6
    
    /// 较浅的填充透明度 (0.1)，常用于标签背景
    public static let subtleFillOpacity: Double = 0.1
    
    /// 表面层透明度 (0.8)，常用于卡片叠加
    public static let surfaceOpacity: Double = 0.8
    /// 半透层透明度 (0.6)
    public static let translucentOpacity: Double = 0.6
    /// 软透层透明度 (0.4)
    public static let softOpacity: Double = 0.4
    /// 幽灵层透明度 (0.01)，用于交互热区
    public static let ghostOpacity: Double = 0.01
    
    /// 分割线透明度 (0.5)
    public static let dividerOpacity: Double = 0.5
    /// 强调描边透明度 (0.3)
    public static let accentStrokeOpacity: Double = 0.3
    /// 卡片背景基础透明度 (0.7)
    public static let cardOpacity: Double = 0.7
    
    // MARK: - 2. 预设容器颜色
    
    public struct Opacity {
        public static let glassOpacity: Double = Colors.glassOpacity
        public static let subtleOpacity: Double = Colors.subtleOpacity
        public static let fullOpacity: Double = Colors.fullOpacity
        public static let disabledOpacity: Double = Colors.disabledOpacity
        public static let pressedOpacity: Double = Colors.pressedOpacity
        public static let dimmedOpacity: Double = Colors.dimmedOpacity
        public static let secondaryOpacity: Double = Colors.secondaryOpacity
        public static let halfOpacity: Double = Colors.halfOpacity
        public static let shadowOpacity: Double = Colors.shadowOpacity
        public static let coachMarkBackgroundOpacity: Double = Colors.coachMarkBackgroundOpacity
        public static let subtleFillOpacity: Double = Colors.subtleFillOpacity
        
        public static let surfaceOpacity: Double = Colors.surfaceOpacity
        public static let translucentOpacity: Double = Colors.translucentOpacity
        public static let softOpacity: Double = Colors.softOpacity
        public static let ghostOpacity: Double = Colors.ghostOpacity
        public static let cardOpacity: Double = Colors.cardOpacity
        
        public static let dividerOpacity: Double = Colors.dividerOpacity
        public static let accentStrokeOpacity: Double = Colors.accentStrokeOpacity
        
        public static var shadowColor: Color { Colors.shadowColor }
        public static var glassShadowColor: Color { Color.black.opacity(DesignSystem.Opacity.ghost) }
        public static var deepShadowColor: Color { Color.black.opacity(DesignSystem.Opacity.subtle) }
    }
    
    /// 标准容器背景色
    public static var containerBackground: Color { Color.appCard }
    /// 标准容器边框色
    public static var containerBorder: Color { Color.appBorder }
    /// 标准阴影颜色
    public static var shadowColor: Color { Color.black.opacity(0.06) } // swiftlint:disable:this magic_numbers_opacity

    // MARK: - 3. 启动页 (Splash) 专有色彩令牌
    public enum Splash {
        public static let bgStep1 = Color(red: 0.04, green: 0.04, blue: 0.12)
        public static let bgStep2 = Color(red: 0.06, green: 0.08, blue: 0.22)
        public static let bgStep3 = Color(red: 0.08, green: 0.10, blue: 0.28)
        public static let bgStep4 = Color(red: 0.10, green: 0.12, blue: 0.30)
        public static let bgStep5 = Color(red: 0.12, green: 0.10, blue: 0.22)
        public static let bgStep6 = Color(red: 0.18, green: 0.12, blue: 0.15)
        public static let bgStep7 = Color(red: 0.25, green: 0.15, blue: 0.10)
        
        public static let glow1 = Color(red: 1.0, green: 0.85, blue: 0.5)
        public static let glow2 = Color(red: 0.9, green: 0.65, blue: 0.3)
        public static let glow3 = Color(red: 0.7, green: 0.4, blue: 0.2)
    }
}

/// 主题颜色解析器：通过 @Dependency 解析 ThemeManager，替代已删除的 ThemeManager.shared
private struct ThemeColorResolver {
    @Dependency(\.themeService) var theme
}

// MARK: - Color 扩展 (Semantic Colors)
extension Color {
    
#if canImport(UIKit) && !os(watchOS)
    public init(adaptLight: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(adaptLight)
        })
    }
#elseif canImport(AppKit)
    public init(adaptLight: Color, dark: Color) {
        self.init(NSColor { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(adaptLight)
        })
    }
#else
    public init(adaptLight: Color, dark: Color) {
        self.init(adaptLight)
    }
#endif
    
    // MARK: - 核心语义颜色
    // MARK: @LR-01: 适配全平台多语言环境下的视觉对比度
    // MARK: @PR-03: 语义化颜色规范，支持高性能亮暗模式切换
    
    public static var appBackground: Color { Color(adaptLight: Color(hex: "f5f5fa"), dark: Color(hex: "1a1b2e")) }
    public static var appCard: Color { Color(adaptLight: Color(hex: "ffffff"), dark: Color(hex: "252640")) }
    public static var appText: Color { Color(adaptLight: Color(hex: "1a1a2e"), dark: Color(hex: "e8e8f0")) }
    public static var appSecondary: Color { Color(adaptLight: Color(hex: "6b6b87"), dark: Color(hex: "ababc7")) }
    public static var appTertiary: Color { Color(adaptLight: Color(hex: "9e9eb3"), dark: Color(hex: "7a7a91")) }
    public static var appBorder: Color { Color(adaptLight: Color(hex: "ebebf2"), dark: Color(hex: "303142")) }
    
    /// 主题强调色 (通过 ThemeManager 获取，确保在主线程访问)
    public static var appAccent: Color {
        #if os(watchOS)
        return .blue // watchOS 暂不支持复杂的 ThemeManager 逻辑
        #else
        return runOnMainSync { ThemeColorResolver().theme.accentColor }
        #endif
    }
    
    /// 玻璃拟态高亮色/光泽色
    public static var appGloss: Color { Color(adaptLight: Color.white, dark: Color.white.opacity(DesignSystem.Opacity.dim)) }
    
    // MARK: - 知识分类语义颜色
    
    public static var appSource: Color { .blue }
    public static var appConcept: Color { .purple }
    public static var appEntity: Color { .orange }
    public static var appMap: Color { .indigo }
    public static var appComparison: Color { .teal }
    
    // MARK: - 功能性语义颜色
    
    /// 录音中/紧急警告色
    public static var appRecording: Color { .red }
    /// 一般性警告/提醒色
    public static var appAlert: Color { .orange }

    // MARK: - 十六进制初始化逻辑
    
    /// 十六进制颜色初始化 (支持 6 位或 8 位)
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        let mask: UInt64 = 0xFF
        let maxRGB: Double = 255.0
        
        let shift24: UInt64 = 24
        let shift16: UInt64 = 16
        let shift8: UInt64 = 8
        
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (UInt64(maxRGB), int >> shift16, int >> shift8 & mask, int & mask)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> shift24, int >> shift16 & mask, int >> shift8 & mask, int & mask)
        default:
            (a, r, g, b) = (UInt64(maxRGB), 0, 122, UInt64(maxRGB))
        }
        
        self.init(
            .sRGB,
            red: Double(r) / maxRGB,
            green: Double(g) / maxRGB,
            blue: Double(b) / maxRGB,
            opacity: Double(a) / maxRGB
        )
    }
}

// MARK: - ShapeStyle 扩展
extension ShapeStyle where Self == Color {
    public static var appAccent: Color { .appAccent }
    public static var appText: Color { .appText }
    public static var appSecondary: Color { .appSecondary }
    public static var appTertiary: Color { .appTertiary }
    public static var appBorder: Color { .appBorder }
    public static var appCard: Color { .appCard }
    public static var appBackground: Color { .appBackground }
    public static var appSource: Color { .appSource }
    public static var appConcept: Color { .appConcept }
    public static var appEntity: Color { .appEntity }
    public static var appMap: Color { .appMap }
    public static var appComparison: Color { .appComparison }
    public static var appGloss: Color { .appGloss }
    public static var appRecording: Color { .appRecording }
    public static var appAlert: Color { .appAlert }
}

// MARK: - Environment 扩展
public struct AppAccentColorKey: EnvironmentKey {
    public static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    /// 全局强调色环境变量
    public var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }
}

// MARK: - HIG Compliance Color.theme & UIColor.theme Extensions

extension Color {
    /// 全局人机交互指南 (HIG) 合规主题颜色映射网关
    public static let theme = ColorTheme()
}

/// 语义化颜色设计系统结构体
public struct ColorTheme: Sendable {
    /// 强调色
    public var accent: Color { .appAccent }
    /// 背景色
    public var background: Color { .appBackground }
    /// 卡片底色
    public var card: Color { .appCard }
    /// 正文字体颜色
    public var text: Color { .appText }
    /// 次要字体颜色
    public var secondaryText: Color { .appSecondary }
    /// 边框与分割线颜色
    public var border: Color { .appBorder }
    
    // MARK: - HIG 推荐的非硬编码语义适配颜色（亮/暗模式）
    
    /// 警告/警示（橙色）
    public var orange: Color { Color(adaptLight: Color(hex: "FF9500"), dark: Color(hex: "FF9F0A")) }
    /// 录音/错误/删除（红色）
    public var red: Color { Color(adaptLight: Color(hex: "FF3B30"), dark: Color(hex: "FF453A")) }
    /// 成功/完成/在线（绿色）
    public var green: Color { Color(adaptLight: Color(hex: "34C759"), dark: Color(hex: "30D158")) }
    /// 标签/特定逻辑（紫色）
    public var purple: Color { Color(adaptLight: Color(hex: "AF52DE"), dark: Color(hex: "BF5AF2")) }
    /// 链接/特定标识（蓝色）
    public var blue: Color { Color(adaptLight: Color(hex: "007AFF"), dark: Color(hex: "0A84FF")) }
    /// 阴影与基础色（黑色）
    public var black: Color { Color(adaptLight: Color(hex: "000000"), dark: Color(hex: "000000")) }
    /// 阴影与基础色（白色）
    public var white: Color { Color(adaptLight: Color(hex: "FFFFFF"), dark: Color(hex: "FFFFFF")) }
    /// 幽灵填充色/失效（灰色）
    public var gray: Color { Color(adaptLight: Color(hex: "8E8E93"), dark: Color(hex: "8E8E93")) }
    /// 测试/多用例特定颜色（青色）
    public var cyan: Color { Color.cyan }
    /// 比对/特定标识（青色/蓝绿色）
    public var teal: Color { Color(adaptLight: Color(hex: "30B0C7"), dark: Color(hex: "40C8E0")) }
    /// 词条/高亮（黄色）
    public var yellow: Color { Color(adaptLight: Color(hex: "FFCC00"), dark: Color(hex: "FFD60A")) }
    public var pink: Color { Color(adaptLight: Color(hex: "FF2D55"), dark: Color(hex: "FF375F")) }
    /// 靛蓝（Indigo）
    public var indigo: Color { Color(adaptLight: Color(hex: "5856D6"), dark: Color(hex: "5E5CE6")) }
    /// 薄荷绿（Mint）
    public var mint: Color { Color(adaptLight: Color(hex: "00C7BE"), dark: Color(hex: "66D4CF")) }
    /// 棕色（Brown）
    public var brown: Color { Color(adaptLight: Color(hex: "A2845E"), dark: Color(hex: "AC8E68")) }
}

#if canImport(UIKit)
extension UIColor {
    /// 全局人机交互指南 (HIG) 合规主题颜色映射网关 (UIColor 桥接)
    public static let theme = UIColorTheme()
}

/// 语义化 UI 颜色设计系统结构体 (UIColor 桥接)
public struct UIColorTheme: Sendable {
    /// 阴影与基础色（黑色）
    public var black: UIColor { UIColor(Color.theme.black) }
    /// 阴影与基础色（白色）
    public var white: UIColor { UIColor(Color.theme.white) }
    /// 成功/完成/在线（绿色）
    public var green: UIColor { UIColor(Color.theme.green) }
    /// 录音/错误/删除（红色）
    public var red: UIColor { UIColor(Color.theme.red) }
}

#endif
