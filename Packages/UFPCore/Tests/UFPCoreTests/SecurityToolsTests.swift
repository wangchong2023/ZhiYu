//
//  SecurityToolsTests.swift
//  UFPCoreTests
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 测试层
//  核心职责：验证 UFPCore 安全/并发工具 — AhoCorasickEngine（AC 自动机）、
//           IntentRateLimiter（10Hz 滑动窗口限流）、RegexReplacementHelper（正则替换辅助，含 R5 合并）。
//

import XCTest
@testable import UFPCore

// MARK: - AhoCorasickEngine

final class AhoCorasickEngineTests: XCTestCase {

    func testAhoCorasickEngine_BasicMatching() {
        let patterns = ["颠覆政权", "暴乱", "反动宣言"]
        let engine = AhoCorasickEngine(patterns: patterns)

        let testText = "这是一个包含煽动暴乱与颠覆政权的违规文本"
        let matches = engine.search(in: testText)

        XCTAssertFalse(matches.isEmpty, "引擎应当能检测出文本中的敏感词模式")
        XCTAssertTrue(engine.containsAny(in: testText), "containsAny 应当精准返回 true")

        let matchedPatterns = matches.map { $0.pattern }
        XCTAssertTrue(matchedPatterns.contains("暴乱"), "应匹配到 '暴乱'")
        XCTAssertTrue(matchedPatterns.contains("颠覆政权"), "应匹配到 '颠覆政权'")
    }

    func testAhoCorasickEngine_NonMatchingText() {
        let patterns = ["制造炸弹", "恐怖袭击"]
        let engine = AhoCorasickEngine(patterns: patterns)

        let safeText = "今天天气晴朗，适合在智宇中整理知识卡片与图谱。"
        let matches = engine.search(in: safeText)

        XCTAssertTrue(matches.isEmpty, "安全文本不应包含任何敏感词匹配")
        XCTAssertFalse(engine.containsAny(in: safeText), "containsAny 应当返回 false")
    }

    func testAhoCorasickEngine_MutationAndEdgeCases() {
        let patterns = ["abc", "bc", "c"]
        let engine = AhoCorasickEngine(patterns: patterns)

        let text = "abc"
        let matches = engine.search(in: text)

        XCTAssertEqual(matches.count, 3, "重叠子串模式应当被全部捕获")

        let emptyEngine = AhoCorasickEngine(patterns: [])
        XCTAssertFalse(emptyEngine.containsAny(in: "任意文本"), "空字典树不应触发任何匹配")
    }

    /// 重复模式应被去重（Set 去重），不影响匹配结果
    func testAhoCorasickEngine_DuplicatePatterns_MatchesNormally() {
        let patterns = ["abc", "abc", "abc", "def"]
        let engine = AhoCorasickEngine(patterns: patterns)
        let matches = engine.search(in: "abcdef")
        let uniquePatterns = Set(matches.map { $0.pattern })
        XCTAssertTrue(uniquePatterns.contains("abc"), "应匹配到 abc")
        XCTAssertTrue(uniquePatterns.contains("def"), "应匹配到 def")
    }

    /// 空字符串模式应被过滤（filter { !$0.isEmpty }），非空模式正常匹配
    func testAhoCorasickEngine_EmptyPattern_FiltersAndWorks() {
        let patterns = ["", "test", ""]
        let engine = AhoCorasickEngine(patterns: patterns)
        XCTAssertTrue(engine.containsAny(in: "test"), "空字符串模式应被过滤，test 应匹配")
        XCTAssertFalse(engine.containsAny(in: "nomatch"), "无匹配文本应返回 false")
    }

    /// search 返回的 startIndex/endIndex 应正确
    func testAhoCorasickEngine_Search_IndexCorrectness() {
        let engine = AhoCorasickEngine(patterns: ["cat"])
        let text = "the cat sat"
        let matches = engine.search(in: text)
        XCTAssertEqual(matches.count, 1, "应匹配到 1 个结果")
        if let match = matches.first {
            XCTAssertEqual(match.pattern, "cat")
            XCTAssertEqual(match.startIndex, 4, "cat 起始索引应为 4")
            XCTAssertEqual(match.endIndex, 6, "cat 结束索引应为 6")
        }
    }

    /// containsAny 空文本应返回 false
    func testAhoCorasickEngine_ContainsAny_EmptyText_ReturnsFalse() {
        let engine = AhoCorasickEngine(patterns: ["test"])
        XCTAssertFalse(engine.containsAny(in: ""), "空文本应返回 false")
    }

    /// containsAny 空模式列表应返回 false
    func testAhoCorasickEngine_ContainsAny_EmptyPatterns_ReturnsFalse() {
        let engine = AhoCorasickEngine(patterns: [])
        XCTAssertFalse(engine.containsAny(in: "any text"), "空模式列表应返回 false")
    }

    /// search 部分匹配但未完整匹配应返回空结果
    func testAhoCorasickEngine_PartialMatch_DoesNotHit() {
        let engine = AhoCorasickEngine(patterns: ["hello"])
        let matches = engine.search(in: "hel lo")
        XCTAssertTrue(matches.isEmpty, "部分匹配（中间有空格）不应命中")
    }

    /// 多个模式在同一位置重叠应全部命中
    func testAhoCorasickEngine_OverlappingPatterns_AllHit() {
        let engine = AhoCorasickEngine(patterns: ["he", "she", "her"])
        let matches = engine.search(in: "she")
        let patterns = Set(matches.map { $0.pattern })
        XCTAssertTrue(patterns.contains("she"), "应命中 she")
        XCTAssertTrue(patterns.contains("he"), "应命中 he（she 的子串）")
    }
}

// MARK: - IntentRateLimiter

final class IntentRateLimiterTests: XCTestCase {

