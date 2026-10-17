//
//  LanguageModeTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 LanguageMode 枚举与 L10nTableEntry 协议声明的正确性与回归保护。
//

import XCTest
@testable import UFPCore

final class LanguageModeTests: XCTestCase {

    // MARK: - LanguageMode rawValue

    func testAutoRawValue() {
        XCTAssertEqual(LanguageMode.auto.rawValue, "auto")
    }

    func testLanguageRawValues() {
        XCTAssertEqual(LanguageMode.english.rawValue, "en")
        XCTAssertEqual(LanguageMode.chinese.rawValue, "zh-Hans")
        XCTAssertEqual(LanguageMode.traditionalChinese.rawValue, "zh-Hant")
        XCTAssertEqual(LanguageMode.spanish.rawValue, "es")
        XCTAssertEqual(LanguageMode.french.rawValue, "fr")
        XCTAssertEqual(LanguageMode.arabic.rawValue, "ar")
        XCTAssertEqual(LanguageMode.russian.rawValue, "ru")
        XCTAssertEqual(LanguageMode.korean.rawValue, "ko")
        XCTAssertEqual(LanguageMode.japanese.rawValue, "ja")
        XCTAssertEqual(LanguageMode.portuguese.rawValue, "pt")
    }

    // MARK: - Identifiable

    func testIdentifiableID() {
        XCTAssertEqual(LanguageMode.auto.id, "auto")
        XCTAssertEqual(LanguageMode.english.id, "en")
        XCTAssertEqual(LanguageMode.chinese.id, "zh-Hans")
    }

    // MARK: - CaseIterable

    func testAllCasesCount() {
        XCTAssertEqual(LanguageMode.allCases.count, 11)
    }

    func testAllCasesContainAutoFirst() {
        XCTAssertEqual(LanguageMode.allCases.first, .auto)
    }

    // MARK: - RawValue 可逆解析

    func testRawValueRoundTrip() {
        for mode in LanguageMode.allCases {
            XCTAssertEqual(LanguageMode(rawValue: mode.rawValue), mode)
        }
    }

    func testUnknownRawValueFallsBackToNil() {
        XCTAssertNil(LanguageMode(rawValue: "xx"))
    }

    // MARK: - Sendable

    func testLanguageModeIsSendable() {
        func accept(_ value: some Sendable) {}
        accept(LanguageMode.auto)
        accept(LanguageMode.allCases)
    }
}

// MARK: - L10nTableEntry 协议声明

/// 验证 L10nTableEntry 协议可在 UFPCore 内独立声明并被下层引用
final class L10nTableEntryProtocolTests: XCTestCase {

    /// 一个符合 L10nTableEntry 的测试表
    private enum TestTable: L10nTableEntry {
        static var tableName: String { "Test" }
    }

    func testTableNameProperty() {
        XCTAssertEqual(TestTable.tableName, "Test")
    }

    /// 验证 L10nTableEntry 可通过协议约束引用静态 tableName
    func testProtocolRequiresTableName() {
        func readTableName<T: L10nTableEntry>(_ type: T.Type) -> String {
            T.tableName
        }
        XCTAssertEqual(readTableName(TestTable.self), "Test")
    }
}