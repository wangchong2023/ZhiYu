//
//  SynthesisAndQuizProcessorsDeepBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：针对知识合成处理器（SynthesisProcessor）与测验解析引擎（QuizProcessor）
//            进行全分支边界、畸变输入、正则匹配与 Markdown 清洗的深度测试。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class SynthesisAndQuizProcessorsDeepTests: XCTestCase {

    // MARK: - 1. SynthesisProcessor Mermaid 与文本清洗深层分支

    func testSynthesisProcessor_MermaidFormatting_Branches() {
        // 空输入
        let emptyResult = SynthesisProcessor.formatMermaid("", fallbackPrefix: "graph TD")
        XCTAssertTrue(emptyResult.isEmpty)

        // 包含已知图表语法
        let flowchart = """
        ```mermaid
        ---
        title: System Flow
        ---
        flowchart TD
            A --> B
        ```
        """
        let formatted = SynthesisProcessor.formatMermaid(flowchart, fallbackPrefix: "graph TD")
        XCTAssertTrue(formatted.contains("flowchart TD") || formatted.contains("A --> B"))

        // 无标题直接代码
        let rawCode = "graph LR\n  X --> Y"
        let res2 = SynthesisProcessor.formatMermaid(rawCode, fallbackPrefix: "graph TD")
        XCTAssertFalse(res2.isEmpty)

        // 畸变无头内容，触发 fallbackPrefix
        let fallbackCode = "node1 --> node2"
        let fallbackRes = SynthesisProcessor.formatMermaid(fallbackCode, fallbackPrefix: "graph TD")
        XCTAssertTrue(fallbackRes.contains("graph TD"))
    }

    func testSynthesisProcessor_SanitizeSourceLines_FiltersPromptKeywords() {
        let dirtyContent = """
        ```swift
        ```
        Source: http://example.com
        Requirements: Strict
        ---
        核心架构设计第一章
        """
        let lines = SynthesisProcessor.sanitizeSourceLines(dirtyContent)
        XCTAssertEqual(lines, ["核心架构设计第一章"])
    }

    func testSynthesisProcessor_SanitizeMermaidSyntax() {
        let rawMermaid = "```mermaid\ngraph TD\n  A[Node (Special)] --> B[Target]\n```"
        let formatted = SynthesisProcessor.formatMermaid(rawMermaid, fallbackPrefix: "graph TD")
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("graph TD") || formatted.contains("Node"))
    }

    // MARK: - 2. QuizProcessor 测验解析多结构反序列化与答案匹配

    func testQuizProcessor_FlexibleJsonParsing_AllShapes() {
        // 结构 1: 标准 JSON 测验
        let jsonStandard = """
        {
            "quizTitle": "Swift 6 并发模型考题",
            "questions": [
                {
                    "id": "q1",
                    "question": "Actor 的核心作用是什么？",
                    "options": ["数据隔离与消除竞态", "加速网络请求", "管理内存分配", "替代GCD"],
                    "answer": 0,
                    "explanation": "Actor 通过隔离可变状态防止并发数据竞争。"
                }
            ]
        }
        """
        let parsedStandard = QuizProcessor.parseToQuizModel(jsonStandard)
        XCTAssertNotNil(parsedStandard)
        XCTAssertEqual(parsedStandard?.questions.count, 1)
        if let question = parsedStandard?.questions.first {
            XCTAssertEqual(question.options[question.answer], "数据隔离与消除竞态")
        }

        // 结构 2: 字符串答案 "A" / "B" 变体与转 Markdown 格式化
        let jsonLetterAnswer = """
        {
            "title": "计算机基础测验",
            "questions": [
                {
                    "id": 101,
                    "questionText": "HTTP 200 表示什么？",
                    "options": ["请求成功", "资源未找到", "服务器错误", "重定向"],
                    "answer": "A",
                    "explanation": "200 OK"
                }
            ]
        }
        """
        let parsedLetters = QuizProcessor.parseToQuizModel(jsonLetterAnswer)
        XCTAssertNotNil(parsedLetters)
        if let question = parsedLetters?.questions.first {
            XCTAssertEqual(question.options[question.answer], "请求成功")
        }

        let mdConverted = QuizProcessor.convertJSONToMarkdown(jsonLetterAnswer)
        XCTAssertNotNil(mdConverted)
        XCTAssertTrue(mdConverted?.contains("HTTP 200") == true)

        // 结构 3: 容错解析非标准 Markdown 测验
        let markdownQuiz = """
        # 基础测试
        1. 什么是 RAG？
        - 检索增强生成
        - 随机算法生成
        - 实时数据流
        - 递归注意力图
        <details>
        <summary>答案</summary>
        正确答案: 检索增强生成
        解析: Retrieval-Augmented Generation
        </details>
        """
        let fallbackQuiz = QuizProcessor.parseToQuizModel(markdownQuiz)
        XCTAssertNotNil(fallbackQuiz)
    }
}
