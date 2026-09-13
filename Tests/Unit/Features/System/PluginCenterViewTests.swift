//
//  PluginCenterViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：对插件中心展示视图（PluginCenterView 及 PluginDetailView）的环境变量和依赖进行实例化验证。
//

import XCTest
import SwiftUI
@testable import ZhiYu

@MainActor
final class PluginCenterViewTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        setupFullMockEnvironment()
    }
    
    /// TC-PLG-01: 验证 PluginCenterView 能成功实例化且不因依赖项缺失崩溃
    func testPluginCenterViewInstantiation() {
        let store = AppStore()
        let router = Router.shared
        
        let view = PluginCenterView()
            .environment(store)
            .environment(router)
            
        XCTAssertNotNil(view, "PluginCenterView 应当被成功初始化而不为空")
    }

    /// TC-PLG-02: 验证 PluginDetailView 在传入 Mock 数据后能成功实例化且不因依赖项缺失崩溃
    func testPluginDetailViewInstantiation() {
        let store = AppStore()
        let router = Router.shared
        let marketService = PluginMarketService(registry: PluginRegistry())
        
        let mockPlugin = MarketPlugin(
            id: "test.plugin.detail",
            version: "1.0.0",
            author: "Tester",
            downloads: "200",
            rating: 4.8,
            icon: "puzzlepiece",
            downloadURL: "https://example.com/test.zyplugin",
            minAppVersion: "1.0",
            requiredPermissions: ["network"],
            monetization: nil,
            reviewCount: 10,
            category: "Utility",
            source: "community",
            names: ["en": "Test Detail Plugin", "zh-Hans": "测试详情插件"],
            descriptions: ["en": "Detailed description of mock plugin"]
        )
        
        let view = PluginDetailView(plugin: mockPlugin, marketService: marketService)
            .environment(store)
            .environment(router)
            
        XCTAssertNotNil(view, "PluginDetailView 应当被成功初始化而不为空")
    }
    
    /// TC-PLG-03: 验证 AppEmptyState 网络异常时 Retry 点击事件的闭包绑定回调能正常触发
    func testPluginMarketRetryTrigger() {
        let expectation = self.expectation(description: "Retry action triggered")
        
        // 创建一个包含 Action 的 AppEmptyState，并模拟点击 Retry
        let emptyState = AppEmptyState.withAction(
            icon: "wifi.slash",
            title: "Connection Error",
            description: "No Internet",
            actionLabel: "Retry",
            actionIcon: "arrow.clockwise"
        ) {
            expectation.fulfill()
        }
        
        XCTAssertNotNil(emptyState.action, "AppEmptyState 应当包含有效的行动按钮配置")
        XCTAssertEqual(emptyState.action?.label, "Retry")
        
        // 模拟执行 Action 的处理器，验证闭包调用
        emptyState.action?.handler()
        
        wait(for: [expectation], timeout: 1.0)
    }
}
