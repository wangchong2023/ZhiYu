//
//  ZhiYuWatchApp.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：watchOS 平台实现：语音听写、健康数据同步、紧凑 UI。
//
import SwiftUI
import UFPCore

/// Apple Watch 应用程序入口
@main
struct AppWatchApp: App {
    /// 构造函数，在 watchOS App 启动时进行基础模块注册，保障系统 @Inject 的安全解析边界
    init() {
        WatchModuleRegistrar.register(in: ServiceContainer.shared)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                WatchKnowledgeStatsView()
                WatchDictationView()
                WatchBriefingView()
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
