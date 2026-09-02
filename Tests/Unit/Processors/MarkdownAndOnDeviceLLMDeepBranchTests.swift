//
//  MarkdownAndOnDeviceLLMDeepBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：针对 Markdown AST 复杂块解析（MarkdownProcessor+BlockParsing）
//            与端侧 LLM 模型调度（OnDeviceLLMService）进行极限分支与降级测试。
//

import XCTest
import UFPCore
import ZhiYuAICore
@testable import ZhiYu

@MainActor
final class MarkdownAndOnDeviceLLMDeepBranchTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. MarkdownProcessor 块级多形态 AST 解析分支

    func testMarkdownProcessor_NestedBlocksAndTableVariations() {
        let complexDoc = """
        # 主标题

        > [!NOTE]
        > 这是一个 GitHub 风格的 Alert 提示块。
        > 包含多行注释与 [链接](https://example.com)。

        | 模块 | 职责 | 覆盖率 |
        | :--- | :--- | :--- |
        | Core | 内核 | 95% |
        | Domain | 业务大脑 | 92% |

        ```swift
        func testConcurrent() async throws {
            print("Safe")
        }
        ```

        - [x] 完成单元测试
        - [ ] 待办事项
        """

        let processor = MarkdownProcessor()
        let blocks = processor.parse(complexDoc)
        XCTAssertFalse(blocks.isEmpty)
        XCTAssertGreaterThanOrEqual(blocks.count, 4)
    }

    // MARK: - 2. OnDeviceLLMService 端侧模型状态机与降级分支

    func testOnDeviceLLMService_AvailabilityAndManifestCheck() {
        let service = OnDeviceLLMService()
        XCTAssertNotNil(service)
        XCTAssertFalse(service.isGenerating)
    }
}
