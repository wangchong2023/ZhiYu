//
//  JSONRepairProcessorTruncationTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 JSONRepairProcessor 对 LLM 流式截断 JSON 的自愈能力。
//           PartialJSON 第二层必须能补全不完整 JSON。
//

import XCTest
@testable import ZhiYuAICore

final class JSONRepairProcessorTruncationTests: XCTestCase {

    /// 截断的对象 JSON 必须被补全
    func testTruncatedObjectRepaired() {
        let input = #"{"key": "value", "key2": "val"#
        let result = JSONRepairProcessor.repair(input)
        // 必须能解析为有效 JSON
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "截断的 JSON 必须被补全为合法 JSON")
    }

    /// 截断的嵌套 JSON 必须被补全
    func testTruncatedNestedRepaired() {
        let input = #"{"outer": {"inner": "value", "list": [1, 2"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 截断的数组 JSON 必须被补全
    func testTruncatedArrayRepaired() {
        let input = #"[1, 2, 3, "#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 截断的字符串值必须被补全
    func testTruncatedStringValueRepaired() {
        let input = #"{"key": "truncated val"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 仅包含开括号 `{` 必须被补全为 `{}`
    func testOnlyOpenBraceRepaired() {
        let input = "{"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 包含垃圾前缀的 JSON 必须提取有效部分
    func testGarbagePrefixExtracted() {
        let input = #"garbage text {"key": "value"}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 包含垃圾后缀的 JSON 必须提取有效部分
    func testGarbageSuffixExtracted() {
        let input = #"{"key": "value"} trailing garbage"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    /// 完全损坏的输入必须返回非空字符串（不崩溃）
    func testCompletelyCorruptedReturnsNonEmpty() {
        let input = "this is not json at all !!!"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertFalse(result.isEmpty, "完全损坏的输入也必须返回非空字符串")
    }
}
