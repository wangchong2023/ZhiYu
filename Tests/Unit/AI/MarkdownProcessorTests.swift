//
//  MarkdownProcessorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 MarkdownProcessor 的解析能力开展自动化单元测试。
//

import XCTest
@testable import ZhiYu

final class MarkdownParserTests: XCTestCase {

    private let processor = MarkdownProcessor()

    // MARK: - parse 基本功能

    func testParse_emptyContent() {
        let blocks = processor.parse("")
        XCTAssertTrue(blocks.isEmpty)
    }

    func testParse_whitespaceOnly() {
        let blocks = processor.parse("  \n  \n  ")
        XCTAssertTrue(blocks.isEmpty)
    }

    func testParse_paragraph() {
        let blocks = processor.parse("Hello world")
        XCTAssertEqual(blocks.count, 1)
        if case .paragraph(let text) = blocks[0] {
            XCTAssertEqual(text, "Hello world")
        } else {
            XCTFail("应为 paragraph")
        }
    }

    func testParse_multipleParagraphs() {
        let blocks = processor.parse("First\n\nSecond")
        XCTAssertEqual(blocks.count, 2)
    }

    // MARK: - 标题

    func testParse_headingH1() {
        let blocks = processor.parse("# Title")
        XCTAssertEqual(blocks.count, 1)
        if case .heading(let text, let level) = blocks[0] {
            XCTAssertEqual(text, "Title")
            XCTAssertEqual(level, 1)
        } else {
            XCTFail("应为 heading")
        }
    }

    func testParse_headingH2() {
        let blocks = processor.parse("## Section")
        XCTAssertEqual(blocks.count, 1)
        if case .heading(let text, let level) = blocks[0] {
            XCTAssertEqual(text, "Section")
            XCTAssertEqual(level, 2)
        } else {
            XCTFail("应为 heading")
        }
    }

    func testParse_headingH3() {
        let blocks = processor.parse("### Sub")
        XCTAssertEqual(blocks.count, 1)
        if case .heading(_, let level) = blocks[0] {
            XCTAssertEqual(level, 3)
        }
    }

    // MARK: - 代码块

    func testParse_codeBlock() {
        let md = """
        ```swift
        let x = 1
        ```
        """
        let blocks = processor.parse(md)
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(let code, let language) = blocks[0] {
            XCTAssertEqual(language, "swift")
            XCTAssertEqual(code.trimmingCharacters(in: .whitespaces), "let x = 1")
        } else {
            XCTFail("应为 codeBlock")
        }
    }

    func testParse_codeBlock_noLanguage() {
        let md = """
        ```
        raw code
        ```
        """
        let blocks = processor.parse(md)
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(_, let language) = blocks[0] {
            XCTAssertTrue(language.isEmpty)
        }
    }

    // MARK: - 列表

    func testParse_unorderedList() {
        let md = """
        - Item A
        - Item B
        - Item C
        """
        let blocks = processor.parse(md)
        XCTAssertEqual(blocks.count, 1)
        if case .bulletList(let items, _, _) = blocks[0] {
            XCTAssertEqual(items, ["Item A", "Item B", "Item C"])
        } else {
            XCTFail("应为 bulletList")
        }
    }

    func testParse_orderedList() {
        let md = """
        1. First
        2. Second
        """
        let blocks = processor.parse(md)
        XCTAssertEqual(blocks.count, 1)
        if case .bulletList(let items, _, _) = blocks[0] {
            XCTAssertEqual(items, ["First", "Second"])
        } else {
            XCTFail("应为 bulletList (ordered)")
        }
    }

    // MARK: - 引用块

    func testParse_blockquote() {
        let blocks = processor.parse("> 引用内容")
        XCTAssertEqual(blocks.count, 1)
        if case .blockquote(let text) = blocks[0] {
            XCTAssertEqual(text, "引用内容")
        } else {
            XCTFail("应为 blockquote")
        }
    }

    // MARK: - 水平线

