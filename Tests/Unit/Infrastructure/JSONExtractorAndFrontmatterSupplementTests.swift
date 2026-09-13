//
//  JSONExtractorAndFrontmatterSupplementTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：JSONExtractor 与 FrontmatterParser 补充测试 — JSON 提取、Frontmatter 分割与解析
//

import XCTest
import Foundation
import Dependencies
import UFPCore
@testable import ZhiYu

// MARK: - JSONExtractor 补充测试

final class JSONExtractorSupplementTests: XCTestCase {

    func testExtractFirstJSONObject_noBrace_returnsNil() {
        XCTAssertNil(JSONExtractor.extractFirstJSONObject(from: "no json here"))
    }

    func testExtractFirstJSONObject_simpleObject() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"key": "value"}"#)
        XCTAssertEqual(result, #"{"key": "value"}"#)
    }

    func testExtractFirstJSONObject_nestedObject() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"outer": {"inner": 1}}"#)
        XCTAssertEqual(result, #"{"outer": {"inner": 1}}"#)
    }

    func testExtractFirstJSONObject_unclosedBrace_returnsNil() {
        XCTAssertNil(JSONExtractor.extractFirstJSONObject(from: #"{"key": "value""#))
    }

    func testExtractFirstJSONObject_braceInString_notCounted() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"key": "val}ue"}"#)
        XCTAssertEqual(result, #"{"key": "val}ue"}"#)
    }

    func testExtractFirstJSONObject_escapedQuoteInString() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"key": "val\"ue"}"#)
        XCTAssertNotNil(result)
    }

    func testExtractJSONDictionary_validJSON_returnsDict() {
        let dict = JSONExtractor.extractJSONDictionary(from: #"{"name": "test", "count": 42}"#)
        XCTAssertEqual(dict["name"] as? String, "test")
        XCTAssertEqual(dict["count"] as? Int, 42)
    }

    func testExtractJSONDictionary_invalidJSON_returnsEmpty() {
        let dict = JSONExtractor.extractJSONDictionary(from: "not json at all")
        XCTAssertTrue(dict.isEmpty)
    }

    func testExtractJSONDictionary_codeFenceStripped() {
        let dict = JSONExtractor.extractJSONDictionary(from: "```json\n{\"key\": \"value\"}\n```")
        XCTAssertEqual(dict["key"] as? String, "value")
    }
}

// MARK: - FrontmatterParser 补充测试

final class FrontmatterParserSupplementTests: XCTestCase {

    func testSplit_noFrontmatter_returnsNilFrontmatter() {
        let result = FrontmatterParser.split(content: "plain text without frontmatter")
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "plain text without frontmatter")
    }

    func testSplit_validYAMLFrontmatter() {
        let content = "---\ntitle: Test\n---\nBody content"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNotNil(result.frontmatter)
        XCTAssertTrue(result.frontmatter?.contains("title: Test") == true)
        XCTAssertEqual(result.body, "Body content")
    }

    func testSplit_validJSONFrontmatter() {
        let content = "---json\n{\"title\": \"Test\"}\n---\nBody"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNotNil(result.frontmatter)
        XCTAssertEqual(result.body, "Body")
    }

    func testSplit_unclosedFrontmatter_returnsNil() {
        let content = "---\ntitle: Test\nNo closing delimiter"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    func testSplit_emptyFrontmatter_returnsNil() {
        let content = "---\n---\nBody"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "Body")
    }

    func testParse_validJSON_returnsModel() {
        let json = #"{"pronunciation": "test", "definition": "a test"}"#
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "test")
        XCTAssertEqual(result?.definition, "a test")
    }

    func testParse_invalidJSON_returnsDefaultModel() {
        // EntityFrontmatter 所有字段可选，"not json" 经 YAML 降级转为 {} 后解码成功
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: "not json")
        XCTAssertNotNil(result)
        XCTAssertNil(result?.pronunciation)
        XCTAssertNil(result?.definition)
    }

    func testParse_emptyString_returnsDefaultModel() {
        // 空字符串经 YAML 降级转为 {} 后解码成功，返回全 nil 的默认模型
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: "")
        XCTAssertNotNil(result)
        XCTAssertNil(result?.pronunciation)
    }
}
