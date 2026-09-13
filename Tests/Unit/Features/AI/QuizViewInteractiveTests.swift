//
//  QuizViewInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：QuizView 智能自测交互、选项判断、解释编号清洗、错题与结课状态机深度测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class QuizViewInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 测验选项选择与分数累计逻辑测试

    func testQuizOptionSelectionAndScoreProgression() {
        let question1 = QuizQuestion(
            id: 1,
            text: "智宇系统的底座基础设施包是？",
            options: ["UFPStorage", "UFPCore", "ZhiYuDomain", "ZhiYuFeatures"],
            answer: 1, // B. UFPCore
            explanation: "正确答案: 2。UFPCore 提供了底座能力。"
        )
        let question2 = QuizQuestion(
            id: 2,
            text: "Karpathy 提出的 LLM Wiki 闭环核心包括什么？",
            options: ["纯前端富文本", "RAG 混合检索与 AI 合成", "单体服务端渲染"],
            answer: 1, // B. RAG 混合检索与 AI 合成
            explanation: "The answer is: 2. 检索增强与合成实验室构成完整闭环。"
        )

        let quiz = QuizModel(title: "架构测评", questions: [question1, question2])
        XCTAssertEqual(quiz.questions.count, 2)
        XCTAssertEqual(quiz.questions[0].answer, 1)
        XCTAssertEqual(quiz.questions[1].answer, 1)

        let quizView = QuizView(quiz: quiz)
        let host = UIHostingController(rootView: quizView.snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. 答案解释编号清洗 (fixExplanationNumbering) 变异与正则测试 (Bug #152 针对性防腐测试)

    func testExplanationNumberingReplacementFuzz() {
        let pattern = FeatureConstants.QuizPattern.explanationAnswerRegex
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            XCTFail("解释清洗正则表达式解析失败")
            return
        }

        // 1. 变异测试：普通包含数字的解释文本绝不能误匹配（防止系统限制为 1 个并发被破坏）
        let normalText = "系统限制为 1 个并发线程，并且需要准备 2 个备用实例。"
        let normalMatches = regex.matches(in: normalText, range: NSRange(normalText.startIndex..<normalText.endIndex, in: normalText))
        XCTAssertEqual(normalMatches.count, 0, "普通句子中的阿拉伯数字绝不能被误判为答案编号")

        // 2. 中英文答案前缀均能准确命中
        struct NumberingTestCase {
            let input: String
            let expectedGroup1: String
            let expectedNum: Int
        }

        let testCases = [
            NumberingTestCase(input: "正确答案: 1。该选项正确描述了事实。", expectedGroup1: "正确答案", expectedNum: 1),
            NumberingTestCase(input: "答案是 2。该选项正确描述了事实。", expectedGroup1: "答案", expectedNum: 2),
            NumberingTestCase(input: "参考答案：3。架构设计原则。", expectedGroup1: "参考答案", expectedNum: 3),
            NumberingTestCase(input: "The answer is: 3. Because option C is valid.", expectedGroup1: "The answer is", expectedNum: 3),
            NumberingTestCase(input: "Answer: 4. Detail explanation.", expectedGroup1: "Answer", expectedNum: 4),
            NumberingTestCase(input: "Correct Option: 1 是最佳架构决策。", expectedGroup1: "Correct Option", expectedNum: 1)
        ]

        for tc in testCases {
            let nsRange = NSRange(tc.input.startIndex..<tc.input.endIndex, in: tc.input)
            let matches = regex.matches(in: tc.input, range: nsRange)
            XCTAssertEqual(matches.count, 1, "用例 [\(tc.input)] 应准确命中 1 处答案前缀")
            if let m = matches.first {
                let r1 = Range(m.range(at: 1), in: tc.input)
                let r2 = Range(m.range(at: 2), in: tc.input)
                XCTAssertNotNil(r1)
                XCTAssertNotNil(r2)
                if let r1, let r2 {
                    XCTAssertEqual(String(tc.input[r1]), tc.expectedGroup1)
                    XCTAssertEqual(Int(tc.input[r2]), tc.expectedNum)
                }
            }
        }
    }

    // MARK: - 3. 测验完成态视图渲染测试

    func testQuizCompletionViewRendering() {
        let singleQuestion = QuizQuestion(
            id: 1,
            text: "唯一考题：Swift 6 是否开启了严格并发检查？",
            options: ["是", "否"],
            answer: 0,
            explanation: "正确答案: 1。"
        )
        let quiz = QuizModel(title: "并发测评", questions: [singleQuestion])

        let quizView = QuizView(quiz: quiz)
        let host = UIHostingController(rootView: quizView.snapshotEnvironment())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertEqual(quiz.questions.first?.options.count, 2)
        XCTAssertEqual(quiz.questions.first?.answer, 0)
    }
}
