//
//  LLMUtilsTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LLMUtils 工具集开展自动化单元测试。
//

import XCTest
@testable import ZhiYu

final class LLMUtilsTests: XCTestCase {

    // MARK: - stripMarkdown

    func testStripMarkdown_removesJSONCodeFence() {
        let input = "```json\n[\"a\", \"b\"]\n```"
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "[\"a\", \"b\"]")
    }

    func testStripMarkdown_removesGenericCodeFence() {
        let input = "```\nhello\n```"
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "hello")
    }

    func testStripMarkdown_trimsWhitespace() {
        let input = "  \n  some content  \n  "
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "some content")
    }

    func testStripMarkdown_noopOnPlainText() {
        let input = "plain text without fences"
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "plain text without fences")
    }

    func testStripMarkdown_emptyString() {
        let input = ""
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "")
    }

    // MARK: - parseJSONArray

    func testParseJSONArray_validJSON() {
        let input = "[\"apple\", \"banana\", \"cherry\"]"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, ["apple", "banana", "cherry"])
    }

    func testParseJSONArray_withMarkdownFence() {
        let input = "```json\n[\"a\", \"b\"]\n```"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, ["a", "b"])
    }

    func testParseJSONArray_emptyArray() {
        let input = "[]"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, [])
    }

    func testParseJSONArray_invalidJSON_returnsEmpty() {
        let input = "not valid json"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, [])
    }

    func testParseJSONArray_nonArrayJSON_returnsEmpty() {
        let input = "\"just a string\""
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, [])
    }

    func testParseJSONArray_singleElement() {
        let input = "[\"only\"]"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, ["only"])
    }

    // MARK: - parseSmartIngest

    func testParseSmartIngest_validJSON() {
        let json = """
        {
            "title": "Test Title",
            "compiled_content": "some content",
            "suggested_tags": ["tag1", "tag2"],
            "suggested_type": "concept",
            "related_titles": ["Related"],
            "summary": "A summary"
        }
        """
        let result = LLMUtils.parseSmartIngest(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Test Title")
        XCTAssertEqual(result?.suggestedTags, ["tag1", "tag2"])
        XCTAssertEqual(result?.suggestedType, "concept")
    }

    func testParseSmartIngest_withMarkdownFence() {
        let json = """
        ```json
        {
            "title": "Fenced",
            "compiled_content": "c",
            "suggested_tags": [],
            "suggested_type": "entity",
            "related_titles": [],
            "summary": "s"
        }
        ```
        """
        let result = LLMUtils.parseSmartIngest(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Fenced")
    }

    func testParseSmartIngest_invalidJSON_returnsNil() {
        let result = LLMUtils.parseSmartIngest("not json")
        XCTAssertNil(result)
    }

    func testParseSmartIngest_missingFields_returnsNil() {
        let json = """
        {
            "title": "Incomplete"
        }
        """
        let result = LLMUtils.parseSmartIngest(json)
        XCTAssertNil(result)
    }

    // MARK: - parseRefactorSuggestions

    func testParseRefactorSuggestions_validJSON() {
        let json = """
        [
            {
                "type": "merge",
                "target": "PageA",
                "reason": "duplicate",
                "suggestion": "merge into PageB"
            }
        ]
        """
        let result = LLMUtils.parseRefactorSuggestions(json)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.type, "merge")
        XCTAssertEqual(result.first?.target, "PageA")
    }

    func testParseRefactorSuggestions_emptyArray() {
        let result = LLMUtils.parseRefactorSuggestions("[]")
        XCTAssertTrue(result.isEmpty)
    }

    func testParseRefactorSuggestions_invalidJSON_returnsEmpty() {
        let result = LLMUtils.parseRefactorSuggestions("bad data")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - extractContent

    func testExtractContent_standardModel() {
        let response: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "content": "Hello, world!"
                    ]
                ]
            ]
        ]
        let result = LLMUtils.extractContent(from: response)
        XCTAssertEqual(result, "Hello, world!")
    }

    func testExtractContent_reasoningModel() {
        let response: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "reasoning_content": "Deep reasoning output"
                    ]
                ]
            ]
        ]
        let result = LLMUtils.extractContent(from: response)
        XCTAssertEqual(result, "Deep reasoning output")
    }

    func testExtractContent_prioritizesContentOverReasoning() {
        let response: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "content": "Standard output",
                        "reasoning_content": "Internal reasoning"
                    ]
                ]
            ]
        ]
        let result = LLMUtils.extractContent(from: response)
        XCTAssertEqual(result, "Standard output")
    }

    func testExtractContent_noChoices_returnsNil() {
        let response: [String: Any] = [:]
        let result = LLMUtils.extractContent(from: response)
        XCTAssertNil(result)
    }

    func testExtractContent_emptyChoices_returnsNil() {
        let response: [String: Any] = ["choices": []]
        let result = LLMUtils.extractContent(from: response)
        XCTAssertNil(result)
    }

    func testExtractContent_noMessage_returnsNil() {
        let response: [String: Any] = [
            "choices": [
                ["something": "else"]
            ]
        ]
        let result = LLMUtils.extractContent(from: response)
        XCTAssertNil(result)
    }

    func testExtractContent_neitherContentNorReasoning() {
        let response: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "role": "assistant"
                    ]
                ]
            ]
        ]
        let result = LLMUtils.extractContent(from: response)
        XCTAssertNil(result)
    }
}
