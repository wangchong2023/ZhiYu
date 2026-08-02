//
//  HomophonePinyinSanitizerTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

final class HomophonePinyinSanitizerTests: XCTestCase {

    func testStripInterferenceCharacters() {
        let sanitizer = MultilingualTextSanitizer.shared

        let inputWithDots = "颠.覆.政.权"
        let cleaned = sanitizer.stripInterferenceCharacters(inputWithDots)

        XCTAssertEqual(cleaned, "颠覆政权", "应剥离中间插入的隔点号")

        let inputWithSymbols = "暴_乱*与#毒$品"
        let cleanedSymbols = sanitizer.stripInterferenceCharacters(inputWithSymbols)

        XCTAssertEqual(cleanedSymbols, "暴乱与毒品", "应剥离特殊字符与标点符号")
    }

    func testNormalizeLeetspeak_English() {
        let sanitizer = MultilingualTextSanitizer.shared

        let leetText = "p@ssw0rd"
        let normalized = sanitizer.normalizeLeetspeak(leetText)

        XCTAssertEqual(normalized, "password", "英文 Leetspeak 特殊字符应精准被还原")
    }

    func testStripDiacritics_EuropeanLanguages() {
        let sanitizer = MultilingualTextSanitizer.shared

        let frenchGermanText = "çâfé ëxämplë"
        let stripped = sanitizer.stripDiacritics(frenchGermanText)

        XCTAssertEqual(stripped, "cafe example", "法/德/西等欧语系变音符号应被归一化剥离")
    }

    func testSanitizeForModeration_MultilingualIntegration() {
        let sanitizer = MultilingualTextSanitizer.shared

        let rawInput = "煽.动.暴.乱"
        let sanitized = sanitizer.sanitizeForModeration(rawInput)

        XCTAssertFalse(sanitized.contains("."), "洗词结果不应包含原有的分隔符")
        XCTAssertEqual(sanitized, "煽动暴乱", "应准确还原纯文本词汇")
    }
}
