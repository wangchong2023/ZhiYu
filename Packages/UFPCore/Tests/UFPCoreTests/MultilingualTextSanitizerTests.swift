//
//  MultilingualTextSanitizerTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 MultilingualTextSanitizer 多语系洗词流水线（Leetspeak/重音符/全半角/干扰符）的正反向行为。
//

import XCTest
@testable import UFPCore

final class MultilingualTextSanitizerTests: XCTestCase {

    private let sanitizer = MultilingualTextSanitizer.shared

    func testNormalizeLeetspeakRestoresLetters() {
        XCTAssertEqual(sanitizer.normalizeLeetspeak("p@ssw0rd"), "password")
    }

    func testNormalizeLeetspeakKeepsPlainTextUntouched() {
        XCTAssertEqual(sanitizer.normalizeLeetspeak("hello"), "hello")
        XCTAssertEqual(sanitizer.normalizeLeetspeak(""), "")
    }

    func testStripDiacriticsRemovesAccents() {
        XCTAssertEqual(sanitizer.stripDiacritics("crème brûlée"), "creme brulee")
    }

    func testFullwidthNormalization() {
        XCTAssertEqual(sanitizer.normalizeFullwidthAndKana("ＡＢＣ１２３"), "ABC123")
    }

    func testStripInterferenceCharactersRemovesZeroWidthAndPunctuation() {
        XCTAssertEqual(sanitizer.stripInterferenceCharacters("颠.覆\u{200B}政 权"), "颠覆政权")
        XCTAssertEqual(sanitizer.stripInterferenceCharacters(""), "")
    }

    func testSanitizeForModerationFullPipeline() {
        // 全角 + Leetspeak + 插入点号的变异写法应被还原
        XCTAssertEqual(sanitizer.sanitizeForModeration("ｈ@.c.k"), "hack")
    }

    func testSanitizeForModerationEmptyInput() {
        XCTAssertEqual(sanitizer.sanitizeForModeration(""), "")
    }

    func testBackwardCompatibleTypeAlias() {
        XCTAssertTrue(HomophonePinyinSanitizer.shared === MultilingualTextSanitizer.shared)
    }
}