    override func tearDown() async throws {
        IntentRateLimiter.shared.reset()
        try await super.tearDown()
    }

    /// 10Hz 窗口内前 10 次应全部放行
    func testIntentRateLimiter_AllowsFirstTenRequests() {
        let limiter = IntentRateLimiter.shared
        limiter.reset()
        for _ in 0..<10 {
            XCTAssertTrue(limiter.request(), "窗口内前 10 次请求应全部放行")
        }
    }

    /// 第 11 次请求应被熔断拒绝
    func testIntentRateLimiter_RejectsEleventhRequest() {
        let limiter = IntentRateLimiter.shared
        limiter.reset()
        for _ in 0..<10 {
            _ = limiter.request()
        }
        XCTAssertFalse(limiter.request(), "超过 10 次后请求应被拒绝")
    }

    /// reset 后限流计数应清零，可再次放行
    func testIntentRateLimiter_Reset_ClearsCount() {
        let limiter = IntentRateLimiter.shared
        limiter.reset()
        for _ in 0..<10 {
            _ = limiter.request()
        }
        XCTAssertFalse(limiter.request(), "重置前第 11 次应被拒绝")
        limiter.reset()
        XCTAssertTrue(limiter.request(), "重置后应再次放行")
    }

    /// resetStateForTesting 应等同于 reset，用于测试隔离
    func testIntentRateLimiter_ResetStateForTesting_ClearsCount() {
        let limiter = IntentRateLimiter.shared
        limiter.reset()
        for _ in 0..<10 {
            _ = limiter.request()
        }
        limiter.resetStateForTesting()
        XCTAssertTrue(limiter.request(), "resetStateForTesting 后应再次放行")
    }
}

// MARK: - RegexReplacementHelper

final class RegexReplacementHelperTests: XCTestCase {

    /// applyReplacements 应按顺序应用多条替换规则
    func testApplyReplacements_AppliesMultipleRulesInOrder() {
        let text = "foo bar baz"
        let rules: [(pattern: String, template: String)] = [
            (pattern: "foo", template: "qux"),
            (pattern: "baz", template: "quux")
        ]
        let result = RegexReplacementHelper.applyReplacements(text, rules: rules)
        XCTAssertEqual(result, "qux bar quux", "多条规则应依次生效")
    }

    /// applyReplacements 无效正则应被跳过，不改变结果
    func testApplyReplacements_InvalidPattern_IsSkipped() {
        let text = "hello world"
        let rules: [(pattern: String, template: String)] = [
            (pattern: "[", template: "x")
        ]
        let result = RegexReplacementHelper.applyReplacements(text, rules: rules)
        XCTAssertEqual(result, text, "无效正则应被跳过，结果保持不变")
    }

    /// applyReplacements 无规则应原样返回
    func testApplyReplacements_EmptyRules_ReturnsOriginal() {
        let text = "nothing to change"
        let result = RegexReplacementHelper.applyReplacements(text, rules: [])
        XCTAssertEqual(result, text, "无规则应原样返回")
    }

    /// matchesAny 任一模式命中即返回 true
    func testMatchesAny_AnyPatternHit_ReturnsTrue() {
        XCTAssertTrue(RegexReplacementHelper.matchesAny("abc123", patterns: ["\\d+"]), "数字模式应命中")
    }

    /// matchesAny 无模式命中应返回 false
    func testMatchesAny_NoPatternHit_ReturnsFalse() {
        XCTAssertFalse(RegexReplacementHelper.matchesAny("abc", patterns: ["\\d+"]), "无命中应返回 false")
    }

    /// matchesAny 空模式列表应返回 false
    func testMatchesAny_EmptyPatterns_ReturnsFalse() {
        XCTAssertFalse(RegexReplacementHelper.matchesAny("abc", patterns: []), "空模式列表应返回 false")
    }

    /// matchesAny 无效正则应被跳过
    func testMatchesAny_InvalidPattern_IsSkipped() {
        XCTAssertFalse(RegexReplacementHelper.matchesAny("abc", patterns: ["["]), "无效正则应被跳过")
    }

    /// applyCaptureGroupReplacement 应将匹配替换为捕获组 1 + 空格 + 捕获组 2
    func testApplyCaptureGroupReplacement_ReplacesWithGroups() {
        let text = "HelloWorld"
        let result = RegexReplacementHelper.applyCaptureGroupReplacement(
            text,
            pattern: #"([a-z])([A-Z])"#
        )
        XCTAssertEqual(result, "Hello World", "应插入捕获组 1 与捕获组 2 之间的空格")
    }

    /// applyCaptureGroupReplacement 多组匹配应全部替换
    func testApplyCaptureGroupReplacement_MultipleMatches() {
        let text = "fooBarBazQux"
        let result = RegexReplacementHelper.applyCaptureGroupReplacement(
            text,
            pattern: #"([a-z])([A-Z])"#
        )
        XCTAssertEqual(result, "foo Bar Baz Qux", "多处驼峰边界应全部插入空格")
    }

    /// applyCaptureGroupReplacement 无匹配应原样返回
    func testApplyCaptureGroupReplacement_NoMatch_ReturnsOriginal() {
        let text = "already spaced"
        let result = RegexReplacementHelper.applyCaptureGroupReplacement(
            text,
            pattern: #"([a-z])([A-Z])"#
        )
        XCTAssertEqual(result, text, "无驼峰边界应原样返回")
    }

    /// applyCaptureGroupReplacement 无效正则应原样返回
    func testApplyCaptureGroupReplacement_InvalidPattern_ReturnsOriginal() {
        let text = "hello"
        let result = RegexReplacementHelper.applyCaptureGroupReplacement(text, pattern: "[")
        XCTAssertEqual(result, text, "无效正则应原样返回")
    }
}
