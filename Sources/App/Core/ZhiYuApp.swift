//
//  ZhiYuApp.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：App 模块的 ZhiYuApp 实现。
//
import SwiftUI
import UFPCore
import UFPDesignSystem

struct ZhiYuApp: App {
    /// 状态持有：App 全局环境（负责所有后台服务的生命周期）
    @State private var appEnv = AppEnvironment.shared
    
    /// 状态持有：主题管理器
    @State private var themeManager: ThemeManager

    /// 状态持有：ZhiYuAppModel — 集中持有 21 个单例的 UI 可观察状态（P1 骨架，P2-P6 逐步填充）
    @State private var appModel = ZhiYuAppModel()

    /// 状态持有：DependencyContainer — 集中持有 21 个服务依赖（P1 骨架，P2-P6 逐步填充）
    @State private var dependencies = DependencyContainer()
    
    /// 状态持有：闪屏页可见性
    /// 已登录或非首次冷启动时直接跳过闪屏
    @State private var hasSeenSplash: Bool
    
    /// 引导状态持有
    @StateObject private var onboardingService = OnboardingService()
    
    init() {
        // 从 DI 解析 KeyStore，创建 ThemeManager 实例
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) // inject_exempt: App 入口 DI 初始化
        self._themeManager = State(initialValue: ThemeManager(keyStore: keyStore))

        let hasSeenSplashBefore = SplashPresentationPolicy.hasSeenSplashBefore(keyStore: keyStore)
        let isUserLoggedIn = AuthSession.shared.isLoggedIn
        let shouldSkip = SplashPresentationPolicy.shouldSkipSplash(
            hasSeenSplashBefore: hasSeenSplashBefore,
            isLoggedIn: isUserLoggedIn
        )
        self._hasSeenSplash = State(initialValue: shouldSkip)
    }
    
    var body: some Scene {
        // 场景分发：平台差异收敛于 AppSceneBuilder，环境注入收敛于 SceneEnvironmentInjection
        AppSceneBuilder.root(
            appEnv: appEnv, appModel: appModel, dependencies: dependencies,
            themeManager: themeManager, onboardingService: onboardingService,
            hasSeenSplash: hasSeenSplash
        )
    }
}
