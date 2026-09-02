//
//  IngestServiceConceptLinkingTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度验证 IngestService 概念自动双链关联（Bug #58 修复：保护已有双链、Markdown 链接与代码块）。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

final class IngestServiceConceptLinkingTests: XCTestCase {

    // MARK: - 1. 基础纯文本概念链接测试

    func testLinkConceptsSafely_PlainText() {
        let content = "The Transformer model revolutionized natural language processing."
        let concepts = ["Transformer"]

        let result = IngestService.linkConceptsSafely(content: content, concepts: concepts)
        XCTAssertEqual(result, "The [[Transformer]] model revolutionized natural language processing.")
    }

    // MARK: - 2. 已有双链保护测试（杜绝 [[[[Transformer]]]] 重复包装）

    func testLinkConceptsSafely_PreservesExistingWikiLinks() {
        let content = "Already linked: [[Transformer]] and unlinked Transformer in the same sentence."
        let concepts = ["Transformer"]

        let result = IngestService.linkConceptsSafely(content: content, concepts: concepts)
        XCTAssertEqual(result, "Already linked: [[Transformer]] and unlinked [[Transformer]] in the same sentence.")
    }

    // MARK: - 3. Markdown 链接保护测试

    func testLinkConceptsSafely_PreservesMarkdownLinks() {
        let content = "Check [Transformer Architecture](https://transformer.org/paper) and Transformer here."
        let concepts = ["Transformer"]

        let result = IngestService.linkConceptsSafely(content: content, concepts: concepts)
        XCTAssertEqual(result, "Check [Transformer Architecture](https://transformer.org/paper) and [[Transformer]] here.")
    }

    // MARK: - 4. 代码块与行内代码保护测试

    func testLinkConceptsSafely_PreservesCodeBlocksAndSpans() {
        let content = """
        Here is inline `Transformer` code.
        ```swift
        let model = Transformer()
        ```
        And plain text Transformer.
        """
        let concepts = ["Transformer"]

        let result = IngestService.linkConceptsSafely(content: content, concepts: concepts)
        let expected = """
        Here is inline `Transformer` code.
        ```swift
        let model = Transformer()
        ```
        And plain text [[Transformer]].
        """
        XCTAssertEqual(result, expected)
    }

    // MARK: - 5. 长度优先降序匹配（避免短概念破坏长概念）

    func testLinkConceptsSafely_LongestConceptFirst() {
        let content = "We use Vision Transformer and Transformer in deep learning."
        let concepts = ["Transformer", "Vision Transformer"]

        let result = IngestService.linkConceptsSafely(content: content, concepts: concepts)
        XCTAssertEqual(result, "We use [[Vision Transformer]] and [[Transformer]] in deep learning.")
    }
}
