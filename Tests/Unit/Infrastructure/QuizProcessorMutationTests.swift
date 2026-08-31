//
//  QuizProcessorMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[测试层]
//  核心职责：对 QuizProcessor.FlexibleAnswer.asIndex 进行边界变异测试。
//  该函数负责将 LLM 输出的答案索引（int 或 string 格式）转换为 [0, optionCount) 范围内的合法索引。
//  每个用例构造「若越界保护失效则 FAIL」的边界场景。
//

import XCTest
@testable import ZhiYu

@MainActor
final class QuizProcessorMutationTests: XCTestCase {

    // 类型别名，简化访问
    typealias FlexibleAnswer = QuizProcessor.FlexibleQuizShell.FlexibleAnswer

    // MARK: - 变异 Q1：负数 answerIndex 应被 clamp 为 0
    //
    // 危险点：`(i >= 0 && i < optionCount) ? i : 0`
    // 负数（如 -1）不满足 >= 0，应返回 0。
    // 若此测试 FAIL → Bug：负数索引未被保护，可能作为数组下标导致越界崩溃
    func testMutation_NegativeAnswerIndex_ClampedToZero() {
        let negativeValues = [-1, -100, -999, Int.min]

        for value in negativeValues {
            let answer = FlexibleAnswer.int(value)
            let result = answer.asIndex(optionCount: 4)
            XCTAssertEqual(
                result, 0,
                "负数 answerIndex(\(value)) 应被 clamp 为 0，实际返回 \(result) → 越界未保护"
            )
            XCTAssertGreaterThanOrEqual(result, 0, "返回值不应为负数")
        }
    }

    // MARK: - 变异 Q2：answerIndex 等于 optionCount（越界）应返回 0
    //
    // 危险点：`i < optionCount` 是严格小于，等于时应返回 0。
    // 若此测试 FAIL → Bug：越界判断用了 <= 而非 <
    func testMutation_AnswerIndexEqualsCount_ClampedToZero() {
        let optionCount = 4
        let answer = FlexibleAnswer.int(optionCount) // index == count → 越界

        let result = answer.asIndex(optionCount: optionCount)
        XCTAssertEqual(
            result, 0,
            "answerIndex == optionCount 应越界返回 0，实际 \(result) → 边界判断为 <= 而非 <"
        )
    }

    // MARK: - 变异 Q3：字母答案 "B" 但只有 1 个选项
    //
    // 危险点：`if trimmed.hasPrefix("B") { return min(1, optionCount - 1) }`
    // optionCount=1 时，min(1, 0)=0，正确行为是返回 0。
    // 若此测试 FAIL → Bug：min() 保护缺失，直接返回 1 导致数组越界
    func testMutation_LetterAnswerBWithOneOption_ClampedToZero() {
        let answer = FlexibleAnswer.string("B")
        let result = answer.asIndex(optionCount: 1)
        XCTAssertEqual(
            result, 0,
            "B 答案在只有 1 个选项时应返回 0（clamp），实际 \(result) → min() 保护失效"
        )
    }

    // MARK: - 变异 Q4：optionCount 为 0 —— guard 保护路径
    //
    // 危险点：`guard optionCount > 0 else { return 0 }`
    // 若 guard 被删除，后续计算 i < optionCount 在 optionCount=0 时 i 永远 < 0，
    // 会导致意外的返回值。
    // 若此测试 FAIL → Bug：guard 被错误移除，optionCount=0 时返回非 0 值
    func testMutation_ZeroOptionCount_AlwaysReturnsZero() {
        let answers: [FlexibleAnswer] = [
            .int(0), .int(1), .int(-1), .string("A"), .string("B"), .string("0"), .string("99")
        ]

        for answer in answers {
            let result = answer.asIndex(optionCount: 0)
            XCTAssertEqual(
                result, 0,
                "optionCount=0 时任何答案都应返回 0，answer=\(answer) 实际返回 \(result)"
            )
        }
    }

