//
//  ParsersAndSanitizersFuzzTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：针对全工程核心文本解析器、分词器、脱敏器与 Frontmatter 处理器
//            执行 Fuzz 模糊变异与边界异常测试，挖掘深层崩溃、死循环与解析坏味道。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class ParsersAndSanitizersFuzzTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. FrontmatterParser Fuzz 模糊与变异测试

    func testFrontmatterParser_FuzzMalformedInputs_NeverCrashes() {
        let fuzzPayloads: [String] = [
            "",
            "---",
            "---\n---",
            "---\nkey: value",
            "---\nkey: [1, 2, \n---",
            "---json\n{\"outlines\": [{\"id\": \"1\", \"title\": \"Node 1\", \"level\": 1}]}\n---",
            "---json\n{\"outlines\": \"invalid_array_type\"}\n---\n正文内容",
            "---\n: : : \n---",
            "---\n- - -\n---",
            "  ---\nkey: value\n---\n前置空格不应识别为Frontmatter",
            String(repeating: "---\nkey: test\n", count: 100) + "---\n正文",
            "---\nnull_bytes: \u{0000}\u{0001}\u{0002}\n---\nBody with nulls",
            "---\nunicode: 👨‍👩‍👧‍👦 🇨🇳 \u{200B}\u{FEFF}\n---\nUnicode body"
        ]

        for payload in fuzzPayloads {
            let splitResult = FrontmatterParser.split(content: payload)
            if let fm = splitResult.frontmatter {
                _ = FrontmatterParser.parse(ConceptFrontmatter.self, from: fm)
                _ = FrontmatterParser.parse(EntityFrontmatter.self, from: fm)
                _ = FrontmatterParser.parse(ComparisonFrontmatter.self, from: fm)
            }
            XCTAssertNotNil(splitResult.body, "无论输入何种畸变内容，Body 均应安全返回")
        }
    }

    func testFrontmatterParser_ComparisonFrontmatter_FuzzTypes() throws {
        let jsonValid = """
        {
            "subjects": [{"id": "s1", "name": "Swift"}, {"id": "s2", "name": "Rust"}],
            "dimensions": [{"id": "d1", "name": "价格", "type": "text"}],
            "matrix": [
                {"subject_id": "s1", "dimension_id": "d1", "value": "免费"}
            ]
        }
        """

        if let parsed = FrontmatterParser.parse(ComparisonFrontmatter.self, from: jsonValid) {
            XCTAssertEqual(parsed.subjects?.count, 2)
            XCTAssertEqual(parsed.dimensions?.count, 1)
        }
    }

    // MARK: - 2. SSEParser 流式事件分词 Fuzz 测试

    func testSSEParser_FuzzMalformedChunkStreams() {
        let chunks: [String] = [
            "data: {\"text\": \"chunk1\"}",
            "data: {\"choices\": [{\"delta\": {\"content\": \"hello\"}}]}",
            ": comment line",
            "data: [DONE]",
            "data: incomplete json {",
            "\"text\": \"part2\"}",
            "data: \u{0000}\u{FFFF}",
            "invalid line without colon",
            String(repeating: "data: {\"token\":\"a\"}\n", count: 50)
        ]

        for chunk in chunks {
            if let dataStr = SSEParser.extractDataString(from: chunk) {
                _ = SSEParser.parseJSONLine(dataStr, logger: nil)
            }
        }
    }

    // MARK: - 3. JSONExtractor 容错提取 Fuzz 测试

    func testJSONExtractor_FuzzTruncatedAndDamagedJSON() {
        let corruptJSONs: [String] = [
            "{\"title\": \"未闭合字符串",
            "{\"items\": [1, 2, 3,",
            "```json\n{\"valid\": true}\n```",
            "```\n{\"wrapped\": \"code block\"}\n```",
            "纯文本非JSON内容",
            "{\"nested\": {\"deep\": {\"array\": [{\"a\": 1}]}}}",
            "   {\"id\": 1, \"name\": \"test\"}   "
        ]

        for json in corruptJSONs {
            _ = JSONExtractor.extractFirstJSONObject(from: json)
        }
    }

    // MARK: - 4. WikiLinkExtractor 双向链接抽取 Fuzz 测试

    func testWikiLinkExtractor_FuzzMalformedLinks() {
        let contents: [String] = [
            "这是一段包含 [[有效链接]] 的正文",
            "未闭合链接 [[未完成的双链",
            "空链接 [[]] 以及 [[   ]]",
            "带别名链接 [[架构设计|Architecture Guide]]",
            "多层嵌套 [[Link1 [[Link2]] Link3]]",
            "带特殊字符 [[深度学习/Transformer#Attention]]",
            String(repeating: "[[Link]] ", count: 200)
        ]

        for content in contents {
            let links = WikiLinkExtractor.extractLinks(from: content)
            XCTAssertNotNil(links)
        }
    }

    // MARK: - 5. MarkdownProcessor 语法解析 Fuzz 测试

    func testMarkdownProcessor_FuzzBlocksAndHeaders() {
        let markdownDoc = """
        # 一级标题
        ## 二级标题
        ```swift
        func test() {
            print("hello")
        // 未闭合代码块
        
        | 列一 | 列二 |
        | --- |
        | 畸变表格少一列 |
        
        > 引用块
        >> 二级嵌套引用
        
        - 列表 1
          - 子列表 A
        """

        let processor = MarkdownProcessor()
        let blocks = processor.parse(markdownDoc)
        XCTAssertFalse(blocks.isEmpty)
    }

    // MARK: - 6. ThinkingProcessor 思考链提取 Fuzz 测试

    func testThinkingProcessor_FuzzTags() {
        let streamContents: [String] = [
            "<think>正在思考知识拓扑...</think>这是回答正文",
            "<think>未闭合思考内容",
            "正文前缀 <think>中间思考</think> 正文后缀",
            "<thought>备用标签</thought>正文",
            "<reasoning>推理过程</reasoning>最终结论",
            String(repeating: "<think>嵌套", count: 10) + "正文"
        ]

        for content in streamContents {
            let result = ThinkingProcessor.process(content)
            XCTAssertNotNil(result.mainContent)
        }
    }
}
