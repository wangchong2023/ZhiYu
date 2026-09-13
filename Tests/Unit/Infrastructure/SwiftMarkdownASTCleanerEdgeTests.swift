//
//  SwiftMarkdownASTCleanerEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 SwiftMarkdownASTCleaner 对未闭合代码块、粗体/斜体、空行规整的自动修补能力。
//

import XCTest
@testable import ZhiYu

final class SwiftMarkdownASTCleanerEdgeTests: XCTestCase {

    // MARK: - 代码块闭合

    func testCleanAST_unclosedCodeBlock_appendsClosingFence() {
        let markdown = "```swift\nlet x = 10"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertTrue(cleaned.contains("```"), "未闭合代码块应补全 ``` 结尾, got: \(cleaned)")
        // 实际追加 \n```\n，验证补全发生
        XCTAssertGreaterThan(cleaned.components(separatedBy: "```").count - 1, 1, "应补全闭合 ```")
    }

    func testCleanAST_closedCodeBlock_unchanged() {
        let markdown = "```swift\nlet x = 10\n```"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertEqual(cleaned, markdown)
    }

    func testCleanAST_multipleCodeBlocks_allClosed() {
        let markdown = "```swift\ncode1\n```\n\n```python\ncode2\n```"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertEqual(cleaned, markdown)
    }

    // MARK: - 粗体闭合

    func testCleanAST_unclosedBold_appendsClosing() {
        let markdown = "**未闭合粗体"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertTrue(cleaned.hasSuffix("**"), "未闭合粗体应补全 ** 结尾")
    }

    func testCleanAST_closedBold_unchanged() {
        let markdown = "**已闭合粗体**"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertEqual(cleaned, markdown)
    }

    // MARK: - 空行规整

    func testCleanAST_tripleNewlines_collapsedToDouble() {
        let markdown = "段落1\n\n\n\n段落2"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertFalse(cleaned.contains("\n\n\n"), "连续 3+ 空行应被压缩为 2 个换行")
    }

    func testCleanAST_doubleNewlines_preserved() {
        let markdown = "段落1\n\n段落2"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertEqual(cleaned, markdown)
    }

    // MARK: - 边界输入

    func testCleanAST_emptyString_returnsEmpty() {
        XCTAssertEqual(SwiftMarkdownASTCleaner.cleanAST(""), "")
    }

    func testCleanAST_whitespaceOnly_returnsEmpty() {
        XCTAssertEqual(SwiftMarkdownASTCleaner.cleanAST("   \n   \n   "), "")
    }

    func testCleanAST_pureText_unchanged() {
        let markdown = "纯文本无格式"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertEqual(cleaned, markdown)
    }

    // MARK: - 组合场景

    func testCleanAST_unclosedCodeAndBold_bothFixed() {
        let markdown = "```swift\n**未闭合"
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(markdown)
        XCTAssertTrue(cleaned.hasSuffix("**"))
        XCTAssertTrue(cleaned.contains("```"))
    }
}
