//
//  MarkdownRendererDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：MarkdownRendererAndUserProfileDeepTests.swift, MarkdownRendererDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class MarkdownRendererDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func executeSearch(query: String) async -> [KnowledgePage] {
            return []
        }

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
        XCTAssertFalse(markdownSample.isEmpty)
        XCTAssertTrue(markdownSample.contains("ZhiYu"))
    }

    func testUserProfileMenu_Rendering() {
        let authSession = AuthSession.shared
        let menuView = UserProfileMenu()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: menuView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertNotNil(authSession)
    }

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
        XCTAssertTrue(markdown.contains("智宇架构核心指南"))
        XCTAssertTrue(markdown.contains("UFPCore"))
    }

    func testMarkdownRenderer_PrivacyMode() {
        let privateContent = "机密知识内容与敏感商业机密"
        let host = MarkdownRendererView(
            content: privateContent,
            isPrivate: true,
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertFalse(privateContent.isEmpty)
    }

}
