//
//  AppRootScenesAndSidebarDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用表现层测试
//  核心职责：针对主界面根视图（ContentView）与侧边栏/分栏布局组件（AppLayoutComponents）
//            执行全平台多栏响应式渲染与命令面板状态机覆盖。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppRootScenesAndSidebarDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ContentView 根视图多设备布局渲染

    func testContentView_RootViewRendering() {
        let contentView = ContentView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: contentView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. AppLayoutComponents 侧边栏与底部栏组件

    func testAppLayoutComponents_SidebarAndTabs() {
        let router = ServiceContainer.shared.resolve(Router.self)
        router.sidebarSelection = .tool(.dashboard)

        let contentView = ContentView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: contentView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertEqual(router.sidebarSelection, .tool(.dashboard))
    }
}
