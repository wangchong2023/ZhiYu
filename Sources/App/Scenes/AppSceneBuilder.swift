//
//  AppSceneBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：唯一 #if os 三平台场景分发点，收敛平台 scene 差异。
//
import SwiftUI

/// 场景根分发：平台差异在此收敛，业务层无宏
@MainActor
enum AppSceneBuilder {
    /// 各平台场景根（@SceneBuilder 组合多 scene）
    @SceneBuilder
    static func root(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService,
        hasSeenSplash: Bool
    ) -> some Scene {
        #if os(macOS)
        // macOS 分支占位：MacSceneBuilder 于任务 2 创建后替换为真实三组 scene
        iOSSceneBuilder.main(
            appEnv: appEnv, appModel: appModel, dependencies: dependencies,
            themeManager: themeManager, onboardingService: onboardingService,
            hasSeenSplash: hasSeenSplash
        )
        #else
        iOSSceneBuilder.main(
            appEnv: appEnv, appModel: appModel, dependencies: dependencies,
            themeManager: themeManager, onboardingService: onboardingService,
            hasSeenSplash: hasSeenSplash
        )
        #endif
    }
}
