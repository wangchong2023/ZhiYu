//
//  TextChunkerDeepEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 TextChunkerProcessor 在未闭合代码块、跳级 Markdown 标题栈、超长单行与多字节 Unicode 字符下的边界分块精度。
//

import XCTest
@testable import ZhiYuDomain

final class TextChunkerDeepEdgeTests: XCTestCase {

    private let chunker = TextChunkerProcessor()

    // MARK: - 1. 未闭合代码块边界

    func testUnclosedCodeFenceParsing() {
        let text = """
        # 代码章节
        下面是一段未闭合的代码：
        ```swift
        let a = 1
        let b = 2
        """

        let chunks = chunker.split(text: text)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.contains { $0.isCode }, "包含代码块标记的分块应标记 isCode 为 true")
    }

    // MARK: - 2. 跳级 Markdown 标题面包屑栈回退

    func testDeepHeaderStackJumpAndPrune() {
        let text = """
        # 一级模块
        一级内容描述。
        ### 三级深层配置
        深层内容描述。
        ## 二级核心模块
        二级内容描述。
        """

        let config = TextChunkerProcessor.Config(chunkSize: 50, chunkOverlap: 10, separators: ["\n"])
        let chunks = chunker.split(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty)

        // 验证深层配置的面包屑包含一级与三级
        let deepChunk = chunks.first { $0.text.contains("深层内容描述") }
        XCTAssertNotNil(deepChunk)
        XCTAssertTrue(deepChunk?.breadcrumbPath.contains("一级模块") == true)
        XCTAssertTrue(deepChunk?.breadcrumbPath.contains("三级深层配置") == true)

        // 验证回退到二级模块时，三级配置被正确从面包屑栈中修剪出栈
        let secondChunk = chunks.first { $0.text.contains("二级内容描述") }
        XCTAssertNotNil(secondChunk)
        XCTAssertTrue(secondChunk?.breadcrumbPath.contains("二级核心模块") == true)
        XCTAssertFalse(secondChunk?.breadcrumbPath.contains("三级深层配置") == true, "二级标题出现时应从栈中修剪掉兄弟/子级标题")
    }

    // MARK: - 3. 多字节 Emoji 与复合字符偏移安全性

    func testUnicodeEmojiOffsetSafety() {
        let text = """
        # 🌟 核心功能 🚀
        这是一个包含很多特殊字符的段落：👨‍👩‍👧‍👦 复杂的家庭 emoji 以及 🇨🇳 国旗符号。
        确保在计算 startIndex 和 chunk count 时不会触发 String 越界崩溃。
        """

        let chunks = chunker.split(text: text)
        XCTAssertFalse(chunks.isEmpty)
        for chunk in chunks {
            XCTAssertGreaterThanOrEqual(chunk.startIndex, 0)
            XCTAssertFalse(chunk.text.isEmpty)
        }
    }

    // MARK: - 缺陷 #242 回归：CRLF 归一化、#标签防误判标题与超长无换行单行切分

    func testCRLFNormalization_matchesLFChunksAndOffsets() {
        let lfText = "# 标题一\n第一段内容。\n## 标题二\n第二段内容。"
        let crlfText = lfText.replacingOccurrences(of: "\n", with: "\r\n")

        let lfChunks = chunker.split(text: lfText)
        let crlfChunks = chunker.split(text: crlfText)

        XCTAssertEqual(crlfChunks.map(\.text), lfChunks.map(\.text), "CRLF 文本不应产生额外空行")
        XCTAssertEqual(crlfChunks.map(\.startIndex), lfChunks.map(\.startIndex), "CRLF 归一化后 startIndex 应与 LF 一致")
    }

    func testHashtagLine_notTreatedAsMarkdownHeading() {
        let text = """
        # 合法章节
        正文开始。
        #Swift #并发
        正文继续。
        """
        let chunks = chunker.split(text: text)

        XCTAssertEqual(chunks.count, 1, "行首 #标签 不应被误判为 Markdown 标题强行拆块")
        XCTAssertEqual(chunks[0].anchorPath, "合法章节", "行首 #标签 不应污染 anchorPath")
        XCTAssertEqual(chunks[0].breadcrumbPath, "合法章节", "行首 #标签 不应污染 breadcrumbPath")
    }

    func testOversizedSingleLine_slicedWithinChunkSize() {
        let longLine = String(repeating: "测", count: 350)
        let config = TextChunkerProcessor.Config(chunkSize: 100, chunkOverlap: 20, separators: ["\n"])
        let chunks = chunker.split(text: longLine, config: config)

        XCTAssertGreaterThanOrEqual(chunks.count, 4, "350 字符无换行单行在 chunkSize=100 下应被滑窗切分")
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.text.count, 100, "每个切片长度不应突破 chunkSize 上限")
        }
    }
}
