//
//  iOSSceneBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：iOS/watchOS 场景根，对齐现有 ZhiYuApp.body 的 WindowGroup（含闪屏 ZStack + SplashView + onChange + preferredColorScheme + tint + animation + appToast）。
//
import SwiftUI
import UFPCore
import UFPDesignSystem

/// iOS/watchOS 场景构建器
@MainActor
enum iOSSceneBuilder {
    /// 主窗口：承载原 ZhiYuApp.body 中 WindowGroup 内全部内容
    @SceneBuilder
    static func main(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService,
        hasSeenSplash: Bool
    ) -> some Scene {
        WindowGroup {
            iOSRootView(
                appEnv: appEnv, appModel: appModel, dependencies: dependencies,
                themeManager: themeManager, onboardingService: onboardingService,
                initialHasSeenSplash: hasSeenSplash
            )
        }
    }
}

/// [L3] iOS 根视图：承载原 body 中 WindowGroup 内的全部内容（闪屏 ZStack + SplashView + onChange + 颜色/主题 + appToast）
/// 核心职责：在场景根完成闪屏呈现与全局主题/浮层包装，注入链交由 SceneEnvironmentInjection 抽取。
@MainActor
private struct iOSRootView: View {
    let appEnv: AppEnvironment
    let appModel: ZhiYuAppModel
    let dependencies: DependencyContainer
    let themeManager: ThemeManager
    let onboardingService: OnboardingService

    /// 闪屏可见性：由 ZhiYuApp 启动策略计算出的初始值迁移而来，此后在视图内部自闭环管理
    @State private var hasSeenSplash: Bool

    init(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService,
        initialHasSeenSplash: Bool
    ) {
        self.appEnv = appEnv
        self.appModel = appModel
        self.dependencies = dependencies
        self.themeManager = themeManager
        self.onboardingService = onboardingService
        self._hasSeenSplash = State(initialValue: initialHasSeenSplash)
    }

    var body: some View {
        ZStack {
            // 主内容视图：注入所有必需的环境对象
            ContentView()
                .modifier(SceneEnvironmentInjection(
                    appEnv: appEnv, appModel: appModel, dependencies: dependencies,
                    themeManager: themeManager, onboardingService: onboardingService
                ))

            // 启动闪屏层：覆盖在主视图之上
            if !hasSeenSplash {
                SplashView(onDismiss: {
                    guard !hasSeenSplash else { return }
                    Logger.shared.info("[Splash] Dismissing splash and persisting hasSeenSplashBefore.")
                    let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) // inject_exempt: App 入口 DI 初始化
                    SplashPresentationPolicy.markSplashSeen(keyStore: keyStore)
                    withAnimation(.easeInOut(duration: DesignTokens.Animation.slowDuration)) {
                        hasSeenSplash = true
                        NotificationCenter.default.post(name: .splashDismissed, object: nil)
                    }
                })
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onChange(of: AuthSession.shared.isLoggedIn) { _, isLoggedIn in
            // 用户首次登录完成（或已成功恢复会话）时，若仍在闪屏则立即跳过并固化持久化
            if isLoggedIn && !hasSeenSplash {
                Logger.shared.info("[Splash] User logged in during splash, dismissing immediately.")
                let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) // inject_exempt: App 入口 DI 初始化
                SplashPresentationPolicy.markSplashSeen(keyStore: keyStore)
                withAnimation(.easeInOut(duration: DesignTokens.Animation.slowDuration)) {
                    hasSeenSplash = true
                    NotificationCenter.default.post(name: .splashDismissed, object: nil)
                }
            }
        }
        .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
        .tint(themeManager.accentColor)
        .animation(.easeInOut(duration: DesignTokens.Animation.slowDuration), value: hasSeenSplash)
        .appToast()
    }
}
