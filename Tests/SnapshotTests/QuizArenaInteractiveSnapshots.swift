//
//  QuizArenaInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：知识测评竞技场 (QuizView)、答题卡片与空状态的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class QuizArenaInteractiveSnapshots: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 空题库防除零保护态快照

    func testQuizView_EmptyQuestions_RendersUnavailableState() {
        let quiz = QuizModel(
            title: "空测评题库",
            questions: []
        )
        let view = QuizView(quiz: quiz)
            .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 正常答题卡片与选项排版渲染

    func testQuizView_AnsweringState_RendersQuestionAndOptions() {
        let questions = [
            QuizQuestion(
                id: 1,
                text: "在 Swift 6 并发模型中，非 Sendable 的单例静态实例应当如何声明以避免警告？",
                options: [
                    "标记为 nonisolated(unsafe)",
                    "使用 @unchecked Sendable 包装",
                    "使用 OSAllocatedUnfairLock 加锁",
                    "改为局部变量传递"
                ],
                answer: 0,
                explanation: "Swift 6 允许使用 nonisolated(unsafe) 标记单例避免严格并发阻断。"
            )
        ]
        let quiz = QuizModel(
            title: "Swift 6 并发深度自测",
            questions: questions
        )
        let view = QuizView(quiz: quiz)
            .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
