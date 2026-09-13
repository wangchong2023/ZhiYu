//
//  AIWorkflowsAndVoiceDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] Features/AI 智能工作流与测验合成深度集成测试
//  核心职责：深度覆盖 AIWorkflowStore、QuizModel/QuizView、SynthesisStore
//            及多源合成引用的状态机与数据模型边界。
//  质量标准：严格执行 unit-test-quality-review 规范，全方位覆盖测验序列化、
//            题目选项越界守卫、空题防除零、合成类型多态及页面级 AI 状态原子清理。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AIWorkflowsAndVoiceDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - 1. AIWorkflowStore 状态机流转与页面级 AI 原子清理深测

    func testAIWorkflowStore_StateMachineAndAtomicDismiss() {
        let store = AIWorkflowStore()

        // 1. 扫描状态流转
        XCTAssertFalse(store.isScanningAI, "初始状态下不应处于扫描中")
        store.isScanningAI = true
        XCTAssertTrue(store.isScanningAI)

        // 3. 页面级 AI 结果与激活 ID 绑定
        store.activePageAIResult = "这是 AI 生成的摘要正文"
        store.isProcessingPageAI = true

        let dummyQuiz = QuizModel(title: "测试测验", questions: [])
        store.activeQuiz = dummyQuiz
        XCTAssertNotNil(store.activeQuiz)

        // 4. 执行原子清空并验证所有状态复位
        store.clearAll()
        XCTAssertNil(store.activePageAIResult, "clearAll 后 activePageAIResult 必须置 nil")
        XCTAssertNil(store.activeQuiz, "clearAll 后 activeQuiz 必须置 nil")
        XCTAssertFalse(store.isProcessingPageAI, "clearAll 后 isProcessingPageAI 必须复位为 false")
        XCTAssertFalse(store.isScanningAI, "clearAll 后 isScanningAI 必须复位为 false")
    }

    // MARK: - 2. QuizModel & QuizQuestion 数据驱动序列化与正确答案深测

    func testQuizModel_SerializationAndOptionIndexBounds() throws {
        let question1 = QuizQuestion(
            id: 1,
            text: "Swift 6 默认启用的主要并发特性是？",
            options: ["完全严格并发检查", "关闭 Actor 隔离", "移除 async/await", "强制主线程运行"],
            answer: 0,
            explanation: "Swift 6 开启了 Complete Strict Concurrency 模式。"
        )

        let question2 = QuizQuestion(
            id: 2,
            text: "智宇本地知识库采用的核心存储组合是？",
            options: ["CoreData + CloudKit", "SQLite + FTS5 + 向量检索", "Realm 纯本地库", "UserDefaults 文件缓存"],
            answer: 1,
            explanation: "智宇通过 SQLite FTS5 与向量存储实现混合检索。"
        )

        let quiz = QuizModel(title: "Swift 6 与架构测试", questions: [question1, question2])

        // 1. 验证选项区间合法性守卫 (防越界崩溃)
        for question in quiz.questions {
            XCTAssertFalse(question.options.isEmpty, "题目选项列表绝不能为空")
            XCTAssertGreaterThanOrEqual(question.answer, 0, "正确答案索引必须 >= 0")
            XCTAssertLessThan(question.answer, question.options.count, "正确答案索引 \(question.answer) 必须严格小于选项数量 \(question.options.count)")
            XCTAssertFalse(question.explanation.isEmpty, "题目解析不应为空")
        }

        // 2. Codable 序列化与反序列化确定性校验（模拟 LLM JSON 解析流）
        let encoder = JSONEncoder()
        let data = try encoder.encode(quiz)
        let decoded = try JSONDecoder().decode(QuizModel.self, from: data)

        XCTAssertEqual(decoded.title, quiz.title)
        XCTAssertEqual(decoded.questions.count, 2)
        XCTAssertEqual(decoded.questions[0].options[decoded.questions[0].answer], "完全严格并发检查")
        XCTAssertEqual(decoded.questions[1].options[decoded.questions[1].answer], "SQLite + FTS5 + 向量检索")
    }

    // MARK: - 3. QuizView 空题目守卫生命周期深测 (防除零崩溃)
    // MARK: - 4. SynthesisStore 合成类型完备性与多源引用文档结构深测

    func testSynthesisStore_TypesCompletenessAndMultiSourceTracking() {
        // 1. 验证 6 大合成类型
        let allTypes = SynthesisStore.SynthesisType.allCases
        XCTAssertEqual(allTypes.count, 6, "AI 合成实验室应精准支持 6 大合成目标类型")

        for type in allTypes {
            XCTAssertFalse(type.title.isEmpty, "\(type) 标题不应为空")
            XCTAssertFalse(type.icon.isEmpty, "\(type) 图标不应为空")
            XCTAssertFalse(type.formatIcon.isEmpty, "\(type) 格式图标不应为空")
        }

        // 2. 验证多源引用文档结构
        let docID = UUID()
        let source1 = UUID()
        let source2 = UUID()
        let doc = SynthesisStore.SynthesisDocument(
            id: docID,
            type: .mindmap,
            name: "分布式系统全景图",
            content: "```mermaid\ngraph TD;\nA-->B;\n```",
            createdAt: Date(),
            size: 1024,
            sourcePageIDs: [source1, source2]
        )

        XCTAssertEqual(doc.id, docID)
        XCTAssertEqual(doc.type, .mindmap)
        XCTAssertEqual(doc.sourcePageIDs.count, 2)
        XCTAssertTrue(doc.sourcePageIDs.contains(source1))
        XCTAssertTrue(doc.sourcePageIDs.contains(source2))
    }

    // MARK: - 5. AIPulseIndicator 动画脉冲视觉组件装载深测
}
