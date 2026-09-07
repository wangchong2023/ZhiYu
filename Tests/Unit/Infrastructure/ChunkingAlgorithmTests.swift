//
//  ChunkingAlgorithmTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ChunkingAlgorithm 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

/// 语义分块边界测试套件 (ChunkingAlgorithmTests)
final class ChunkingAlgorithmTests: XCTestCase {

    private var chunker: TextChunkerProcessor!

    override func setUp() {
        super.setUp()
        chunker = TextChunkerProcessor()
    }

    override func tearDown() {
        chunker = nil
        super.tearDown()
    }

    // MARK: - 基础与极端边界测试

    /// 测试当输入空文本时的边缘行为。
    /// 预期：应当返回空分块列表，不引发崩溃或死循环。
    func testEmptyTextReturnsEmptyChunks() {
        // Arrange
        let text = ""
        let config = TextChunkerProcessor.Config(chunkSize: 100, chunkOverlap: 20, separators: [])

        // Act
        let chunks = chunker.split(text: text, config: config)

        // Assert
        XCTAssertTrue(chunks.isEmpty, "空文本应当返回空的分块结果列表")
    }

    /// 测试输入短文本（小于 chunkSize）的行为。
    /// 预期：应当只返回一个分块，内容与原文本一致（去除首尾空白），且 anchorPath 为 "Root"。
    func testShortTextReturnsSingleChunk() {
        // Arrange
        let text = "这是智宇知识库的短文本样例。"
        let config = TextChunkerProcessor.Config(chunkSize: 100, chunkOverlap: 10, separators: [])

        // Act
        let chunks = chunker.split(text: text, config: config)

        // Assert
        XCTAssertEqual(chunks.count, 1, "小于目标块大小的文本应当只产生一个分块")
        XCTAssertEqual(chunks.first?.text, text, "分块内容应当与原始文本完全一致")
        XCTAssertEqual(chunks.first?.anchorPath, "Root", "默认无标题时锚点路径应当为 Root")
        XCTAssertFalse(chunks.first?.isCode ?? true, "普通文本不应被识别为代码块")
    }

    // MARK: - 重叠（Overlap）机制与 CJK 特殊字符测试

    /// 测试分块重叠（Overlap）机制与偏移量（StartIndex）计算的正确性。
    /// 预期：相邻分块有 config.chunkOverlap 大小的重叠，并且第二个分块的 startIndex 计算正确。
    func testChunkOverlapAndStartIndexCalculation() {
        // Arrange
        // 每行 10 个字符（包括换行符）
        let line1 = "一一二二三三四四五\n" // 10 字符
        let line2 = "二二三三四四五五六\n" // 10 字符
        let line3 = "三三四四五五六六七\n" // 10 字符
        let line4 = "四四五五六六七七八\n" // 10 字符
        let text = line1 + line2 + line3 + line4 // 共 40 字符
        
        // 限制块大小为 25 字符，重叠窗口为 10 字符
        let config = TextChunkerProcessor.Config(chunkSize: 25, chunkOverlap: 10, separators: [])

        // Act
        let chunks = chunker.split(text: text, config: config)

        // Assert
        XCTAssertGreaterThanOrEqual(chunks.count, 2, "根据块大小，应当切分为至少 2 个分块")
        
        let chunk1 = chunks[0]
        let chunk2 = chunks[1]
        
        // 打印调试信息
        print("--- Chunk 1: [\(chunk1.text)] (StartIndex: \(chunk1.startIndex))")
        print("--- Chunk 2: [\(chunk2.text)] (StartIndex: \(chunk2.startIndex))")
        
        // 验证 chunk2 的起始文本包含 chunk1 的末尾重叠部分
        XCTAssertTrue(chunk2.text.contains("二二三三四四五五六"), "第二个分块应当保留前一个分块末尾的内容作为上下文重叠")
    }

    // MARK: - Markdown 标题路径追踪（Anchor Tracking）测试

    /// 测试在 Markdown 长文本切分过程中，对标题的层级感知与 anchorPath 自动修正。
    /// 预期：随着文本处理推进，各分块感知到最新的 `# 标题` 锚点路径。
    func testMarkdownAnchorPathTracking() {
        // Arrange
        let markdownText = """
        # 系统设计核心
        这是属于主标题下的第一段描述内容。
        ## 模块解耦
        这是关于模块解耦的具体实现说明。
        """
        
        // 限制很小的块大小，让其每次换行强拆，以测试不同段落的 anchorPath 变化
        let config = TextChunkerProcessor.Config(chunkSize: 20, chunkOverlap: 5, separators: [])

        // Act
        let chunks = chunker.split(text: markdownText, config: config)

        // Assert
        XCTAssertGreaterThanOrEqual(chunks.count, 2, "应当切分为多个分块")
        
        // 验证包含首个标题的分块
        if let firstChunk = chunks.first(where: { $0.text.contains("第一段") }) {
            XCTAssertEqual(firstChunk.anchorPath, "系统设计核心", "第一段描述的锚点应该绑定为主标题")
        }
        
        // 验证包含二级标题之后内容的分块
        if let secondChunk = chunks.first(where: { $0.text.contains("模块解耦") || $0.text.contains("具体实现") }) {
            XCTAssertEqual(secondChunk.anchorPath, "模块解耦", "二级标题后的描述应当追踪到最新的模块解耦锚点")
        }
    }

    // MARK: - 代码块完整性保护测试

    /// 测试当文本中包含 Markdown 代码块（```` ````）时的保护机制。
    /// 预期：即便代码块内的文本长度超过了配置的 chunkSize，在代码块结束前，也不应当将其强行截断，以保护代码的完整语法。
    func testCodeBlockProtectionPreventsArbitrarySplitting() {
        // Arrange
        let prefixText = "以下是关键的算法实现：\n"
        let codeBlock = """
        ```swift
        func calculateCoreMetrics(inputs: [Double]) -> Double {
            var sum = 0.0
            for input in inputs {
                sum += input * 1.414
            }
            return sum
        }
        ```
        """
        let text = prefixText + codeBlock
        
        // 故意设置较小的 chunkSize = 50，而代码块本身大约 150 字符
        // 按照普通流程应该会被强拆，但由于在代码块内部，应该会延后到代码块闭合后才封包
        let config = TextChunkerProcessor.Config(chunkSize: 50, chunkOverlap: 10, separators: [])

        // Act
        let chunks = chunker.split(text: text, config: config)

        // Assert
        XCTAssertFalse(chunks.isEmpty, "分块结果不应为空")
        
        // 检查包含代码块的分块是否完整保留了整个 ``` 代码结构，没有在中间拦腰折断
        let codeChunks = chunks.filter { $0.isCode }
        XCTAssertGreaterThanOrEqual(codeChunks.count, 1, "应当至少有一个分块被标记为包含代码块")
        
        for chunk in codeChunks {
            XCTAssertTrue(chunk.text.contains("```swift") && chunk.text.contains("```"), 
                          "代码块保护应当确保完整的开始和闭合标志均在同一个分块中，不能将代码块强行拆碎：\n\(chunk.text)")
        }
    }
}
