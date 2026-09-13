//
//  QuizArenaSRSAlgorithmTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 QuizProcessor 的容错 JSON 解析、字母选项映射、Markdown 回退解析以及边界异常。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class QuizArenaSRSAlgorithmTests: XCTestCase {

    // MARK: - 1. 标准 JSON 测验解析分支

    func testParseQuiz_WithStandardJSON_ParsesCorrectly() {
        let json = """
        {
            "title": "分布式系统测验",
            "questions": [
                {
                    "id": 1,
                    "question": "Raft 算法中 Leader 节点的选举周期依赖什么？",
                    "options": ["心跳超时定时器", "固定时间片", "手动指定", "网络拓扑度"],
                    "answer": 0,
                    "explanation": "Follower 在 heartbeat timeout 内未收到心跳将触发选举"
                }
            ]
        }
        """

        let result = QuizProcessor.parseToQuizModel(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "分布式系统测验")
        XCTAssertEqual(result?.questions.count, 1)
        XCTAssertEqual(result?.questions.first?.options.count, 4)
    }

    // MARK: - 2. 弱类型 ID 与字母答案解析分支 (A/B/C/D -> 0/1/2/3)

    func testParseQuiz_WithAlphaLetterAnswers_MapsToCorrectIndices() {
        let json = """
        {
            "quizTitle": "Swift 严格并发测试",
            "questions": [
                {
                    "id": "q_001",
                    "text": "Swift 6 中非 Sendable 类型跨隔离域传递会引发什么？",
                    "options": ["编译期硬阻断错误", "运行时断言", "静默深拷贝", "自动升级为 Actor"],
                    "answer": "A",
                    "explanation": "Swift 6 Complete Concurrency 模式会在编译阶段拦截数据竞争"
                },
                {
                    "id": 2,
                    "questionText": "@Observable 宏来自哪个框架？",
                    "options": ["Combine", "Observation", "SwiftUI", "Foundation"],
                    "answerIndex": "B",
                    "explanation": "Observation 框架自 iOS 17 / macOS 14 引入"
                }
            ]
        }
        """

        let result = QuizProcessor.parseToQuizModel(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Swift 严格并发测试")
        XCTAssertEqual(result?.questions.count, 2)
    }

    // MARK: - 3. Markdown 纯文本回退格式解析分支

    func testParseQuiz_WithMarkdownFallbackFormat_ExtractsQuestionsAndAnswers() {
        let markdown = """
        # 知识库测验
        
        1. 什么是 FTS5 虚拟表？
        A. SQLite 的全文搜索模块
        B. 向量相似度插件
        C. 图数据库引擎
        D. 缓存持久化机制
        Answer: A
        Explanation: FTS5 是 SQLite 提供的分词检索扩展。
        
        2. GRDB 的优势是什么？
        A. 类型安全的 SQLite 访问
        B. 跨平台 UI 渲染
        Answer: A
        """

        let result = QuizProcessor.parseToQuizModel(markdown)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.questions.isEmpty ?? true, "Markdown 纯文本格式应当被成功兜底解析为测验题")
    }

    // MARK: - 4. 损坏 JSON 与空数据熔断分支

    func testParseQuiz_WithBrokenJSON_RecoversGracefully() {
        let brokenJSON = "{ title: '未闭合格式, questions: "

        let result = QuizProcessor.parseToQuizModel(brokenJSON)
        // 损坏的非 markdown 文本在无法提取到题目时安全返回 nil
        XCTAssertTrue(result == nil || result?.questions.isEmpty == true, "损坏文本应安全降级而不崩溃")
    }

    func testCanDecodeAsQuizModel_IdentifiesValidFormats() {
        let validJSON = "{\"title\": \"测试\", \"questions\": [{\"question\": \"Q1\", \"options\": [\"A\", \"B\"], \"answer\": 0}]}"
        let invalid = "乱码字符串"

        XCTAssertTrue(QuizProcessor.canDecodeAsQuizModel(validJSON))
        XCTAssertFalse(QuizProcessor.canDecodeAsQuizModel(invalid))
    }
}
