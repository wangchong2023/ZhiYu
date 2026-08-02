//
//  ZhiYuProcessorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuProcessor 开展自动化单元测试验证。
//
import XCTest
import SwiftUI
@preconcurrency import GRDB
@testable import ZhiYu

// MARK: - 文档物理格式探测自动分类 (DocumentFormat) 单元测试
@MainActor
final class DocumentFormatTests: XCTestCase {
    
    func testDetectMarkdown() {
        let url = URL(fileURLWithPath: "/test.md")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }
    
    func testDetectPlainTxt() {
        let url = URL(fileURLWithPath: "/test.txt")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
    }
    
    func testDetectDocx() {
        let url = URL(fileURLWithPath: "/test.docx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .docx)
    }
    
    func testDetectXlsx() {
        let url = URL(fileURLWithPath: "/test.xlsx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .xlsx)
    }
    
    func testDetectPdf() {
        let url = URL(fileURLWithPath: "/test.pdf")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }
    
    func testDetectUnknown() {
        let url = URL(fileURLWithPath: "/test.xyz")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }
    
    func testDetectTextExtension() {
        let url = URL(fileURLWithPath: "/test.text")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
    }
}

// MARK: - Markdown AST 文本解析处理器 (MarkdownProcessor) 单元测试
final class MarkdownProcessorTests: XCTestCase {
    
    var parser: MarkdownProcessor!
    
    override func setUp() async throws {
        try await super.setUp()
        parser = MarkdownProcessor()
    }
    
    override func tearDown() async throws {
        parser = nil
        // 注意：此处必须调用 super.tearDown() 而非 super.setUp()，
        // 错误调用 setUp() 会破坏 Swift Concurrency 的 async 任务生命周期，
        // 导致 _swift_task_dealloc_specific 触发 SIGABRT 崩溃。
        try await super.tearDown()
    }
    
    /// 验证对多级 Markdown 标题语法的精准提取与层级标定
    func testParseHeadings() {
        let content = "# Heading 1\n\n## Heading 2\n\n### Heading 3"
        let blocks = parser.parse(content)
        
        let headings = blocks.compactMap { block -> String? in
            if case .heading(let text, let level) = block { return "\(text) (level \(level))" }
            return nil
        }
        XCTAssertEqual(headings.count, 3)
    }
    
    /// 验证对 fenced code block 代码块语法的块截取与语言类型标记
    func testParseCodeBlock() {
        let content = "```swift\nlet x = 1\n```\nText after"
        let blocks = parser.parse(content)
        
        guard case .codeBlock(let code, _) = blocks.first else {
            XCTFail("应当正常解析出代码块类型"); return
        }
        XCTAssertTrue(code.contains("let x = 1"))
        XCTAssertEqual(blocks.count, 2) // 代码块 + 段落
    }
    
    /// 验证无序列无序列表语法解析
    func testParseBulletList() {
        let content = "- Item 1\n- Item 2\n- Item 3"
        let blocks = parser.parse(content)
        
        guard case .bulletList(let items, _, _) = blocks.first else {
            XCTFail("应当正常解析出无序列表"); return
        }
        XCTAssertEqual(items.count, 3)
    }
    
    /// 验证任务列表（Task List）已勾选和未勾选状态的解析覆盖
    func testParseTaskList() {
        let content = "- [ ] Todo A\n- [x] Todo B\n- [X] Todo C"
        let blocks = parser.parse(content)
        
        guard case .taskList(let items) = blocks.first else {
            XCTFail("应当正常解析出任务列表类型"); return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertFalse(items[0].checked)  // [ ] 未勾选
        XCTAssertTrue(items[1].checked)   // [x] 已勾选
        XCTAssertTrue(items[2].checked)   // [X] 大写 X 已勾选
    }
    
    /// 验证 Markdown Blockquote 引用段落语法的解析
    func testParseBlockquote() {
        let content = "> This is a quote"
        let blocks = parser.parse(content)
        
        guard case .blockquote(let text) = blocks.first else {
            XCTFail("应当正常解析出引用块段落"); return
        }
        XCTAssertEqual(text, "This is a quote")
    }
    
    /// 验证水平分割线（Horizontal Rule）语法解析
    func testParseHorizontalRule() {
        let content = "---"
        let blocks = parser.parse(content)
        XCTAssertTrue(blocks.contains { if case .horizontalRule = $0 { return true }; return false })
    }
    
    /// 验证表格（Table）语法（包括表头、数据行）的多维解析
    func testParseTable() {
        let content = "| Name | Age |\n|------|-----|\n| Alice | 30 |\n| Bob | 25 |"
        let blocks = parser.parse(content)
        
        guard case .table(let headers, let rows) = blocks.first else {
            XCTFail("应当正常解析出表格数据结构"); return
        }
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(rows.count, 2)
    }
    
    /// 验证行内混合标记（加粗、行内代码、双链链接、斜体等）的细粒度片段探测
    func testParseInlineSegments() {
        let text = "**bold** `code` [[link]] *italic* plain"
        let segments = parser.parseInlineSegments(text)
        
        let types = segments.map(\.type)
        XCTAssertTrue(types.contains(.bold))
        XCTAssertTrue(types.contains(.code))
        XCTAssertTrue(types.contains(.applink))
        XCTAssertTrue(types.contains(.italic))
        XCTAssertTrue(types.contains(.text))
        
        // 验证 content 属性
        XCTAssertEqual(segments.first?.content, "bold")
    }
    
    /// 验证复杂复合排版排版下的连续 AST 流解析
    func testParseMixedContent() {
        let content = """
        # Title

        Some intro paragraph.

        ## Section

        - List item 1
        - List item 2

        > A quote here

        ```python
        print("hello")
        ```

        ---
        """
        let blocks = parser.parse(content)
        XCTAssertGreaterThanOrEqual(blocks.count, 6)
    }
    
    /// 验证空内容的容错
    func testParseEmptyContent() {
        let blocks = parser.parse("")
        XCTAssertTrue(blocks.isEmpty)
    }
    
    /// 验证仅含空格及换行段落的容错
    func testParseOnlyWhitespace() {
        let blocks = parser.parse("\n\n\n")
        XCTAssertTrue(blocks.isEmpty)
    }
}
