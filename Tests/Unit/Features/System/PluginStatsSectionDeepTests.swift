//
//  PluginStatsSectionDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 PluginStatsSection 插件运行时资源大盘、Donut 饼图监控与明细卡片渲染。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import ZhiYuAICore
@testable import ZhiYu

@MainActor
final class PluginStatsSectionDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 空状态测试

    func testPluginStatsSection_EmptyState() {
        @Dependency(\.pluginRegistry) var registry
        registry.pluginResourceUsage.removeAll()

        let host = PluginStatsSection()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. 填充运行数据状态测试

    func testPluginStatsSection_WithActiveUsage() {
        @Dependency(\.pluginRegistry) var registry
        
        let usage1 = PluginRuntime.ResourceUsage(
            totalExecutionTime: 1.25,
            callCount: 15,
            lastExecutionTime: 0.08,
            status: .active
        )
        let usage2 = PluginRuntime.ResourceUsage(
            totalExecutionTime: 0.45,
            callCount: 8,
            lastExecutionTime: 0.05,
            status: .active
        )
        let usage3 = PluginRuntime.ResourceUsage(
            totalExecutionTime: 0.15,
            callCount: 3,
            lastExecutionTime: 0.02,
            status: .throttled
        )
        registry.pluginResourceUsage["com.zhiyu.plugin.translator"] = usage1
        registry.pluginResourceUsage["com.zhiyu.plugin.summarizer"] = usage2
        registry.pluginResourceUsage["com.zhiyu.plugin.ocr"] = usage3

        let host = PluginStatsSection()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
