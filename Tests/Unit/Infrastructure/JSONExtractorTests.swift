//
//  JSONExtractorTests.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

/// JSONExtractor 单元测试
/// 验证从 LLM 返回文本中提取 JSON 对象的边界场景
final class JSONExtractorTests: XCTestCase {

    // MARK: - extractFirstJSONObject

    /// 验证纯 JSON 文本提取
    func testExtractFirstJSONObjectFromPureJSON() {
        let text = #"{"key": "value"}"#
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertEqual(result, #"{"key": "value"}"#)
    }

    /// 验证从 markdown 代码块包裹的文本提取
    func testExtractFirstJSONObjectFromMarkdownCodeBlock() {
        let text = """
        ```json
        {"name": "test", "value": 42}
        ```
        """
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertEqual(result, #"{"name": "test", "value": 42}"#)
    }

    /// 验证嵌套 JSON 对象提取
    func testExtractFirstJSONObjectWithNestedObjects() {
        let text = #"{"outer": {"inner": {"deep": true}}}"#
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertEqual(result, #"{"outer": {"inner": {"deep": true}}}"#)
    }

    /// 验证字符串中包含花括号的转义处理
    func testExtractFirstJSONObjectWithBracesInString() {
        let text = #"{"text": "a { b } c", "count": 1}"#
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertEqual(result, #"{"text": "a { b } c", "count": 1}"#)
    }

    /// 验证字符串中包含转义双引号
    func testExtractFirstJSONObjectWithEscapedQuotes() {
        // Swift 字面量 "say \"hello\"" 对应 JSON 字符串值 say "hello"
        let text = #"{"text": "say \"hello\""}"#
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertNotNil(result)
        // 提取出的 JSON 字符串应包含转义后的引号
        XCTAssertTrue(result?.contains(#"\"hello\""#) == true)
    }

    /// 验证无 JSON 对象时返回 nil
    func testExtractFirstJSONObjectReturnsNilWhenNoBrace() {
        let text = "plain text without json"
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertNil(result)
    }

    /// 验证不完整的 JSON 对象返回 nil
    func testExtractFirstJSONObjectReturnsNilWhenUnclosed() {
        let text = #"{"key": "value""#
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertNil(result)
    }

    /// 验证从多段文本中提取第一个 JSON 对象
    func testExtractFirstJSONObjectPicksFirstFromMultiple() {
        let text = #"prefix {"first": 1} suffix {"second": 2}"#
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertEqual(result, #"{"first": 1}"#)
    }

    /// 验证空对象提取
    func testExtractFirstJSONObjectEmptyObject() {
        let text = "{}"
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertEqual(result, "{}")
    }

    /// 验证反斜杠在非字符串上下文不影响解析
    func testExtractFirstJSONObjectWithBackslashOutsideString() {
        let text = #"{"a": 1} \\ extra"#
        let result = JSONExtractor.extractFirstJSONObject(from: text)
        XCTAssertEqual(result, #"{"a": 1}"#)
    }

    // MARK: - extractJSONDictionary

    /// 验证从 markdown 代码块提取并解析为字典
    func testExtractJSONDictionaryFromMarkdownCodeBlock() {
        let text = """
        ```json
        {"name": "test", "count": 42}
        ```
        """
        let dict = JSONExtractor.extractJSONDictionary(from: text)
        XCTAssertEqual(dict["name"] as? String, "test")
        XCTAssertEqual(dict["count"] as? Int, 42)
    }

    /// 验证从普通 ``` 代码块提取
    func testExtractJSONDictionaryFromPlainCodeFence() {
        let text = """
        ```
        {"key": "value"}
        ```
        """
        let dict = JSONExtractor.extractJSONDictionary(from: text)
        XCTAssertEqual(dict["key"] as? String, "value")
    }

    /// 验证无效 JSON 返回空字典
    func testExtractJSONDictionaryReturnsEmptyOnInvalidJSON() {
        let dict = JSONExtractor.extractJSONDictionary(from: "not json at all")
        XCTAssertTrue(dict.isEmpty)
    }

    /// 验证嵌套字典解析
    func testExtractJSONDictionaryWithNestedDictionary() {
        let text = #"{"outer": {"inner": "value"}}"#
        let dict = JSONExtractor.extractJSONDictionary(from: text)
        let outer = dict["outer"] as? [String: Any]
        XCTAssertEqual(outer?["inner"] as? String, "value")
    }

    /// 验证数组值解析
    func testExtractJSONDictionaryWithArrayValue() {
        let text = #"{"items": [1, 2, 3]}"#
        let dict = JSONExtractor.extractJSONDictionary(from: text)
        XCTAssertEqual(dict["items"] as? [Int], [1, 2, 3])
    }
}
