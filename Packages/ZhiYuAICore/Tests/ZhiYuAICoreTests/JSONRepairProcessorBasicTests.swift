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

    /// 未闭合的括号必须自动补齐
    func testUnclosedBracketsAutoClosed() {
        let broken = """
        {
            "quizTitle": "demo",
            "questions": [
                {
                    "id": 1,
                    "question": "What is bidirectional link?",
                    "options": ["A", "B", "C", "D"]
        """

        let repaired = JSONRepairProcessor.repair(broken)
        XCTAssertTrue(repaired.hasSuffix("}]}"), "应自动补齐未闭合的集合与对象括号")
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(repaired.utf8)), "修复后应为合法 JSON")
    }

    // MARK: - 缺陷导向：字符串值内的 `, word:` / `{word:` 不应被误当作裸 key

    /// 缺陷验证：`quoteUnquotedKeys` 用正则 `(?<=,)(\s*)[A-Za-z_][A-Za-z0-9_]*(\s*):`
    /// 与 `(?<=\{)(\s*)[A-Za-z_][A-Za-z0-9_]*(\s*):` 全局替换，不区分字符串字面量上下文，
    /// 会把合法 JSON 字符串值内的 `, foo:` 误改写为 `, "foo":`，破坏原本合法的 JSON。
    /// 修复后字符串值内容应原样保留，且输出仍是合法 JSON。
    func testValidJson_stringValueWithCommaKeyColon_notCorrupted() {
        let input = #"{"text": "use, foo: bar"}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertTrue(result.contains(#""use, foo: bar""#),
            "字符串值 `, foo:` 不应被误当作裸 key 改写，实际输出：\(result)")
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
            "输出应为合法 JSON，实际：\(result)")
    }

    /// 字符串值内 `{key: val}` 模式（花括号 + 裸 key 形）不应被误改写
    func testValidJson_stringValueWithBraceKeyColon_notCorrupted() {
        let input = #"{"msg": "prefix{key: val} suffix"}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertTrue(result.contains(#""prefix{key: val} suffix""#),
            "字符串值 `{key: val}` 不应被误改写，实际输出：\(result)")
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
            "输出应为合法 JSON，实际：\(result)")
    }

    /// 字符串值内含转义引号时仍不应被误改写（状态机需正确处理 `\"`）
    func testValidJson_stringValueWithEscapedQuoteAndColon_notCorrupted() {
        let input = #"{"text": "he said \"hi, name: x\" ok"}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
            "含转义引号的字符串值不应被破坏，实际：\(result)")
    }

    /// 真实裸 key 仍应被正确补齐引号（回归：状态机保留原正则能力）
    func testUnquotedKeyInObjectWithNested_stillQuoted() {
        let input = #"{"outer": {inner: "value"}}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertTrue(result.contains(#""inner""#), "嵌套对象内的裸 key `inner` 应被补引号，实际：\(result)")
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }
}