    // MARK: - 变异 Q5：字符串数字越界 —— "100" with optionCount=4
    //
    // 危险点：`if let i = Int(trimmed) { return (i >= 0 && i < optionCount) ? i : 0 }`
    // "100" → i=100，100 >= 4，应返回 0。
    // 若此测试 FAIL → Bug：字符串路径的数字未进行范围校验
    func testMutation_StringNumericOutOfBounds_ClampedToZero() {
        let outOfBoundAnswers = ["100", "4", "99", "-1", "1000"]

        for strAnswer in outOfBoundAnswers {
            let answer = FlexibleAnswer.string(strAnswer)
            let result = answer.asIndex(optionCount: 4)
            XCTAssertEqual(
                result, 0,
                "字符串数字越界答案 '\(strAnswer)' 应返回 0，实际 \(result) → 字符串路径越界未保护"
            )
        }
    }

    // MARK: - 变异 Q6：混合大小写字母 —— uppercased 是否正确应用
    //
    // 危险点：`let trimmed = s.trimmingCharacters(in:).uppercased()`
    // 若 uppercased() 在某条路径被遗漏，小写 "b" 不会匹配 hasPrefix("B")，返回默认 0。
    // 若此测试 FAIL → Bug：小写字母未被 uppercased 处理，答案解析错误
    func testMutation_LowerCaseLetterAnswers_MatchUpperCaseBranch() {
        struct TestCase {
            let input: String
            let optionCount: Int
            let expected: Int
            let desc: String
        }

        let cases: [TestCase] = [
            TestCase(input: "b", optionCount: 3, expected: 1, desc: "小写 b 应匹配 B 分支，返回 1"),
            TestCase(input: "c", optionCount: 4, expected: 2, desc: "小写 c 应匹配 C 分支，返回 2"),
            TestCase(input: "d", optionCount: 4, expected: 3, desc: "小写 d 应匹配 D 分支，返回 3"),
            TestCase(input: "a", optionCount: 4, expected: 0, desc: "小写 a 应匹配 A 分支，返回 0"),
            TestCase(input: "B", optionCount: 3, expected: 1, desc: "大写 B 应匹配 B 分支，返回 1")
        ]

        for item in cases {
            let answer = FlexibleAnswer.string(item.input)
            let result = answer.asIndex(optionCount: item.optionCount)
            XCTAssertEqual(result, item.expected, "\(item.desc)，实际返回 \(result) → uppercased() 可能未应用")
        }
    }

    // MARK: - 变异 Q7："D" 答案只有 3 个选项（min 保护）
    //
    // D → index=3，但 optionCount=3 时 min(3, 2)=2。
    func testMutation_LetterDWithThreeOptions_ClampedToTwo() {
        let answer = FlexibleAnswer.string("D")
        let result = answer.asIndex(optionCount: 3)
        XCTAssertEqual(
            result, 2,
            "D 答案在 3 个选项时应 clamp 为 2（index 2），实际 \(result) → min 保护可能失效"
        )
        XCTAssertLessThan(result, 3, "返回值不应越界（>= optionCount）")
    }

    // MARK: - 变异 Q8：空字符串答案 —— 应返回默认 0
    //
    // 危险点：空字符串 uppercased() 还是空，不匹配任何前缀，
    // 数字解析也失败，应走到最后 `return 0`。
    func testMutation_EmptyStringAnswer_ReturnsDefault() {
        let emptyAnswers = ["", " ", "\t", "\n", "   "]

        for strAnswer in emptyAnswers {
            let answer = FlexibleAnswer.string(strAnswer)
            let result = answer.asIndex(optionCount: 4)
            XCTAssertEqual(
                result, 0,
                "空/空白字符串答案 '\(strAnswer.debugDescription)' 应返回默认 0，实际 \(result)"
            )
        }
    }
}
