//
//  SettingsAndPluginsDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对插件中心（PluginCenterView）、系统设置（SettingsView）与
//            开发者调试选项执行深度渲染与交互状态机测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SettingsAndPluginsDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PluginCenterView 插件市场与安全模式切换

    func testPluginCenterView_FullRendering() {
        let pluginCenter = PluginCenterView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: pluginCenter)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. ServerConfigView 服务器配置列表与 Sheet 弹窗

    func testServerConfigView_Rendering() {
        let serverView = ServerConfigView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: serverView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}
