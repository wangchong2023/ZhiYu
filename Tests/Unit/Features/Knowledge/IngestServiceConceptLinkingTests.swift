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
@testable import ZhiYuUnitTestHost

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

    // MARK: - 6. 缺陷 #273 回归：纯空白概念/目录过滤防污染

    func testLinkConceptsSafely_IgnoresWhitespaceOnlyConceptsAndRegularFileFilterExcludesDirectories() throws {
        let content = "Hello world\nNext line"
        let linked = IngestService.linkConceptsSafely(content: content, concepts: [" ", "\n\t", ""])
        XCTAssertEqual(linked, content, "纯空白概念不得触发 [[ ]] 注入污染")

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ingest_filter_\(UUID().uuidString)", isDirectory: true)
        let subDir = tempDir.appendingPathComponent("SubFolder", isDirectory: true)
        let fileA = tempDir.appendingPathComponent("noteA.md")
        let fileB = subDir.appendingPathComponent("noteB.txt")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: fileA)
        try Data("b".utf8).write(to: fileB)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let resolved = IngestService.regularFileURLs(in: tempDir) ?? []
        XCTAssertEqual(resolved.count, 2, "regularFileURLs 必须排除子目录条目，仅返回常规文件")
        XCTAssertFalse(resolved.contains(where: { $0.lastPathComponent == "SubFolder" }))
    }
}
