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

struct ZhiYuApp: App {
    /// 状态持有：App 全局环境（负责所有后台服务的生命周期）
    @State private var appEnv = AppEnvironment.shared
    
    /// 状态持有：主题管理器
    @StateObject private var themeManager = ThemeManager.shared

    /// 状态持有：ZhiYuAppModel — 集中持有 21 个单例的 UI 可观察状态（P1 骨架，P2-P6 逐步填充）
    @State private var appModel = ZhiYuAppModel()

    /// 状态持有：DependencyContainer — 集中持有 21 个服务依赖（P1 骨架，P2-P6 逐步填充）
    @State private var dependencies = DependencyContainer()
    
    /// 状态持有：闪屏页可见性
    /// UI 测试时直接设为 true 跳过闪屏，避免遮挡 AuthView 导致 agreementCheckbox 等元素超时
    @State private var hasSeenSplash = CommandLine.arguments.contains("--uitesting")
    
    /// 引导状态持有
    @StateObject private var onboardingService = OnboardingService()
    
    /// UI 测试路由注入：解析 launch argument，在启动时直接跳转到目标页面
    /// 避免在视图/服务层散布 `if isUITesting` 分叉渲染
    private let uiTestRoute: UITestRoute?
    
    init() {
        uiTestRoute = UITestRoute.fromLaunchArguments()
        if let route = uiTestRoute {
            let router = AppEnvironment.shared.router
            Task { @MainActor in
                route.apply(to: router)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // 主内容视图：注入所有必需的环境对象
                ContentView()
                    .environment(appEnv) // 注入环境持有者自身，修复 SettingsView 崩溃
                    .environment(AuthService.shared)
                    .environment(VaultService.shared)
                    .environment(appEnv.store)
                    .environment(appEnv.store.aiWorkflowStore)
                    .environment(appEnv.store.aiInsightStore)
                    .environment(appEnv.store.searchStore)
                    .environment(appEnv.store.tagStore)
                    .environment(appEnv.store.knowledgeStore)
                    .environment(appEnv.store.settingsStore)
                    .environment(appEnv.llmConfig)
                    .environment(appEnv.router)
                    .environment(appEnv.ingestStore)
                    .environment(appEnv.synthesisStore)
                    // P1 骨架注入：AppModel + DependencyContainer（P2-P6 阶段逐步替换上方 .environment 调用）
                    .environment(appModel)
                    .environment(dependencies)
                    .environmentObject(themeManager)
                    .environmentObject(ServiceContainer.shared.resolve(LLMService.self))
                    .environmentObject(onboardingService)
                    .environmentObject(MedalService.shared)
                    .environment(\.locale, Localized.currentLocale)

                // 启动闪屏层：覆盖在主视图之上
                if !hasSeenSplash {
                    SplashView(onDismiss: {
                        guard !hasSeenSplash else { return }
                        Logger.shared.info(" [Splash] ...")
                        withAnimation(.easeInOut(duration: DesignSystem.Animation.slowDuration)) {
                            hasSeenSplash = true
                            NotificationCenter.default.post(name: .splashDismissed, object: nil)
                        }
                    })
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
            .tint(themeManager.accentColor)
            .animation(.easeInOut(duration: 0.6), value: hasSeenSplash)
            .appToast()
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.Creation.newPage) {
                    NotificationCenter.default.post(name: .createNewPage, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
    }
}

/// [L3] 单元测试专属空壳 App
/// 核心职责：在运行单元测试（XCTest）时，作为应用程序进程的壳载体运行。
/// 核心价值：通过运行此空壳 App，彻底切断了宿主应用程序 `ZhiYuApp` 在主线程/后台线程启动的任何初始化、数据种子化、数据同步等后台生命周期任务。
/// 从而保证单元测试运行在一个绝对独立、无任何后台异步任务污染的进程级沙盒内，根治并发 DI 服务未注册致命崩溃风险。
struct TestApp: App {
    var body: some Scene {
        WindowGroup {
            Text(L10n.Common.testRunnerWorking)
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// [L3] 应用程序动态分流总启动入口
/// 核心职责：在进程拉起时判定当前环境，如果是单元测试则启动空壳 `TestApp`，否则启动真实的 `ZhiYuApp`。
/// 实现机理：通过检测运行期是否载入 XCTest 类库来决定分流。
@main
struct AppLauncher {
    /// 进程统一启动主入口方法
    static func main() {
        let isUnitTesting = NSClassFromString("XCTestCase") != nil && !CommandLine.arguments.contains("-UITest_MockData")
        if isUnitTesting {
            // 单测环境下：分流启动空壳 App，屏蔽宿主所有服务和异步任务的实例化
            TestApp.main()
        } else {
            // 正常应用运行环境下：启动完整的业务 App，拉起核心 AppEnvironment 环境
            
            #if DEBUG
            if CommandLine.arguments.contains("--uitesting") || CommandLine.arguments.contains("-UITesting") {
                #if canImport(UIKit)
                UIView.setAnimationsEnabled(false)
                #endif
                Logger.shared.info("[AppLauncher] UI Testing environment detected. Disabled UIView animations for test stability.")
            }
            #endif
            
            // 物理自愈：如果检测到启动参数包含 "-ResetUserDefaults"（通常在 UI 自动化大回归跑测时传递）
            // 将重置并清空所有带有 "seeded_vault_" 前缀的本地笔记本冷启动播种标记，确保 Seeding 流程 100% 触发自愈
            //
            // NOTE: AppLauncher.main() 是进程入口点，运行于 DI 容器注册之前，
            // 属于 KeyStoreProtocol 无法覆盖的引导层上下文。此处保留 UserDefaults.standard
            // 直接访问，确保命令行参数自愈机制在 DI 就绪前即可生效。
            if CommandLine.arguments.contains("--reset-auth-state") {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: AppConstants.Keys.Storage.authIsAuthenticated)
                defaults.removeObject(forKey: AppConstants.Keys.Storage.authIsGuest)
                defaults.synchronize()
                
                // 同时清理 Keychain
                try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
                try? KeychainService.shared.delete(key: AppConstants.Network.refreshTokenKey)
                
                Logger.shared.info("[AppLauncher] Detected --reset-auth-state. Cleared auth state.")
            }
            
            if CommandLine.arguments.contains("-ResetUserDefaults") {
                let defaults = UserDefaults.standard
                let keys = defaults.dictionaryRepresentation().keys
                for key in keys where key.hasPrefix("seeded_vault_") {
                        defaults.removeObject(forKey: key)
                }
                defaults.synchronize()
                Logger.shared.info(" [AppLauncher] Found -ResetUserDefaults launch argument. Successfully sanitized and reset all seeded_vault_* keys.")
            }
            
            ZhiYuApp.main()
        }
    }
}

/// UI 测试路由注入枚举 — 在 @main 入口解析 launch argument，直接跳转到目标页面。
/// 避免在视图/服务层散布 `if isUITesting` 分叉渲染（测试耦合反模式）。
enum UITestRoute {
    case aiSettings
    case settings

    /// 从 CommandLine.arguments 解析 UI 测试路由
    static func fromLaunchArguments() -> UITestRoute? {
        if CommandLine.arguments.contains("--open-ai-settings") { return .aiSettings }
        if CommandLine.arguments.contains("--open-settings") { return .settings }
        return nil
    }

    /// 将路由应用到 Router 状态
    @MainActor
    func apply(to router: Router) {
        switch self {
        case .aiSettings:
            router.isShowingAISettingsSheet = true
        case .settings:
            router.isShowingSettingsSheet = true
        }
    }
}
