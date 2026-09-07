//
//  CharacterCJKDetectionTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 Character.isCJKCharacter 对 Unicode CJK 8 大区间判定与非 CJK 字符排他性。
//

import XCTest
@testable import UFPCore

final class CharacterCJKDetectionTests: XCTestCase {

    // MARK: - 8 大 CJK 区间正向判定

    func testIsCJKCharacter_cjkUnifiedIdeographs_returnsTrue() {
        // 0x4E00 一, 0x9FFF 鿿, 中间字符 '中', '文'
        XCTAssertTrue(Character("\u{4E00}").isCJKCharacter)
        XCTAssertTrue(Character("\u{9FFF}").isCJKCharacter)
        XCTAssertTrue(Character("中").isCJKCharacter)
        XCTAssertTrue(Character("文").isCJKCharacter)
    }

    func testIsCJKCharacter_cjkExtensionA_returnsTrue() {
        // 0x3400...0x4DBF
        XCTAssertTrue(Character("\u{3400}").isCJKCharacter)
        XCTAssertTrue(Character("\u{4DBF}").isCJKCharacter)
    }

    func testIsCJKCharacter_cjkSymbolsAndPunctuation_returnsTrue() {
        // 0x3000...0x303F
        XCTAssertTrue(Character("\u{3000}").isCJKCharacter)
        XCTAssertTrue(Character("\u{303F}").isCJKCharacter)
        XCTAssertTrue(Character("。").isCJKCharacter)
        XCTAssertTrue(Character("、").isCJKCharacter)
        XCTAssertTrue(Character("「").isCJKCharacter)
        XCTAssertTrue(Character("」").isCJKCharacter)
    }

    func testIsCJKCharacter_halfwidthAndFullwidthForms_returnsTrue() {
        // 0xFF00...0xFFEF
        XCTAssertTrue(Character("\u{FF00}").isCJKCharacter)
        XCTAssertTrue(Character("\u{FFEF}").isCJKCharacter)
        XCTAssertTrue(Character("！").isCJKCharacter)
        XCTAssertTrue(Character("？").isCJKCharacter)
        XCTAssertTrue(Character("：").isCJKCharacter)
    }

    func testIsCJKCharacter_cjkRadicalsSupplement_returnsTrue() {
        // 0x2E80...0x2EFF
        XCTAssertTrue(Character("\u{2E80}").isCJKCharacter)
        XCTAssertTrue(Character("\u{2EFF}").isCJKCharacter)
    }

    func testIsCJKCharacter_hiragana_returnsTrue() {
        // 0x3040...0x309F
        XCTAssertTrue(Character("\u{3040}").isCJKCharacter)
        XCTAssertTrue(Character("\u{309F}").isCJKCharacter)
        XCTAssertTrue(Character("あ").isCJKCharacter)
        XCTAssertTrue(Character("ん").isCJKCharacter)
    }

    func testIsCJKCharacter_katakana_returnsTrue() {
        // 0x30A0...0x30FF
        XCTAssertTrue(Character("\u{30A0}").isCJKCharacter)
        XCTAssertTrue(Character("\u{30FF}").isCJKCharacter)
        XCTAssertTrue(Character("ア").isCJKCharacter)
        XCTAssertTrue(Character("ン").isCJKCharacter)
    }

    func testIsCJKCharacter_koreanSyllables_returnsTrue() {
        // 0xAC00...0xD7AF
        XCTAssertTrue(Character("\u{AC00}").isCJKCharacter)
        XCTAssertTrue(Character("\u{D7AF}").isCJKCharacter)
        XCTAssertTrue(Character("한").isCJKCharacter)
        XCTAssertTrue(Character("글").isCJKCharacter)
    }

    // MARK: - 非 CJK 字符排他性反向判定

    func testIsCJKCharacter_asciiLettersAndDigits_returnsFalse() {
        let nonCJKChars: [Character] = ["a", "Z", "0", "9", " ", "\n", "\t"]
        for ch in nonCJKChars {
            XCTAssertFalse(ch.isCJKCharacter, "ASCII 字符 '\(ch)' 必须返回 false")
        }
    }

    func testIsCJKCharacter_asciiPunctuation_returnsFalse() {
        let asciiPunctuation: [Character] = [".", ",", "!", "?", ":", ";", "/", "-", "@", "#", "$"]
        for ch in asciiPunctuation {
            XCTAssertFalse(ch.isCJKCharacter, "ASCII 标点 '\(ch)' 必须返回 false")
        }
    }

    func testIsCJKCharacter_emojisAndEuropeanScripts_returnsFalse() {
        let otherChars: [Character] = ["😀", "🎉", "α", "β", "д", "ж", "ñ", "ü"]
        for ch in otherChars {
            XCTAssertFalse(ch.isCJKCharacter, "表情符号或非东亚西里尔/希腊字符 '\(ch)' 必须返回 false")
        }
    }
}
