//
//  MacSceneBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 场景根构建器（主窗口 + Settings + 辅助窗口），对齐任务 2 计划占位。
//
import SwiftUI
import UFPCore
import UFPDesignSystem

/// macOS 场景构建器：主窗口、Settings 与辅助窗口的统一场景出口
@MainActor
enum MacSceneBuilder {
    /// 主窗口：承载 MacMainWindow 外壳 + 依赖注入 + MacMenuCommands 菜单命令
    @SceneBuilder
    static func main(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService
    ) -> some Scene {
        WindowGroup(L10n.Common.appName, id: "main") {
            MacMainWindow()
                .modifier(SceneEnvironmentInjection(
                    appEnv: appEnv, appModel: appModel, dependencies: dependencies,
                    themeManager: themeManager, onboardingService: onboardingService
                ))
        }
        .defaultSize(
            width: DesignTokens.Metrics.macMainWindowWidth,
            height: DesignTokens.Metrics.macMainWindowHeight
        )
        .windowResizability(.contentSize)
        .commands { MacMenuCommands() }
    }

    /// 设置窗口：占位视图，任务 5 创建 MacSettingsView 后替换
    static func settings() -> some Scene {
        Settings { MacSettingsPlaceholder() }
    }

    /// 辅助窗口：个人资料、订阅计划、插件中心、笔记本中心
    @SceneBuilder
    static func windows() -> some Scene {
        Window(L10n.Auth.profileAndQuota, id: "profile") {
            UserProfileView()
        }
        Window(L10n.Auth.subscription, id: "plan") {
            SubscriptionPlanView()
        }
        Window(L10n.Plugin.title, id: "plugins") {
            PluginCenterView()
        }
        // 无 Notebook 模块 hubTitle 词条，复用 NotebookHubView 自身的导航标题 homeTitle
        Window(L10n.Vault.homeTitle, id: "notebook-hub") {
            NotebookHubView()
        }
    }
}

/// 设置窗口占位视图：任务 5 创建 MacSettingsView 后移除
private struct MacSettingsPlaceholder: View {
    var body: some View {
        Text(L10n.Common.settings)
    }
}
