//
//  DesignSystem+Layering.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：遵循 W3C DTCG 标准实现 3 级 Token 分层架构 (Tier 1 Global -> Tier 2 Semantic -> Tier 3 Component)
//

import SwiftUI

extension DesignSystem {
    
    // MARK: - ==========================================
    // MARK: Tier 1: Global / Reference Tokens (全局物理常量)
    // MARK: - ==========================================
    public enum Tier1 {
        
        /// Tier 1 物理色彩基准标尺 (Color Palette Options)
        public enum Color {
            public static let blue500 = SwiftUI.Color(red: 0.12, green: 0.53, blue: 0.95)
            public static let blue600 = SwiftUI.Color(red: 0.08, green: 0.44, blue: 0.85)
            public static let slate100 = SwiftUI.Color(red: 0.95, green: 0.96, blue: 0.98)
            public static let slate800 = SwiftUI.Color(red: 0.11, green: 0.14, blue: 0.19)
            public static let emerald500 = SwiftUI.Color(red: 0.06, green: 0.73, blue: 0.48)
            public static let rose500 = SwiftUI.Color(red: 0.95, green: 0.25, blue: 0.35)
            public static let amber500 = SwiftUI.Color(red: 0.96, green: 0.62, blue: 0.07)
        }
        
        /// Tier 1 物理间距基准标尺 (Spacing Scale Options)
        public enum Spacing {
            public static let space2: CGFloat = 2
            public static let space4: CGFloat = 4
            public static let space8: CGFloat = 8
            public static let space12: CGFloat = 12
            public static let space16: CGFloat = 16
            public static let space20: CGFloat = 20
            public static let space24: CGFloat = 24
            public static let space32: CGFloat = 32
            public static let space40: CGFloat = 40
            public static let space48: CGFloat = 48
            public static let space64: CGFloat = 64
        }
        
        /// Tier 1 物理圆角基准标尺 (Radius Scale Options)
        public enum Radius {
            public static let r4: CGFloat = 4
            public static let r8: CGFloat = 8
            public static let r12: CGFloat = 12
            public static let r16: CGFloat = 16
            public static let r24: CGFloat = 24
            public static let rCapsule: CGFloat = 999
        }
    }

    // MARK: - ==========================================
    // MARK: Tier 2: Alias / Semantic Tokens (语义化别名 Token)
    // MARK: - ==========================================
    public enum Tier2 {
        
        /// Tier 2 语义化颜色
        public enum Color {
            public static var brandAccent: SwiftUI.Color { Tier1.Color.blue500 }
            public static var success: SwiftUI.Color { Tier1.Color.emerald500 }
            public static var warning: SwiftUI.Color { Tier1.Color.amber500 }
            public static var error: SwiftUI.Color { Tier1.Color.rose500 }
        }
        
        /// Tier 2 语义化间距
        public enum Spacing {
            public static var atomic: CGFloat { Tier1.Spacing.space2 }
            public static var tight: CGFloat { Tier1.Spacing.space4 }
            public static var compact: CGFloat { Tier1.Spacing.space8 }
            public static var standard: CGFloat { Tier1.Spacing.space16 }
            public static var cardPadding: CGFloat { Tier1.Spacing.space16 }
            public static var sectionPadding: CGFloat { Tier1.Spacing.space24 }
            public static var screenMargin: CGFloat { Tier1.Spacing.space32 }
        }
        
        /// Tier 2 语义化圆角
        public enum Radius {
            public static var small: CGFloat { Tier1.Radius.r4 }
            public static var medium: CGFloat { Tier1.Radius.r8 }
            public static var large: CGFloat { Tier1.Radius.r16 }
            public static var card: CGFloat { Tier1.Radius.r16 }
            public static var capsule: CGFloat { Tier1.Radius.rCapsule }
        }
    }

    // MARK: - ==========================================
    // MARK: Tier 3: Component / Contextual Tokens (组件/平台上下文 Token)
    // MARK: - ==========================================
    public enum Tier3 {
        
        /// 侧边栏组件 Token
        public enum Sidebar {
            public static var rowSpacing: CGFloat { Tier2.Spacing.compact }
            public static var rowRadius: CGFloat { Tier2.Radius.medium }
            public static var backButtonWidth: CGFloat { Tier1.Spacing.space40 }
            public static var widthPhone: CGFloat { 280 }
            public static var widthMac: CGFloat { 240 }
        }
        
        /// 桌面/锁屏小组件 Token
        public enum Widget {
            public static var cardPaddingPhone: CGFloat { Tier2.Spacing.cardPadding }
            public static var cardPaddingWatch: CGFloat { Tier1.Spacing.space8 }
            public static var iconSizePhone: CGFloat { Tier1.Spacing.space24 }
            public static var iconSizeWatch: CGFloat { Tier1.Spacing.space16 }
        }
        
        /// 交互操作 Token
        public enum Action {
            public static var minTouchTargetTouch: CGFloat { Tier1.Spacing.space40 + Tier1.Spacing.space4 } // 44pt
            public static var minTouchTargetPointer: CGFloat { Tier1.Spacing.space24 + Tier1.Spacing.space4 } // 28pt
            public static var buttonHeight: CGFloat { Tier1.Spacing.space40 + Tier1.Spacing.space4 }
        }
    }
}
