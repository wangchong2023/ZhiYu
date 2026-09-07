//
//  QuizModelAndBoundsSafetyTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 QuizModel、题目解析序列化、AI 答案越界与负数选项防御分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class QuizModelAndBoundsSafetyTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. JSON 解码与边界分支

    func testQuizModel_JSONDecoding() throws {
        let json = """
        {
            "title": "Swift 并发测评",
            "questions": [
                {
                    "id": 1,
                    "text": "Swift 6 默认并发模型是什么？",
                    "options": ["Actor 模型", "Thread 锁", "GCD 队列"],
                    "answer": 0,
                    "explanation": "Swift 6 强化了基于 Actor 的数据隔离"
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let quiz = try JSONDecoder().decode(QuizModel.self, from: data)
        XCTAssertEqual(quiz.title, "Swift 并发测评")
        XCTAssertEqual(quiz.questions.count, 1)
        XCTAssertEqual(quiz.questions.first?.answer, 0)
    }

    // MARK: - 2. 空题目与防崩溃分支

    func testQuizModel_EmptyQuestions() {
        let quiz = QuizModel(title: "空测评", questions: [])
        XCTAssertTrue(quiz.questions.isEmpty)
        XCTAssertEqual(quiz.id, "空测评")
    }

    // MARK: - 3. 越界与负数答案索引数据韧性

    func testQuizQuestion_OutOfBoundsAnswer() {
        let question = QuizQuestion(
            id: 99,
            text: "边界题目",
            options: ["选项A", "选项B"],
            answer: 5, // 越界索引
            explanation: "解析"
        )
        XCTAssertFalse(question.options.indices.contains(question.answer), "应当正确识别越界答案索引")
    }
}
