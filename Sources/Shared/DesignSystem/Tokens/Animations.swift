//
//  Animations.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI

/// 智宇设计系统原子动效令牌 (Animation Tokens)
/// 
/// 本类型集中管理全局所有物理交互参数、弹簧系数及时间基准。
/// 严格遵循 iOS 高端物理仿真动效规范，支持平滑、轻盈的空间连续性过渡。
public enum Animations {
    
    // MARK: - 1. 物理交互参数 (Physical Interaction)
    // MARK: @PR-03: 交互动效参数经过优化以维持高帧率交互
    
    /// 点击按下的缩放比例 (0.97)
    public static let pressScale: CGFloat = 0.97
    /// 悬停时的缩放比例 (1.02)
    public static let hoverScale: CGFloat = 1.02
    
    // MARK: - 2. 动画时长 (Durations)
    
    /// 标准线性动画时长 (0.2s)
    public static let standardDuration: Double = 0.2
    /// 快速动画时长 (0.2s)
    public static let fastDuration: Double = 0.2
    /// 慢速动画时长 (0.5s)
    public static let slowDuration: Double = 0.5
    /// 宽松动画时长 (1.5s)
    public static let looseDuration: Double = 1.5
    
    // MARK: - 3. 弹性动效参数 (Spring Parameters)
    
    /// 标准弹性动效响应时长 (0.3s)
    public static let springResponse: Double = 0.3
    /// 标准弹性动效阻尼系数 (0.8)
    public static let springDamping: Double = 0.8
    
    /// 突出弹性动效响应时长 (0.4s)
    public static let prominentSpringResponse: Double = 0.4
    
    /// 突出弹性动效阻尼系数 (0.58)
    /// 
    /// - Note: 经由 Task 2 微动效交互革新，该值从原先稳重的临界阻尼 0.8 调整为 **0.58**。
    /// 0.58 属于精心调优的**欠阻尼 (Underdamped)** 物理状态，能够为大盘笔记本切库、全局 Tab 视图大切换等
    /// 跨度较大的界面连续运动，赋予极为生动、自然、且伴随轻微视觉物理回弹的高端苹果风交互体验。
    public static let prominentSpringDamping: Double = 0.58
    
    // MARK: - 4. 装饰动效令牌 (Decorator Animation Tokens)
    
    /// 闪烁动画循环时长 (1.5s)
    public static let shimmerDuration: Double = 1.5
    /// 脉冲动效循环时长 (1.2s)
    public static let pulseDuration: Double = 1.2
    /// 脉冲动效缩放倍率 (1.4)
    public static let pulseScale: CGFloat = 1.4
    
    /// 闪烁动画相位偏移
    public static let shimmerPhaseShift: CGFloat = 400
    /// 闪烁光带宽度比例
    public static let shimmerWidthRatio: CGFloat = 0.6
    /// 闪烁动画终止比例
    public static let shimmerEndRatio: CGFloat = 1.6
    /// 中型发光缩放倍率
    public static let glowScaleMedium: CGFloat = 1.3
    /// 巨大发光缩放倍率
    public static let glowScaleLarge: CGFloat = 1.8
    
    /// 标准交错动画延迟 (0.2s)
    public static let staggerDelay: Double = 0.2

    // MARK: - 5. 业务场景动效 (Business Scene Animations)

    /// 启动页动画序列令牌
    public enum Splash {
        /// 名言淡入延迟 (standardDuration * 3)
        public static let quoteDelay: Double = standardDuration * 3
        /// 署名与按钮淡入延迟 (slowDuration + standardDuration * 4.5)
        public static let authorDelay: Double = slowDuration + standardDuration * 4.5
        /// 闪光扫过延迟 (slowDuration + standardDuration * 6.5)
        public static let shimmerDelay: Double = slowDuration + standardDuration * 6.5
        /// 启动延迟 (2.5s)
        public static let welcomeDisplayDelay: Double = 2.5
        /// 自动进入延迟 (5.0s)
        public static let autoDismissDelay: Double = 5.0
    }
    
    /// AI 交互节奏
    public enum AI {
        /// 思考脉搏周期 (1.5s)
        public static let pulseInterval: Double = 1.5
    }

    public struct Interaction {
        public static let pressScale: CGFloat = Animations.pressScale
        public static let hoverScale: CGFloat = Animations.hoverScale
        public static let springResponse: Double = Animations.springResponse
        public static let springDamping: Double = Animations.springDamping
        public static let standardDuration: Double = Animations.standardDuration
        public static let fastDuration: Double = Animations.fastDuration
        public static let slowDuration: Double = Animations.slowDuration
        public static let looseDuration: Double = Animations.looseDuration
        public static let standardDamping: Double = 0.8
        public static let standardAnimation: Animation = .appStandard
        public static let prominentAnimation: Animation = .appProminent
        public static let fastAnimation: Animation = .appFast
    }
    
    public struct Decorator {
        public static let shimmerDuration: Double = Animations.shimmerDuration
        public static let pulseDuration: Double = Animations.pulseDuration
        public static let pulseScale: CGFloat = Animations.pulseScale
        public static let shimmerPhaseShift: CGFloat = Animations.shimmerPhaseShift
        public static let shimmerWidthRatio: CGFloat = Animations.shimmerWidthRatio
        public static let shimmerEndRatio: CGFloat = Animations.shimmerEndRatio
        public static let glowScaleMedium: CGFloat = Animations.glowScaleMedium
        public static let glowScaleLarge: CGFloat = Animations.glowScaleLarge
    }
}

// MARK: - SwiftUI Animation 扩展
extension Animation {
    
    /// 标准弹性动画 (智宇推荐)
    public static var appStandard: Animation {
        .spring(
            response: Animations.springResponse,
            dampingFraction: Animations.springDamping
        )
    }
    
    /// 突出弹性动画
    public static var appProminent: Animation {
        .spring(
            response: Animations.prominentSpringResponse,
            dampingFraction: Animations.prominentSpringDamping
        )
    }
    
    /// 快速淡出动画
    public static var appFast: Animation {
        .easeOut(duration: Animations.fastDuration)
    }
    
    /// 缓慢平滑动画
    public static var appSlow: Animation {
        .easeInOut(duration: Animations.slowDuration)
    }
    
    // 遗留兼容支持
    public static var standardAnimation: Animation { appStandard }
    public static var fastAnimation: Animation { appFast }
}
