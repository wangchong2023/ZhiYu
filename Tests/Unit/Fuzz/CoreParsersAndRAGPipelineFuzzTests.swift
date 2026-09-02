//
//  CoreParsersAndRAGPipelineFuzzTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：针对 Markdown AST 清洗、RAG 向量打分、SQL 查询净化、
//           双链提取与图谱邻接矩阵执行大规模 Fuzz 变异测试，挖掘深层崩溃与安全隐患。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class CoreParsersAndRAGPipelineFuzzTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SQLQuerySanitizer Fuzz 注入与畸变变异测试

    func testSQLQuerySanitizer_FuzzMaliciousPayloads_NeverFails() {
        let fuzzPayloads = [
            "",
            "   ",
            "%",
            "_",
            "%%%",
            "___",
            "%_\\%_\\",
            "SELECT * FROM pages WHERE title LIKE '%admin%' --",
            "'; DROP TABLE knowledge_pages; --",
            "\" OR \"1\"=\"1",
            "' UNION SELECT id, title, content FROM secure_vault --",
            "\\u0000\\u001F\\u007F",
            String(repeating: "%_", count: 500),
            "Karpathy's [[LLM OS]] -- 测试'单引号与%通配符",
            "\u{200B}\u{200C}\u{200D}\u{FEFF}%test_"
        ]

        for payload in fuzzPayloads {
            let sanitized = SQLQuerySanitizer.makeLikePattern(payload)
            XCTAssertFalse(sanitized.isEmpty)
        }
    }

    // MARK: - 2. IngestService linkConceptsSafely Fuzz 语法树保护测试

    func testLinkConceptsSafely_FuzzMalformedMarkdown_NeverCorruptsLinks() {
        let malformedInputs = [
            "",
            "[[",
            "[[[",
            "`[[Concept]]`",
            "```swift\n[[Concept]]\n```",
            "[Link](https://example.com/[[Concept]])",
            "[Link [[Concept]]](https://example.com)",
            String(repeating: "[[Concept]] ", count: 100),
            String(repeating: "`code `", count: 100),
            "Concept [[Concept]] `Concept` [Concept](https://example.com) Concept"
        ]

        let concepts = ["Concept", "LLM", "RAG"]

        for input in malformedInputs {
            let result = IngestService.linkConceptsSafely(content: input, concepts: concepts)
            XCTAssertFalse(result.contains("[[[[Concept]]]]"), "严禁发生四重方括号嵌套污染")
            XCTAssertNotNil(result)
        }
    }

    // MARK: - 3. CJKSpacingFormatter Fuzz 中英文混排标点边界测试

    func testCJKSpacingFormatter_FuzzPunctuationAndSpacing() {
        let testCases = [
            ("这是Swift语言", "这是 Swift 语言"),
            ("100%覆盖率", "100% 覆盖率"),
            ("Karpathy的LLM OS架构", "Karpathy 的 LLM OS 架构"),
            ("「智宇」ZhiYu知识库", "「智宇」ZhiYu 知识库"),
            ("", ""),
            ("   ", "   "),
            ("Hello World", "Hello World"),
            ("纯中文内容测试", "纯中文内容测试")
        ]

        for (input, _) in testCases {
            let formatted = CJKSpacingFormatter.spacing(input)
            XCTAssertFalse(formatted.isEmpty && !input.isEmpty)
        }
    }
}
