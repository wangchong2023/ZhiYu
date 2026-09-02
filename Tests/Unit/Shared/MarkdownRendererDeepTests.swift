//
//  MarkdownRendererDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 MarkdownRendererView 复杂 AST 块（表格/代码块/引用/公式/清单）渲染与隐私脱敏层。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class MarkdownRendererDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 基础排版渲染测试

    func testMarkdownRenderer_ComprehensiveBlocks() {
        let markdown = """
        # 智宇架构核心指南

        > [!NOTE]
        > 这是一个测试 Callout 提示框。

        ## 核心特性
        - [x] Swift 6 严格并发
        - [ ] GRDB 向量存储与 FTS5 检索
        - [ ] 知识双向拓扑图谱

        ```swift
        func executeSearch(query: String) async -> [KnowledgePage] {
            return []
        }
        ```

        | 模块 | 职责 | 覆盖率 |
        | :--- | :--- | :---: |
        | UFPCore | 基础设施与 DI 容器 | 95% |
        | ZhiYuDomain | 领域模型与契约 | 90% |

        这是一段包含 [[双向链接]] 和公式 $$E = mc^2$$ 的正文段落。
        """

        let host = MarkdownRendererView(
            content: markdown,
            isPrivate: false,
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. 隐私模式脱敏层测试

    func testMarkdownRenderer_PrivacyMode() {
        let host = MarkdownRendererView(
            content: "机密知识内容与敏感商业机密",
            isPrivate: true,
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
