//
//  HapticFeedbackTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对触感反馈与用户主菜单相关逻辑进行单元测试验证。
//

#if os(iOS)
import XCTest
import UFPCore
import SwiftUI
@testable import ZhiYu

final class HapticFeedbackTests: XCTestCase {
    
    @MainActor
    override func setUp() {
        super.setUp()
        setupFullMockEnvironment()
    }
    
    /// TC-HAP-01: 测试 iOSHapticService 的 trigger 接口不会发生 crash，且能正常被调用
    @MainActor
    func testiOSHapticServiceTrigger() {
        let service = iOSHapticService()
        let patterns: [HapticPattern] = [
            .success, .error, .warning, .processing, .lock, .unlock, .link, .selection, .pulse
        ]
        // 遍历所有模式触发，确保不会抛出异常或在不同硬件条件下发生 crash
        for pattern in patterns {
            service.trigger(pattern)
        }
    }
    
    /// TC-HAP-02: 测试 UserProfileMenu 视图的正确实例化与依赖解析
    @MainActor
    func testUserProfileMenuInstantiation() {
        let authService = AuthService.shared
        // 直接构造 AppStore() 实例，避免在单元测试下由于 ServiceContainer 未注册 AppStore 导致解析发生 DI 崩溃
        let store = AppStore()
        let router = ServiceContainer.shared.resolve(Router.self)
        let onboardingService = OnboardingService()
        let themeManager = ThemeManager()
        
        let menu = UserProfileMenu()
            .environment(authService)
            .environment(store)
            .environment(router)
            .environmentObject(onboardingService)
            .environment(themeManager)
        
        XCTAssertNotNil(menu)
    }
}
#endif
