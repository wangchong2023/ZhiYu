//
//  MarkdownProcessorBlockEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 MarkdownProcessor 块级解析器对标题/段落/列表/引用/代码块/表格/分割线/任务列表/details 的识别语义。
//

import XCTest
@testable import ZhiYu

final class MarkdownProcessorBlockEdgeTests: XCTestCase {

    private let processor = MarkdownProcessor()

    // MARK: - 空输入

    func testParse_emptyString_returnsEmptyBlocks() {
        XCTAssertTrue(processor.parse("").isEmpty)
    }

    func testParse_whitespaceOnly_returnsEmptyBlocks() {
        XCTAssertTrue(processor.parse("   \n   \n   ").isEmpty)
    }

    // MARK: - 标题

    func testParse_h1_returnsHeadingBlock() {
        let blocks = processor.parse("# 标题")
        XCTAssertEqual(blocks.count, 1)
        if case .heading(let text, let level) = blocks[0] {
            XCTAssertEqual(text, "标题")
            XCTAssertEqual(level, 1)
        } else {
            XCTFail("应为 heading 块")
        }
    }

    func testParse_h6_returnsHeadingBlock() {
        let blocks = processor.parse("###### 六级标题")
        XCTAssertEqual(blocks.count, 1)
        if case .heading(_, let level) = blocks[0] {
            XCTAssertEqual(level, 6)
        }
    }

    // MARK: - 段落

    func testParse_plainText_returnsParagraphBlock() {
        let blocks = processor.parse("普通段落")
        XCTAssertEqual(blocks.count, 1)
        if case .paragraph(let text) = blocks[0] {
            XCTAssertEqual(text, "普通段落")
        }
    }

    func testParse_multipleParagraphs_returnsMultipleBlocks() {
        let blocks = processor.parse("段落1\n\n段落2")
        XCTAssertEqual(blocks.count, 2)
    }

    // MARK: - 无序列表

    func testParse_bulletList_returnsBulletListBlock() {
        let blocks = processor.parse("- 项1\n- 项2\n- 项3")
        XCTAssertEqual(blocks.count, 1)
        if case .bulletList(let items, _, _) = blocks[0] {
            XCTAssertEqual(items.count, 3)
            XCTAssertEqual(items[0], "项1")
        }
    }

    func testParse_bulletListWithAsterisk_returnsBulletListBlock() {
        let blocks = processor.parse("* 项1\n* 项2")
        XCTAssertEqual(blocks.count, 1)
        if case .bulletList(let items, _, _) = blocks[0] {
            XCTAssertEqual(items.count, 2)
        }
    }

    // MARK: - 有序列表

    func testParse_orderedList_returnsBulletListBlock() {
        let blocks = processor.parse("1. 第一\n2. 第二\n3. 第三")
        XCTAssertEqual(blocks.count, 1)
        if case .bulletList(let items, _, let startNumber) = blocks[0] {
            XCTAssertEqual(items.count, 3)
            XCTAssertEqual(startNumber, 1)
        }
    }

    // MARK: - 引用块

    func testParse_blockquote_returnsBlockquoteBlock() {
        let blocks = processor.parse("> 引用内容")
        XCTAssertEqual(blocks.count, 1)
        if case .blockquote(let text) = blocks[0] {
            XCTAssertTrue(text.contains("引用内容"))
        }
    }

    // MARK: - 代码块

    func testParse_codeBlock_returnsCodeBlockBlock() {
        let blocks = processor.parse("```\ncode line\n```")
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(let code, let language) = blocks[0] {
            XCTAssertTrue(code.contains("code line"))
            XCTAssertEqual(language, "")
        }
    }

    func testParse_codeBlockWithLanguage_returnsCodeBlockBlock() {
        let blocks = processor.parse("```swift\nlet x = 1\n```")
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(_, let language) = blocks[0] {
            XCTAssertEqual(language, "swift")
        }
    }

    // MARK: - 水平分割线

    func testParse_horizontalRule_returnsHorizontalRuleBlock() {
        let blocks = processor.parse("---")
        XCTAssertEqual(blocks.count, 1)
        if case .horizontalRule = blocks[0] {
            // 预期
        } else {
            XCTFail("应为 horizontalRule")
        }
    }

    func testParse_horizontalRuleAsterisks_returnsHorizontalRuleBlock() {
        let blocks = processor.parse("***")
        XCTAssertEqual(blocks.count, 1)
        if case .horizontalRule = blocks[0] {} else {
            XCTFail("应为 horizontalRule")
        }
    }

    // MARK: - 任务列表

    func testParse_taskList_returnsTaskListBlock() {
        let blocks = processor.parse("- [x] 已完成\n- [ ] 未完成")
        XCTAssertEqual(blocks.count, 1)
        if case .taskList(let items) = blocks[0] {
            XCTAssertEqual(items.count, 2)
            XCTAssertTrue(items[0].checked)
            XCTAssertFalse(items[1].checked)
        }
    }

    // MARK: - 表格

    func testParse_table_returnsTableBlock() {
        let blocks = processor.parse("""
        | 列1 | 列2 |
        |-----|-----|
        | A   | B   |
        """)
        XCTAssertEqual(blocks.count, 1)
        if case .table(let headers, let rows) = blocks[0] {
            XCTAssertEqual(headers.count, 2)
            XCTAssertEqual(rows.count, 1)
        }
    }

    // MARK: - details 块

    func testParse_detailsBlock_returnsDetailsBlock() {
        let blocks = processor.parse("""
        <details>
        <summary>点击展开</summary>

        隐藏内容。
        </details>
        """)
        XCTAssertEqual(blocks.count, 1)
        if case .details(let summary, let content) = blocks[0] {
            XCTAssertTrue(summary.contains("点击展开"))
            XCTAssertTrue(content.contains("隐藏内容"))
        }
    }

    // MARK: - 混合内容

    func testParse_mixedContent_returnsMultipleBlocks() {
        let blocks = processor.parse("""
        # 标题

        段落内容。

        - 列表项1
        - 列表项2

        ```swift
        let x = 1
        ```
        """)
        XCTAssertGreaterThan(blocks.count, 3)
    }

    // MARK: - 空行处理

    func testParse_consecutiveEmptyLines_filtered() {
        let blocks = processor.parse("段落1\n\n\n\n\n段落2")
        XCTAssertEqual(blocks.count, 2, "连续空行应被过滤")
    }
}
