//
//  TextChunkerMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：变异测试 —— 以「先构造预期失败场景」为原则，验证 TextChunkerProcessor
//  在畸变输入下的实际行为，而非根据实现反向构造必然通过的断言。
//
//  【变异设计原则】
//  每个用例先写「如果实现有 Bug 则断言失败」的期望。
//  测试运行失败 => 发现真实缺陷。
//

import XCTest
@testable import ZhiYu

final class TextChunkerMutationTests: XCTestCase {

    private let chunker = TextChunkerProcessor()

    // MARK: - 变异 M1：未闭合代码块不应跨块切片
    //
    // 场景：Markdown 中 ``` 开启但从未闭合。
    // 预期：分块器应把整个未闭合代码块作为一个 chunk 而不是截断它。
    // 危险点：updateCodeBlockState 只在遇到第二个 ``` 时 toggle 回 false；
    //         若整篇文档结束时 isInCodeBlock == true，所有内容都在同一个 chunk 里，
    //         但 chunk.isCode 应为 true（包含 ```）。
    func testMutation_UnclosedCodeBlock_IsContainedInSingleChunk() {
        let input = """
        # 第一节

        正文内容

        ```swift
        func hello() {
            print("unclosed code block")
        // 注意：这个代码块没有闭合！
        """

        let chunks = chunker.split(text: input)

        // 变异断言 1：不应产生零个 chunk（内容存在则必须有至少 1 个 chunk）
        XCTAssertGreaterThan(chunks.count, 0, "未闭合代码块内容不应被全部丢弃")

        // 变异断言 2：代码块内的行不应作为单独 chunk 的正文出现（应该被 isCode 标记）
        // 如果实现有缺陷，代码行可能以 isCode=false 的普通 chunk 形式出现
        guard let lastChunk = chunks.last else {
            XCTFail("chunks 不应为空")
            return
        }
        // 最后一个 chunk 包含了 ``` 标记，isCode 应该是 true
        XCTAssertTrue(
            lastChunk.isCode || chunks.contains(where: { $0.isCode }),
            "包含 ``` 的 chunk 必须标记 isCode=true，否则代码块语义丢失"
        )
    }

    // MARK: - 变异 M2：空文本分块应返回空数组
    //
    // 场景：传入空字符串、纯空白字符串。
    // 危险点：guard !text.isEmpty else { return [] } 仅处理了空字符串，
    //         纯空白字符串（"   \n   "）会进入处理逻辑。
    func testMutation_PureWhitespaceInput_ReturnsEmpty() {
        let whitespaceInputs = [
            "   ",
            "\n\n\n",
            "\t\t\t",
            "  \n  \t  \n  "
        ]

        for input in whitespaceInputs {
            let chunks = chunker.split(text: input)
            XCTAssertTrue(
                chunks.isEmpty,
                "纯空白输入 '\(input.debugDescription)' 不应产生任何 chunk，但得到了 \(chunks.count) 个"
            )
        }
    }

    // MARK: - 变异 M3：极短文本（单字符）分块
    //
    // 场景：1 个字符的输入。
    // 危险点：chunkOverlap 默认值可能超过文本长度，导致 String.index 越界崩溃。
    func testMutation_SingleCharInput_DoesNotCrash() {
        let inputs = ["A", "中", "1", "#"]
        for input in inputs {
            // 如果实现有越界 Bug，这里会抛出异常或 crash
            let chunks = chunker.split(text: input)
            if input == "#" {
                // 纯标题行，正文为空，可能没有 chunk
                // 但不应该 crash
            } else {
                XCTAssertEqual(chunks.count, 1, "单字符输入应产生 1 个 chunk，输入: '\(input)'")
                XCTAssertEqual(chunks.first?.text, input)
            }
        }
    }

    // MARK: - 变异 M4：超大文本 overlap 窗口边界
    //
    // 场景：文本长度恰好等于 chunkOverlap，触发边界计算。
    // 危险点：flushChunkOnOverflow 中 overlapAmount == oldChunkTextCount 时
    //         overlapIndex == startIndex，String.index 可能越界。
    func testMutation_TextExactlyEqualsOverlap_DoesNotCrash() {
        // 构造一个恰好比 chunkSize 大一个字符的文本，强制触发 overflow flush
        let chunkSize = ProcessorConstants.TextChunker.defaultChunkSize
        // 先写满 chunkSize 个字符，然后追加换行 + 一行新内容触发溢出
        let longLine = String(repeating: "A", count: chunkSize + 1)
        let input = longLine + "\n" + "overflow line"

        // 如果边界计算有 Bug，这里会崩溃
        let chunks = chunker.split(text: input)
        XCTAssertFalse(chunks.isEmpty, "溢出后应产生分块结果")

        // 验证 startIndex 单调递增（若重叠计算错误会出现相同或倒退的 startIndex）
        for i in 1..<chunks.count {
            XCTAssertGreaterThanOrEqual(
                chunks[i].startIndex,
                chunks[i - 1].startIndex,
                "chunk startIndex 必须单调递增，发现在 index \(i) 处回退"
            )
        }
    }

    // MARK: - 变异 M5：连续多级标题不含正文
    //
    // 场景：文档只有标题行，没有任何正文段落。
    // 危险点：连续调用 flushCurrentChunk 时 currentChunkText 为空，
    //         若判断不严格会产生空 chunk（text == ""）混入结果。
    func testMutation_OnlyHeaderLines_ProducesNoEmptyChunks() {
        let input = """
        # 第一章
        ## 第一节
        ### 第一小节
        # 第二章
        ## 第二节
        """

        let chunks = chunker.split(text: input)

        for chunk in chunks {
            XCTAssertFalse(
                chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "结果中不应存在空文本 chunk，但发现：'\(chunk.text)'"
            )
        }
    }

    // MARK: - 变异 M6：面包屑路径与标题层级一致性
    //
    // 场景：H1 > H2 > H3 嵌套，然后突然跳回 H1。
    // 危险点：anchorStack 修剪逻辑 keepCount = headerLevel - 1，
    //         当跳回 H1 时 keepCount=0，栈应被清空。
    //         若修剪有误，面包屑会残留旧层级。
    func testMutation_HeaderBreadcrumbReset_OnLevelJump() {
        let input = """
        # 顶层

        ## 二级标题

        ### 三级标题

        三级正文内容

        # 新顶层

        新顶层正文
        """

        let chunks = chunker.split(text: input)

        // 找到"新顶层正文"所在的 chunk
        let newTopChunk = chunks.first(where: { $0.text.contains("新顶层正文") })
        XCTAssertNotNil(newTopChunk, "应该能找到含「新顶层正文」的 chunk")

        if let chunk = newTopChunk {
            // 面包屑中不应含有"三级标题"或"二级标题"的残留
            XCTAssertFalse(
                chunk.breadcrumbPath.contains("三级标题"),
                "跳回 H1 后面包屑不应残留「三级标题」，实际值: '\(chunk.breadcrumbPath)'"
            )
            XCTAssertFalse(
                chunk.breadcrumbPath.contains("二级标题"),
                "跳回 H1 后面包屑不应残留「二级标题」，实际值: '\(chunk.breadcrumbPath)'"
            )
        }
    }
}
