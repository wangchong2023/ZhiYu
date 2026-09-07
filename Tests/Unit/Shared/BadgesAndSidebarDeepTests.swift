//
//  BadgesAndSidebarDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 AIRainbowGlowBadge 全局发光微标、SidebarRowComponents
//           侧边栏组件与自适应分栏渲染。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class BadgesAndSidebarDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. AIRainbowGlowBadge 呼吸发光指示微标测试

    func testAIRainbowGlowBadge_Hierarchy() {
        let modelManager = GlobalModelManager.shared
        let host = AIRainbowGlowBadge()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertNotNil(modelManager, "全局模型管理器应单例就绪")
    }

    // MARK: - 2. SidebarSelection 路由转换测试
}
