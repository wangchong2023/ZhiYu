//
//  QuizViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：QuizView 快照测试，覆盖测评初始/答题中/结果展示各阶段状态。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class QuizViewSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 测试数据工厂

    /// 构造单题测评
    private func makeSingleQuestionQuiz() -> QuizModel {
        QuizModel(
            title: "Swift 基础知识测评",
            questions: [
                QuizQuestion(
                    id: 1,
                    text: "Swift 中哪个关键字用于声明常量？",
                    options: ["var", "let", "const", "final"],
                    answer: 1,
                    explanation: "let 用于声明不可变常量，var 用于声明可变变量。"
                )
            ]
        )
    }

    /// 构造多题测评
    private func makeMultiQuestionQuiz() -> QuizModel {
        QuizModel(
            title: "iOS 开发综合测评",
            questions: [
                QuizQuestion(id: 1, text: "SwiftUI 中哪个修饰符用于设置字体？", options: [".font()", ".textFont()", ".typeface()", ".style()"], answer: 0, explanation: ".font() 用于设置字体。"),
                QuizQuestion(id: 2, text: "以下哪个不是 Swift 的访问控制级别？", options: ["public", "private", "protected", "internal"], answer: 2, explanation: "Swift 没有 protected，有 open/public/internal/fileprivate/private。"),
                QuizQuestion(id: 3, text: "actor 类型的主要作用是？", options: ["数据持久化", "并发安全", "UI 渲染", "网络请求"], answer: 1, explanation: "actor 用于隔离可变状态，保障并发安全。")
            ]
        )
    }

    /// 构造空选项测评（边界测试 — 发现问题的目标）
    private func makeEmptyOptionsQuiz() -> QuizModel {
        QuizModel(
            title: "边界测试 — 空选项",
            questions: [
                QuizQuestion(id: 1, text: "此题目没有选项", options: [], answer: 0, explanation: "边界情况")
            ]
        )
    }

    // MARK: - QuizView 快照测试

    /// 测试单题测评初始状态
    func testQuizView_SingleQuestion_Initial() {
        let view = QuizView(quiz: makeSingleQuestionQuiz())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试多题测评初始状态
    func testQuizView_MultiQuestion_Initial() {
        let view = QuizView(quiz: makeMultiQuestionQuiz())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试空选项边界情况 — 应优雅降级而非崩溃
    func testQuizView_EmptyOptions_DegradedRendering() {
        let view = QuizView(quiz: makeEmptyOptionsQuiz())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
