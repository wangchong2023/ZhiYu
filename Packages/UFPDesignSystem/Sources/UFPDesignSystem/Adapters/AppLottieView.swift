//
//  AppLottieView.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] SPM Package — 物理归位
//  核心职责：Lottie 动效播放适配器（Facade/Wrapper 模式）。
//           封装 Airbnb Lottie，上层只需 import UFPDesignSystem，
//           严禁上层直接 import Lottie。
//
//  架构原则：开源库 Lottie 只在此文件 import，通过 AppLottieView 对外暴露能力。
//

import SwiftUI

#if canImport(Lottie) && !os(watchOS)
import Lottie

/// 跨平台 Lottie 动效播放组件
/// 支持原生 fallback 退化策略：若找不到指定的 Lottie json/dotLottie 文件，
/// 将自动降级为原生 SwiftUI 的骨架屏动画或 ProgressView。
public struct AppLottieView: View {
    public let animationName: String
    public let loopMode: LottieLoopMode

    public init(
        name: String,
        loopMode: LottieLoopMode = .loop
    ) {
        self.animationName = name
        self.loopMode = loopMode
    }

    public var body: some View {
        if Bundle.main.url(forResource: animationName, withExtension: "json") != nil {
            // 使用 LottieView 原生 SwiftUI 支持 (lottie-ios 4.x)
            LottieView(animation: .named(animationName))
                .looping()
        } else {
            // 找不到 Lottie 资源时优雅降级为 ProgressView
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}
#else
/// watchOS 平台下 AppLottieView 退化实现
public struct AppLottieView: View {
    public init(name: String, loopMode: Int = 0) {}
    public init(name: String) {}

    public var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }
}
#endif
