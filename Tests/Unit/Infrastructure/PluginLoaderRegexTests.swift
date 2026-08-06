//
//  PluginLoaderRegexTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 PluginLoader 中 String.matchesRegex extension 的正则匹配行为。
//

import XCTest
@testable import ZhiYu

final class PluginLoaderRegexTests: XCTestCase {

    // MARK: - 基础匹配

    func testMatchesRegex_exactMatch_returnsTrue() {
        XCTAssertTrue("hello".matchesRegex("hello"))
    }

    func testMatchesRegex_substringMatch_returnsTrue() {
        XCTAssertTrue("hello world".matchesRegex("world"))
    }

    func testMatchesRegex_noMatch_returnsFalse() {
        XCTAssertFalse("hello".matchesRegex("world"))
    }

    func testMatchesRegex_emptyString_nonEmptyPattern_returnsFalse() {
        XCTAssertFalse("".matchesRegex("hello"))
    }

    // MARK: - 通配符与锚点

    func testMatchesRegex_dotWildcard_matchesAnyChar() {
        XCTAssertTrue("abc".matchesRegex("a.c"))
    }

    func testMatchesRegex_dotWildcard_doesNotMatchNewline() {
        XCTAssertFalse("a\nc".matchesRegex("a.c"))
    }

    func testMatchesRegex_startAnchor() {
        XCTAssertTrue("hello world".matchesRegex("^hello"))
        XCTAssertFalse("hello world".matchesRegex("^world"))
    }

    func testMatchesRegex_endAnchor() {
        XCTAssertTrue("hello world".matchesRegex("world$"))
        XCTAssertFalse("hello world".matchesRegex("hello$"))
    }

    func testMatchesRegex_fullAnchor_exactMatch() {
        XCTAssertTrue("hello".matchesRegex("^hello$"))
        XCTAssertFalse("hello world".matchesRegex("^hello$"))
    }

    // MARK: - 字符类

    func testMatchesRegex_characterClass_digits() {
        XCTAssertTrue("abc123".matchesRegex("[0-9]+"))
        XCTAssertFalse("abc".matchesRegex("[0-9]+"))
    }

    func testMatchesRegex_characterClass_letters() {
        XCTAssertTrue("abc123".matchesRegex("[a-z]+"))
        XCTAssertFalse("ABC".matchesRegex("[a-z]+"))
    }

    func testMatchesRegex_digitShorthand() {
        XCTAssertTrue("a1b".matchesRegex("\\d"))
        XCTAssertFalse("abc".matchesRegex("\\d"))
    }

    func testMatchesRegex_wordCharShorthand() {
        XCTAssertTrue("hello_world".matchesRegex("\\w+"))
    }

    func testMatchesRegex_whitespaceShorthand() {
        XCTAssertTrue("hello world".matchesRegex("\\s"))
        XCTAssertFalse("helloworld".matchesRegex("\\s"))
    }

    // MARK: - 量词

    func testMatchesRegex_starZeroOrMore() {
        XCTAssertTrue("aaa".matchesRegex("a*"))
        XCTAssertTrue("".matchesRegex("a*"))
    }

    func testMatchesRegex_plusOneOrMore() {
        XCTAssertTrue("aaa".matchesRegex("a+"))
        XCTAssertFalse("".matchesRegex("a+"))
    }

    func testMatchesRegex_questionZeroOrOne() {
        XCTAssertTrue("a".matchesRegex("ab?"))
        XCTAssertTrue("ab".matchesRegex("ab?"))
    }

    // MARK: - 特殊字符

    func testMatchesRegex_escapedDot() {
        XCTAssertTrue("file.txt".matchesRegex("\\.txt"))
        XCTAssertFalse("filextxt".matchesRegex("\\.txt"))
    }

    func testMatchesRegex_specialCharsInPattern() {
        XCTAssertTrue("a(b)c".matchesRegex("\\(b\\)"))
    }

    // MARK: - 无效正则

    func testMatchesRegex_invalidPattern_returnsFalse() {
        XCTAssertFalse("hello".matchesRegex("[invalid"))
    }

    func testMatchesRegex_unmatchedParenthesis_returnsFalse() {
        XCTAssertFalse("hello".matchesRegex("(abc"))
    }

    // MARK: - 中文与 Unicode

    func testMatchesRegex_chineseText() {
        XCTAssertTrue("你好世界".matchesRegex("你好"))
        XCTAssertFalse("你好世界".matchesRegex("再见"))
    }

    func testMatchesRegex_unicodePattern() {
        XCTAssertTrue("测试123".matchesRegex("测试\\d+"))
    }

    // MARK: - 实际插件场景

    func testMatchesRegex_pluginIdFormat() {
        XCTAssertTrue("com.zhiyu.plugin.test".matchesRegex("^[a-z]+\\.[a-z]+\\.[a-z]+\\.[a-z]+$"))
    }

    func testMatchesRegex_semverFormat() {
        XCTAssertTrue("1.2.3".matchesRegex("^\\d+\\.\\d+\\.\\d+$"))
        XCTAssertFalse("1.2".matchesRegex("^\\d+\\.\\d+\\.\\d+$"))
    }

    func testMatchesRegex_hexStringFormat() {
        XCTAssertTrue("deadbeef".matchesRegex("^[0-9a-fA-F]+$"))
        XCTAssertFalse("xyz123".matchesRegex("^[0-9a-fA-F]+$"))
    }
}
