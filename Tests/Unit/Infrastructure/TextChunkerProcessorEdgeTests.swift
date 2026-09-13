//
//  TextChunkerProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 TextChunkerProcessor 递归分块器的边界条件、代码块保护、面包屑路径与重叠窗口语义正确性。
//

import XCTest
@testable import ZhiYu

final class TextChunkerProcessorEdgeTests: XCTestCase {

    private let chunker = TextChunkerProcessor()

    // MARK: - 空输入与边界

    func testSplit_emptyText_returnsEmptyArray() {
        let chunks = chunker.split(text: "")
        XCTAssertTrue(chunks.isEmpty, "空文本应返回空数组")
    }

    func testSplit_singleLineShortText_returnsSingleChunk() {
        let chunks = chunker.split(text: "短文本")
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].text, "短文本")
        XCTAssertEqual(chunks[0].anchorPath, "Root")
        XCTAssertEqual(chunks[0].breadcrumbPath, "Root")
        XCTAssertFalse(chunks[0].isCode)
    }

    func testSplit_whitespaceOnlyText_returnsEmptyArray() {
        let chunks = chunker.split(text: "   \n   \n   ")
        XCTAssertTrue(chunks.isEmpty, "纯空白文本应返回空数组")
    }

    // MARK: - 标题层级与面包屑路径

    func testSplit_h1H2H3_breadcrumbPathReflectsHierarchy() {
        let text = """
        # 一级标题

        段落内容1

        ## 二级标题

        段落内容2

        ### 三级标题

        段落内容3
        """
        let chunks = chunker.split(text: text)
        XCTAssertTrue(chunks.count >= 3, "应至少产生 3 个分块")

        let h1Chunk = chunks.first { $0.anchorPath == "一级标题" }
        XCTAssertNotNil(h1Chunk)
        XCTAssertEqual(h1Chunk?.breadcrumbPath, "一级标题")

        let h2Chunk = chunks.first { $0.anchorPath == "二级标题" }
        XCTAssertNotNil(h2Chunk)
        XCTAssertEqual(h2Chunk?.breadcrumbPath, "一级标题 > 二级标题")

        let h3Chunk = chunks.first { $0.anchorPath == "三级标题" }
        XCTAssertNotNil(h3Chunk)
        XCTAssertEqual(h3Chunk?.breadcrumbPath, "一级标题 > 二级标题 > 三级标题")
    }

    func testSplit_headerLevelSkip_back_to_h1_resetsBreadcrumb() {
        let text = """
        # H1
        内容1

        ### H3
        内容3

        # 新H1
        新内容
        """
        let chunks = chunker.split(text: text)

        let newH1Chunk = chunks.first { $0.anchorPath == "新H1" }
        XCTAssertNotNil(newH1Chunk)
        XCTAssertEqual(newH1Chunk?.breadcrumbPath, "新H1", "回到 H1 时面包屑应重置为单级")
    }

    // MARK: - 代码块保护

    func testSplit_codeBlockNotSplitEvenIfExceedsChunkSize() {
        let longCode = String(repeating: "let x = 10\n", count: 200)
        let text = """
        ```swift
        \(longCode)
        ```
        """
        let chunks = chunker.split(text: text)
        XCTAssertEqual(chunks.count, 1, "代码块不应被拆分，即使超过 chunkSize")
        XCTAssertTrue(chunks[0].isCode, "应标记为代码块")
    }

    func testSplit_codeBlockWithHashInsideNotTreatedAsHeader() {
        let text = """
        ```python
        # 这是 Python 注释，不是 Markdown 标题
        print("hello")
        ```
        """
        let chunks = chunker.split(text: text)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].anchorPath, "Root", "代码块内的 # 不应触发标题切换")
    }

    func testSplit_unclosedCodeBlock_treatedAsCodeBlock() {
        let text = """
        ```swift
        let x = 10
        """
        let chunks = chunker.split(text: text)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertTrue(chunks[0].isCode, "未闭合代码块应仍被标记为 isCode")
    }

    // MARK: - 重叠窗口

    func testSplit_overlapWindow_maintainsSemanticContinuity() {
        let config = TextChunkerProcessor.Config(
            chunkSize: 50,
            chunkOverlap: 20,
            separators: ["\n\n", "\n", ". ", " ", ""]
        )
        // 使用多行文本确保触发分块
        let text = (0..<20).map { _ in "这是一段需要被分块的长文本内容。" }.joined(separator: "\n")
        let chunks = chunker.split(text: text, config: config)
        XCTAssertGreaterThan(chunks.count, 1, "多行文本应产生多个分块")

        for chunk in chunks {
            XCTAssertFalse(chunk.text.isEmpty, "分块文本不应为空")
        }
    }

    // MARK: - contextualText 上下文注入

    func testChunk_contextualText_withBreadcrumb_includesContextPrefix() {
        let config = TextChunkerProcessor.Config(chunkSize: 1000, chunkOverlap: 200, separators: ["\n\n"])
        let text = "# 标题\n\n内容"
        let chunks = chunker.split(text: text, config: config)
        XCTAssertEqual(chunks.count, 1)
        // 标题行本身也在 chunk 文本内
        XCTAssertTrue(chunks[0].contextualText.hasPrefix("[Context: 标题]"), "contextualText 应含上下文前缀")
        XCTAssertTrue(chunks[0].contextualText.contains("内容"), "contextualText 应含正文")
    }

    func testChunk_contextualText_rootBreadcrumb_returnsPlainText() {
        let config = TextChunkerProcessor.Config(chunkSize: 1000, chunkOverlap: 200, separators: ["\n\n"])
        let chunks = chunker.split(text: "纯文本", config: config)
        XCTAssertEqual(chunks[0].contextualText, "纯文本")
    }

    // MARK: - startIndex 偏移正确性

    func testSplit_startIndex_monotonicallyIncreasing_bug12Fixed() {
        // 缺陷 #12 已修复：startIndex 现在正确计算，应严格单调递增
        let config = TextChunkerProcessor.Config(
            chunkSize: 30,
            chunkOverlap: 10,
            separators: ["\n\n", "\n", " ", ""]
        )
        let text = (0..<30).map { _ in "段落内容。" }.joined(separator: "\n")
        let chunks = chunker.split(text: text, config: config)
        XCTAssertGreaterThan(chunks.count, 1, "应产生多个分块")
        for i in 1..<chunks.count {
            XCTAssertGreaterThan(chunks[i].startIndex, chunks[i - 1].startIndex,
                "startIndex 应严格单调递增（缺陷 #12 已修复）")
        }
    }

    // MARK: - 默认配置

    func testDefaultConfig_chunkSizeIs1000() {
        XCTAssertEqual(TextChunkerProcessor.default.chunkSize, 1000)
    }

    func testDefaultConfig_chunkOverlapIs200() {
        XCTAssertEqual(TextChunkerProcessor.default.chunkOverlap, 200)
    }

    func testDefaultConfig_separatorsInPriorityOrder() {
        let separators = TextChunkerProcessor.default.separators
        XCTAssertEqual(separators.first, "\n# ")
        XCTAssertEqual(separators.last, "")
    }
}
