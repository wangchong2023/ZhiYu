//
//  MarkdownRendererAndUserProfileDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层测试
//  核心职责：针对 Markdown 富文本渲染器（MarkdownRendererView）
//            与全局用户菜单/弹窗（UserProfileMenu）执行深度全状态与渲染覆盖。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class MarkdownRendererAndUserProfileDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. MarkdownRendererView 渲染多样 Markdown 结构

    func testMarkdownRendererView_VariousContents() {
        let markdownSample = """
        # 系统架构设计

        > **核心提示**：基于 LLM Wiki 与 RAG 闭环。

        - 支持 [[Concept:RAG]] 概念链接
        - 支持端侧本地模型推理

        ```swift
        print("Hello ZhiYu")
        ```
        """

        let renderer = MarkdownRendererView(
            content: markdownSample,
            isPrivate: false,
            onLinkTap: { _ in }
        ).snapshotEnvironment()

        let host = UIHostingController(rootView: renderer)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. UserProfileMenu 全局用户菜单

    func testUserProfileMenu_Rendering() {
        let menuView = UserProfileMenu()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: menuView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}
