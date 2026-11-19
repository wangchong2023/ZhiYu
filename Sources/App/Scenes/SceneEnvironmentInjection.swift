//
//  SceneEnvironmentInjection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：抽取 ZhiYuApp.body 的 20+ 环境注入为公共 ViewModifier，供 iOS/macOS 场景共用。
//
import SwiftUI
import UFPCore

/// 公共环境注入 modifier：逐项对齐 ZhiYuApp.body 的注入链，两平台共用，不得遗漏
struct SceneEnvironmentInjection: ViewModifier {
    let appEnv: AppEnvironment
    let appModel: ZhiYuAppModel
    let dependencies: DependencyContainer
    let themeManager: ThemeManager
    let onboardingService: OnboardingService

    func body(content: Content) -> some View {
        content
            .environment(appEnv)
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
            .environment(appModel)
            .environment(dependencies)
            .environment(themeManager)
            .environmentObject(ServiceContainer.shared.resolve(LLMService.self) as LLMService) // inject_exempt: App 入口 DI 初始化
            .environmentObject(onboardingService)
            .environmentObject(MedalService.shared)
            .environment(\.locale, Localized.currentLocale)
    }
}
