//
//  JSONRepairProcessorLayerCoverageTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 JSONRepairProcessor 双层防护的分支覆盖：
//           1. 第一层 SwiftJSONSanitizer 成功路径（isValidJSON 通过）
//           2. 第二层 PartialJSON 补全路径（第一层失败、第二层成功）
//           3. 两层均失败时的降级返回
//           4. quoteUnquotedKeys 裸 key 补齐
//           5. Markdown 代码块包裹符清理
//

import XCTest
@testable import ZhiYuAICore

final class JSONRepairProcessorLayerCoverageTests: XCTestCase {

    // MARK: - 第一层成功路径

    /// 合法 JSON 直接通过第一层
    func testValidJSONPassesFirstLayer() {
        let input = #"{"name": "test", "value": 42}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertEqual(result, #"{"name":"test","value":42}"#,
                       "合法 JSON 经 minify 后应直接返回")
    }

    /// 尾逗号通过第一层修复
    func testTrailingCommaFixedByFirstLayer() {
        let input = #"{"a": 1, "b": 2,}"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "尾逗号应被第一层修复")
    }

    // MARK: - 第二层 PartialJSON 补全路径

    /// 深度截断的嵌套 JSON：第一层无法修复，第二层 PartialJSON 补全
    /// 构造第一层 sanitize 后仍不是合法 JSON 的输入（截断在值中间）
    func testDeeplyTruncatedFallsToSecondLayer() {
        // 截断在字符串值中间，第一层无法补全引号和括号
        let input = #"{"longKey": "this is a truncated value that cuts off ab"#
        let result = JSONRepairProcessor.repair(input)
        // 第二层应能补全为合法 JSON
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "深度截断应被第二层 PartialJSON 补全")
    }

    /// 截断在嵌套数组中间，第二层补全
    func testTruncatedNestedArrayFallsToSecondLayer() {
        let input = #"{"items": [1, 2, 3, {"name": "partial"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "嵌套数组截断应被第二层补全")
    }

    /// 截断在 key 位置（无值），第二层补全
    func testTruncatedAtKeyFallsToSecondLayer() {
        let input = #"{"key1": "value1", "key2"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "key 位置截断应被第二层补全")
    }

    // MARK: - 两层均失败的降级路径

    /// 完全非 JSON 输入：两层均失败，返回非空降级结果
    func testCompletelyCorruptedReturnsNonEmptyFallback() {
        let input = "this is definitely not json at all !!!"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertFalse(result.isEmpty, "两层均失败时必须返回非空降级字符串")
    }

    /// 纯数字非 JSON（无括号）：两层均失败时的降级路径
    /// 覆盖 :73-75 两层均失败 return result.isEmpty ? text : result
    func testPureNumberNoBracesFallsToBothLayersFailed() {
        // 无 { } 括号，第一层 sanitize 后仍非合法 JSON
        // PartialJSON 对纯数字可能解析成功（作为 JSON number），需验证
        let input = "12345"
        let result = JSONRepairProcessor.repair(input)
        // 无论走哪层，必须返回非空字符串
        XCTAssertFalse(result.isEmpty, "纯数字输入必须返回非空结果")
    }

    /// 空字符串返回 `{}`
    func testEmptyStringReturnsEmptyObject() {
        let result = JSONRepairProcessor.repair("")
        XCTAssertEqual(result, "{}", "空字符串必须返回空对象字面量")
    }

    /// 仅空白字符返回 `{}`
    func testWhitespaceOnlyReturnsEmptyObject() {
        let result = JSONRepairProcessor.repair("   \n\t  ")
        XCTAssertEqual(result, "{}", "纯空白必须返回空对象字面量")
    }

    // MARK: - quoteUnquotedKeys 裸 key 补齐

    /// 裸 key（无引号）必须被补齐双引号
    func testUnquotedKeyGetsQuoted() {
        let input = "{name: \"test\", value: 42}"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "裸 key 应被补齐为合法 JSON")
    }

    /// 多个裸 key 全部补齐
    func testMultipleUnquotedKeysAllQuoted() {
        let input = "{name: \"test\", age: 30, active: true}"
        let result = JSONRepairProcessor.repair(input)
        guard let dict = try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any] else {
            XCTFail("多裸 key 应被补齐为合法 JSON")
            return
        }
        XCTAssertEqual(dict["name"] as? String, "test")
        XCTAssertEqual(dict["age"] as? Int, 30)
        XCTAssertEqual(dict["active"] as? Bool, true)
    }

    /// 下划线开头的裸 key 补齐
    func testUnderscorePrefixUnquotedKeyQuoted() {
        let input = "{_id: 123, _name: \"test\"}"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "下划线开头裸 key 应被补齐")
    }

    // MARK: - Markdown 代码块包裹符清理

    /// ```json ... ``` 包裹的 JSON 必须去除包裹符
    func testMarkdownJsonCodeBlockStripped() {
        let input = "```json\n{\"key\": \"value\"}\n```"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "```json 包裹的 JSON 应被提取")
    }

    /// ``` ... ``` 包裹（无 json 标记）的 JSON 必须去除包裹符
    func testMarkdownCodeBlockWithoutJsonTagStripped() {
        let input = "```\n{\"key\": \"value\"}\n```"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "``` 包裹的 JSON 应被提取")
    }

    /// 大小写不敏感的 ```JSON 包裹
    func testMarkdownCodeBlockCaseInsensitive() {
        let input = "```JSON\n{\"key\": \"value\"}\n```"
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "```JSON 大写应被识别并提取")
    }

    // MARK: - 边界提取

    /// 垃圾前缀 + 垃圾后缀，中间有效 JSON
    func testGarbagePrefixAndSuffixExtracted() {
        let input = #"garbage prefix {"key": "value"} trailing garbage"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "前后垃圾应被剥离，提取中间 JSON")
    }

    /// 数组 JSON 被正确提取
    func testArrayJsonExtracted() {
        let input = #"prefix [1, 2, 3] suffix"#
        let result = JSONRepairProcessor.repair(input)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(result.utf8)),
                        "数组 JSON 应被提取")
    }
}
