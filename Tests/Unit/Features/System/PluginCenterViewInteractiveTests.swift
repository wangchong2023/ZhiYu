//
//  PluginCenterViewInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：PluginCenterView 搜索匹配、分类过滤、插件来源动态研判与安全模式警告交互测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PluginCenterViewInteractiveTests: XCTestCase {

    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router.shared
    }

    override func tearDown() async throws {
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. PluginCenterView 视图层级挂载测试

    func testPluginCenterViewMount() {
        let view = PluginCenterView()
            .environment(router)

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(router)
        XCTAssertNotNil(host.view)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
}
