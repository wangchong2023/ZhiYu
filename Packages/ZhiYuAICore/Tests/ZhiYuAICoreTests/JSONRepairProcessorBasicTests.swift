//
//  JSONRepairProcessorBasicTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 JSONRepairProcessor.repair 的基础修复能力。
//           必须处理 Markdown 包裹、尾逗号、未加引号 key 等常见 LLM 输出缺陷。
//

import XCTest
@testable import ZhiYuAICore

final class JSONRepairProcessorBasicTests: XCTestCase {

    /// 合法 JSON 必须原样返回（仅 trim）
    func testValidJsonPreserved() {
        let input = #"{"key": "value"}"#
        let result = JSONRepairProcessor.repair(input)
        // 必须仍是合法 JSON
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// Markdown 代码块包裹必须被移除
    func testMarkdownCodeBlockRemoved() {
        let input = #"```json\n{"key": "value"}\n```"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertFalse(result.contains("```"))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 空字符串必须返回 "{}"
    func testEmptyStringReturnsEmptyObject() {
        let result = JSONRepairProcessor.repair("")
        XCTAssertEqual(result, "{}")
    }

    /// 纯空白字符串必须返回 "{}"
    func testWhitespaceOnlyReturnsEmptyObject() {
        let result = JSONRepairProcessor.repair("   \n\t  ")
        XCTAssertEqual(result, "{}")
    }

    /// 对象尾逗号 `,}` 必须被移除
    func testObjectTrailingCommaRemoved() {
        let input = #"{"key": "value",}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertFalse(result.contains(",}"))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 未加引号的 key 必须被补齐引号
    func testUnquotedKeyQuoted() {
        let input = "{key: \"value\"}"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertTrue(result.contains("\"key\""))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 多个未加引号 key 必须全部补齐
    func testMultipleUnquotedKeysQuoted() {
        let input = "{name: \"alice\", age: 30}"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertTrue(result.contains("\"name\""))
        XCTAssertTrue(result.contains("\"age\""))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 嵌套对象必须正确修复
    func testNestedObjectRepaired() {
        let input = #"{"outer": {"inner": "value",}}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 数组 JSON 必须正确处理
    func testArrayJsonHandled() {
        let input = #"[1, 2, 3]"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }
}
