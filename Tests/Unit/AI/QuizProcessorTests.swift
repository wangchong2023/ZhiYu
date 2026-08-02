//
//  QuizProcessorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 QuizProcessor 的测验数据解析与格式转换功能开展单元测试。
//

import XCTest
@testable import ZhiYu

final class QuizProcessorTests: XCTestCase {

    // MARK: - canDecodeAsQuizModel

    func testCanDecodeAsQuizModel_validJSON() {
        let json = """
        {
            "title": "Test Quiz",
            "questions": [
                {
                    "text": "Q1",
                    "options": ["A", "B", "C", "D"],
                    "answer": 0
                }
            ]
        }
        """
        XCTAssertTrue(QuizProcessor.canDecodeAsQuizModel(json))
    }

    func testCanDecodeAsQuizModel_withMarkdownFence() {
        let json = """
        ```json
        {
            "title": "T",
            "questions": [{"text": "Q", "options": ["A"], "answer": 0}]
        }
        ```
        """
        XCTAssertTrue(QuizProcessor.canDecodeAsQuizModel(json))
    }

    func testCanDecodeAsQuizModel_invalidJSON() {
        XCTAssertFalse(QuizProcessor.canDecodeAsQuizModel("not json"))
    }

    func testCanDecodeAsQuizModel_emptyJSON() {
        XCTAssertFalse(QuizProcessor.canDecodeAsQuizModel("{}"))
    }

    func testCanDecodeAsQuizModel_missingQuestions() {
        let json = """
        {"title": "No Questions"}
        """
        XCTAssertFalse(QuizProcessor.canDecodeAsQuizModel(json))
    }

    func testCanDecodeAsQuizModel_emptyQuestions() {
        let json = """
        {"title": "T", "questions": []}
        """
        XCTAssertFalse(QuizProcessor.canDecodeAsQuizModel(json), "空题目列表的 JSON 不能判定为有效的 Quiz 测验文档")
    }

    // MARK: - convertJSONToMarkdown

    func testConvertJSONToMarkdown_basicConversion() throws {
        let json = """
        {
            "title": "历史测验",
            "questions": [
                {
                    "text": "哪一年？",
                    "options": ["1911", "1921", "1949", "1978"],
                    "answer": 2,
                    "explanation": "1949年建国"
                }
            ]
        }
        """
        let result = try XCTUnwrap(QuizProcessor.convertJSONToMarkdown(json))
        XCTAssertTrue(result.contains("历史测验"))
        XCTAssertTrue(result.contains("哪一年？"))
        XCTAssertTrue(result.contains("1911"))
        XCTAssertTrue(result.contains("1949年建国"))
    }

    func testConvertJSONToMarkdown_withStringAnswer() throws {
        let json = """
        {
            "title": "Quiz",
            "questions": [
                {
                    "text": "Q",
                    "options": ["A", "B"],
                    "answer": "1"
                }
            ]
        }
        """
        let result = try XCTUnwrap(QuizProcessor.convertJSONToMarkdown(json))
        XCTAssertTrue(result.contains(L10n.Quiz.correctAnswer))
    }

    func testConvertJSONToMarkdown_multipleQuestions() throws {
        let json = """
        {
            "title": "Multi",
            "questions": [
                {"text": "Q1", "options": ["A", "B"], "answer": 0},
                {"text": "Q2", "options": ["C", "D"], "answer": 1}
            ]
        }
        """
        let result = try XCTUnwrap(QuizProcessor.convertJSONToMarkdown(json))
        XCTAssertTrue(result.contains("Q1"))
        XCTAssertTrue(result.contains("Q2"))
    }

    func testConvertJSONToMarkdown_withMarkdownFence() throws {
        let json = """
        ```json
        {
            "title": "Fenced",
            "questions": [{"text": "Q", "options": ["A"], "answer": 0}]
        }
        ```
        """
        let result = try XCTUnwrap(QuizProcessor.convertJSONToMarkdown(json))
        XCTAssertTrue(result.contains("Fenced"))
    }

    func testConvertJSONToMarkdown_invalidJSON_returnsNil() {
        let result = QuizProcessor.convertJSONToMarkdown("bad data")
        XCTAssertNil(result)
    }

    func testConvertJSONToMarkdown_emptyJSON_returnsNil() {
        let result = QuizProcessor.convertJSONToMarkdown("{}")
        XCTAssertNil(result)
    }

    func testConvertJSONToMarkdown_noTitle() throws {
        let json = """
        {
            "questions": [{"text": "Q", "options": ["A"], "answer": 0}]
        }
        """
        let result = try XCTUnwrap(QuizProcessor.convertJSONToMarkdown(json))
        XCTAssertTrue(result.contains(L10n.Quiz.title))
    }
}
