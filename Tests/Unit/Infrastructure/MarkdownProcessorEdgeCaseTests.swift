//
//  MarkdownProcessorEdgeCaseTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 MarkdownProcessor 开展页面链接、加粗、斜体、代码、标题、列表与数学块的边界解析单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - MarkdownProcessor Edge Cases
final class MarkdownProcessorEdgeCaseTests: XCTestCase {

    var parser: MarkdownProcessor!

    override func setUp() {
        super.setUp()
        parser = MarkdownProcessor()
    }

    func testParsePageLinkWithSpaces() {
        let content = "This links to [[Page With Spaces]]"
        let segments = parser.parseInlineSegments(content)

        let pageLinks = segments.filter { $0.type == .applink }
        XCTAssertEqual(pageLinks.count, 1)
        XCTAssertEqual(pageLinks.first?.content, "Page With Spaces")
    }

    func testParsePageLinkWithChinese() {
        let content = "链接到 [[中文页面名称]]"
        let segments = parser.parseInlineSegments(content)

        let pageLinks = segments.filter { $0.type == .applink }
        XCTAssertEqual(pageLinks.count, 1)
        XCTAssertEqual(pageLinks.first?.content, "中文页面名称")
    }

    func testParsePageLinkEmpty() {
        let content = "Text with [[]] empty link"
        let segments = parser.parseInlineSegments(content)

        // Empty brackets should not be parsed as pageLink (regex requires non-empty)
        let pageLinks = segments.filter { $0.type == .applink }
        XCTAssertTrue(pageLinks.isEmpty || pageLinks.allSatisfy { !$0.content.isEmpty })
    }

    func testParseBoldAcrossMultipleWords() {
        let content = "This is **bold text** here"
        let segments = parser.parseInlineSegments(content)

        let boldSegments = segments.filter { $0.type == .bold }
        XCTAssertEqual(boldSegments.first?.content, "bold text")
    }

    func testParseItalicWithUnderscore() {
        let content = "This is _italic text_ here"
        let segments = parser.parseInlineSegments(content)

        let italicSegments = segments.filter { $0.type == .italic }
        XCTAssertEqual(italicSegments.first?.content, "italic text")
    }

    func testParseCodeWithBackticks() {
        let content = "Use `let x = 1` to declare"
        let segments = parser.parseInlineSegments(content)

        let codeSegments = segments.filter { $0.type == .code }
        XCTAssertEqual(codeSegments.first?.content, "let x = 1")
    }

    func testParseMultipleHeadings() {
        let content = "# H1\n## H2\n### H3\n#### H4"
        let blocks = parser.parse(content)

        let headings = blocks.compactMap { block -> (String, Int)? in
            if case .heading(let text, let level) = block { return (text, level) }
            return nil
        }
        XCTAssertEqual(headings.count, 4)
        XCTAssertEqual(headings[0].1, 1)
        XCTAssertEqual(headings[1].1, 2)
        XCTAssertEqual(headings[2].1, 3)
        XCTAssertEqual(headings[3].1, 4)
    }

    func testParseOrderedList() {
        let content = "1. First\n2. Second\n3. Third"
        let blocks = parser.parse(content)

        // Ordered lists are parsed into bulletList blocks (no separate orderedList type yet)
        guard case .bulletList(let items, _, _) = blocks.first else {
            XCTFail("Expected bulletList block for ordered list"); return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], "First")
        XCTAssertEqual(items[1], "Second")
        XCTAssertEqual(items[2], "Third")
    }

    func testParseNestedBulletList() {
        let content = "- Item 1\n  - Nested\n  - Also nested\n- Item 2"
        let blocks = parser.parse(content)

        guard case .bulletList(let items, _, _) = blocks.first else {
            XCTFail("Expected bullet list"); return
        }
        XCTAssertEqual(items.count, 2)
    }

    func testParseMathBlock() {
        let content = "$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$"
        let segments = parser.parseInlineSegments(content)

        // Math blocks ($...$) are not yet specially parsed; they fall through as plain text
        XCTAssertEqual(segments.count, 1, "Entire math expression should be a single text segment")
        XCTAssertEqual(segments.first?.type, .text, "Math content is not specially parsed yet")
    }

    func testParseInlineCodeWithinBold() {
        let content = "**bold with `code` inside**"
        let segments = parser.parseInlineSegments(content)

        // Should have bold with code inside
        let boldSegments = segments.filter { $0.type == .bold }
        XCTAssertFalse(boldSegments.isEmpty)
    }
}