    func testParse_horizontalRule_dash() {
        let blocks = processor.parse("---")
        XCTAssertEqual(blocks.count, 1)
        if case .horizontalRule = blocks[0] {
            // pass
        } else {
            XCTFail("应为 horizontalRule")
        }
    }

    func testParse_horizontalRule_asterisk() {
        let blocks = processor.parse("***")
        XCTAssertEqual(blocks.count, 1)
        if case .horizontalRule = blocks[0] {
            // pass
        } else {
            XCTFail("应为 horizontalRule")
        }
    }

    // MARK: - 混合内容

    func testParse_mixedContent() {
        let md = """
        # Title

        普通段落内容

        - 列表项1
        - 列表项2

        > 引用
        """
        let blocks = processor.parse(md)
        XCTAssertGreaterThan(blocks.count, 3)
    }

    // MARK: - 行内解析

    func testParseInlineSegments_plainText() {
        let segments = processor.parseInlineSegments("Hello")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .text)
        XCTAssertEqual(segments[0].content, "Hello")
    }

    func testParseInlineSegments_bold() {
        let segments = processor.parseInlineSegments("**bold**")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .bold)
        XCTAssertEqual(segments[0].content, "bold")
    }

    func testParseInlineSegments_italic() {
        let segments = processor.parseInlineSegments("*italic*")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .italic)
        XCTAssertEqual(segments[0].content, "italic")
    }

    func testParseInlineSegments_code() {
        let segments = processor.parseInlineSegments("`code`")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .code)
        XCTAssertEqual(segments[0].content, "code")
    }

    func testParseInlineSegments_strikethrough() {
        let segments = processor.parseInlineSegments("~~deleted~~")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .strikethrough)
        XCTAssertEqual(segments[0].content, "deleted")
    }

    func testParseInlineSegments_applink() {
        let segments = processor.parseInlineSegments("[[TargetPage]]")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .applink)
        XCTAssertEqual(segments[0].content, "TargetPage")
    }

    func testParseInlineSegments_applinkWithAlias() {
        let segments = processor.parseInlineSegments("[[显示名|实际页面]]")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .applink)
        XCTAssertEqual(segments[0].content, "显示名|实际页面")
    }

    func testParseInlineSegments_mixed_TextAndBold() {
        let segments = processor.parseInlineSegments("Text **bold** end")
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].type, .text)
        XCTAssertEqual(segments[1].type, .bold)
        XCTAssertEqual(segments[2].type, .text)
    }

    func testParseInlineSegments_mixed_WithApplink() {
        let segments = processor.parseInlineSegments("Before [[Link]] after")
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].type, .text)
        XCTAssertEqual(segments[0].content, "Before ")
        XCTAssertEqual(segments[1].type, .applink)
        XCTAssertEqual(segments[1].content, "Link")
        XCTAssertEqual(segments[2].type, .text)
        XCTAssertEqual(segments[2].content, " after")
    }

    func testParseInlineSegments_boldInsideApplinkProtected() {
        let segments = processor.parseInlineSegments("**bold** and [[Link]]")
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].type, .bold)
        XCTAssertEqual(segments[1].type, .text)
        XCTAssertEqual(segments[2].type, .applink)
    }

    func testParseInlineSegments_link() {
        let segments = processor.parseInlineSegments("[Click](https://example.com)")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .link)
        XCTAssertEqual(segments[0].content, "Click|https://example.com")
    }

    func testParseInlineSegments_emptyString() {
        let segments = processor.parseInlineSegments("")
        XCTAssertTrue(segments.isEmpty)
    }

    // MARK: - 任务列表

    func testParse_taskList() {
        let md = """
        - [x] Completed
        - [ ] Pending
        """
        let blocks = processor.parse(md)
        XCTAssertEqual(blocks.count, 1)
        if case .taskList(let items) = blocks[0] {
            XCTAssertEqual(items.count, 2)
            XCTAssertEqual(items[0].text, "Completed")
            XCTAssertTrue(items[0].checked)
            XCTAssertEqual(items[1].text, "Pending")
            XCTAssertFalse(items[1].checked)
        } else {
            XCTFail("应为 taskList")
        }
    }
}
