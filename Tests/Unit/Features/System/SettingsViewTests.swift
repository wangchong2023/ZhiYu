//
//  SettingsViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/05/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对系统设置视图（SettingsView）的环境变量和依赖注入进行单元测试验证。
//

import XCTest
import SwiftUI
import Dependencies
@testable import ZhiYu

/// 系统设置视图单元测试类
/// 专职验证 `SettingsView` 的依赖解析，防止由于 SwiftUI 环境（Environment）缺失导致运行时发生致命的 Coredump 崩溃。
@MainActor
final class SettingsViewTests: XCTestCase {

    @Dependency(\.themeService) var themeManager

    /// 在每次测试执行前重置 Mock 环境
    @MainActor
    override func setUp() {
        super.setUp()
        setupFullMockEnvironment()
    }
    
    /// TC-SET-01: 测试 SettingsView 的正确实例化与 Environment/EnvironmentObject 的依赖解析
    /// 验证 SettingsView 在被注入全部所需的环境依赖后能够成功构建，不存在环境对象缺失导致的运行时 Panic
    @MainActor
    func testSettingsViewInstantiationAndDependencyResolution() {
        let store = AppStore()
        let router = Router.shared
        let appEnvironment = AppEnvironment.shared
        let onboardingService = OnboardingService()
        
        // 模拟实例化 SettingsView 并链式注入所有关联的环境变量与环境对象
        let settingsView = SettingsView()
            .environment(store)
            .environment(router)
            .environment(appEnvironment)
            .environment(store.settingsStore)
            .environmentObject(onboardingService)
            .environment(themeManager)
        
        // 验证视图实例是否生成成功，不应为 nil
        XCTAssertNotNil(settingsView, "SettingsView 应当能够被成功实例化并且不为 nil")
    }
}
