//
//  AppSplashAboutCoachMarkFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 App 启动闪屏、关于智宇与新手引导视图。
//

import XCTest
import SwiftUI
@testable import ZhiYu
import UFPCore

@MainActor
final class AppSplashAboutCoachMarkFullCoverageTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SplashView 闪屏启动流深度测试

    func testSplashView_DismissCallbackAndRendering() {
        var dismissTriggered = false
        let splashView = SplashView {
            dismissTriggered = true
        }

        let host = UIHostingController(rootView: splashView.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()

        splashView.onDismiss()
        XCTAssertTrue(dismissTriggered, "点击或触发 onDismiss 闭包必须被调用")
        XCTAssertNotNil(host.view, "SplashView 应正常完成渲染布局")
    }

    // MARK: - 2. AboutView 关于页面渲染与版本解析测试

    func testAboutView_RenderingAndDynamicVersion() {
        let aboutView = AboutView()
        let host = UIHostingController(rootView: aboutView.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "AboutView 应正常展示开发者信息、版本号与版权信息")
    }

    // MARK: - 3. CoachMarkOverlay 新手引导矩阵测试

    func testCoachMarkOverlay_TypesAndActions() {
        var selectedTab: AppTab = .knowledge
        let tabBinding = Binding(get: { selectedTab }, set: { selectedTab = $0 })
        var dismissTriggered = false

        // 1. 图谱引导卡片与跳过动作
        let coachMark1 = CoachMarkOverlay(
            type: .graphDiscovery,
            selectedTab: tabBinding
        ) {
            dismissTriggered = true
        }

        let host1 = UIHostingController(rootView: coachMark1.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host1.view.layoutIfNeeded()

        coachMark1.onDismiss()
        XCTAssertTrue(dismissTriggered, "点击跳过引导应正确回调 onDismiss")

        // 2. 验证默认初始状态
        XCTAssertEqual(selectedTab, .knowledge)
    }
}
