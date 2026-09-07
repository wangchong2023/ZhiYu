//
//  JSONRepairProcessorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：测试 JSONRepairProcessor 的语法自愈修复功能（缺失括号、多余逗号、无引号 Key 等）。
//

import XCTest
import ZhiYuAICore
@testable import ZhiYu

final class JSONRepairProcessorTests: XCTestCase {

    func testRepairBrokenJSONWithUnclosedBrackets() {
        let broken = """
        {
            "quizTitle": "测试",
            "questions": [
                {
                    "id": 1,
                    "question": "什么是双向链接？",
                    "options": ["A", "B", "C", "D"]
        """

        let repaired = JSONRepairProcessor.repair(broken)
        XCTAssertTrue(repaired.hasSuffix("}]}"), "JSONRepairProcessor 应自动补齐未闭合的集合与对象括号")

        let model = QuizProcessor.parseToQuizModel(repaired)
        XCTAssertNotNil(model, "自动修复后的 JSON 应该能成功解析为 QuizModel")
        XCTAssertEqual(model?.title, "测试", "标题应正确提取")
        XCTAssertEqual(model?.questions.count, 1, "题目数量应为 1")
    }

    func testRepairTrailingCommasAndUnquotedKeys() {
        let broken = """
        {
            title: "演示",
            items: [1, 2, 3,],
        }
        """

        let repaired = JSONRepairProcessor.repair(broken)
        XCTAssertFalse(repaired.contains(",]"), "应移除数组尾部多余逗号")
        XCTAssertFalse(repaired.contains(",}"), "应移除对象尾部多余逗号")
        XCTAssertTrue(repaired.contains("\"title\":"), "未加引号的 key 应当被补齐双引号")
    }
}
