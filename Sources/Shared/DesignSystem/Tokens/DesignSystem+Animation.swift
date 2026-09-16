//
//  DesignSystem+Animation.swift
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

extension DesignSystem {

    // MARK: - 13. 动效令牌 (Animation)
    public enum Animation {
        public static let springResponse: Double = Animations.Interaction.springResponse
        public static let springDamping: Double = Animations.Interaction.springDamping
        public static let pressScale: CGFloat = Animations.Interaction.pressScale
        public static let hoverScale: CGFloat = Animations.Interaction.hoverScale
        public static let standardDuration: Double = Animations.Interaction.standardDuration
        public static let looseDuration: Double = Animations.Interaction.looseDuration
        public static let fastDuration: Double = Animations.Interaction.fastDuration
        public static let slowDuration: Double = Animations.Interaction.slowDuration
        public static let standardDamping: Double = Animations.Interaction.standardDamping
        
        /// 标准交错动画延迟 (0.2s)
        public static let staggerDelay: Double = Animations.staggerDelay
        
        public static var standard: SwiftUI.Animation { Animations.Interaction.standardAnimation }
        public static var prominent: SwiftUI.Animation { Animations.Interaction.prominentAnimation }
        public static var fast: SwiftUI.Animation { Animations.Interaction.fastAnimation }
        
        /// 启动页动画序列 (Splash)
        public enum Splash {
            public static let quoteDelay: Double = Animations.Splash.quoteDelay
            public static let quoteFadeDuration: Double = Animations.Splash.quoteFadeDuration
            public static let authorDelay: Double = Animations.Splash.authorDelay
            public static let shimmerDelay: Double = Animations.Splash.shimmerDelay
            public static let welcomeDisplayDelay: Double = Animations.Splash.welcomeDisplayDelay
            public static let autoDismissDelay: Double = Animations.Splash.autoDismissDelay
        }
        
        /// AI 交互节奏
        public enum AI {
            public static let pulseInterval: Double = Animations.AI.pulseInterval
        }
        
        public struct Config {
            public static var prominentSpring: SwiftUI.Animation { Animations.Interaction.prominentAnimation }
        }
    }
}
