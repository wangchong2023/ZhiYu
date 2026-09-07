//
//  AhoCorasickEngineTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

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
}
