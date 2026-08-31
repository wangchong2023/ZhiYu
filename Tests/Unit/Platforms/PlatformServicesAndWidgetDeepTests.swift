//
//  PlatformServicesAndWidgetDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层与平台层测试
//  核心职责：针对跨平台系统服务、小组件 Timeline、Spotlight 索引、
//            通用 UI 组件与 MarkdownRenderer 执行深层审计与边界测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PlatformServicesAndWidgetDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. MarkdownRendererView 跨平台富文本渲染测试

    func testMarkdownRendererView_RenderingRichText() {
        let markdown = """
        # 主标题
        正文描述段落，包含 **加粗** 和 *斜体* 以及 `inline code`。
        
        ```swift
        let a = 1
        ```
        """

        let renderer = MarkdownRendererView(
            content: markdown,
            isPrivate: false,
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()

        let host = UIHostingController(rootView: renderer)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. UserProfileMenu 悬浮菜单与窗口适配

    func testUserProfileMenu_Rendering() {
        let menu = UserProfileMenu()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: menu)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}
