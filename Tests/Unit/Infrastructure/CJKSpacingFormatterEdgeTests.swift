//
//  CJKSpacingFormatterEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 CJKSpacingFormatter 在中英混排、CJK 标点、特殊符号、空字符串等边界的语义正确性。
//

import XCTest
@testable import ZhiYu

final class CJKSpacingFormatterEdgeTests: XCTestCase {

    // MARK: - 基本空格注入

    func testSpacing_cjkFollowedByEnglish_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("智宇AI")
        XCTAssertEqual(result, "智宇 AI")
    }

    func testSpacing_englishFollowedByCJK_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("AI智宇")
        XCTAssertEqual(result, "AI 智宇")
    }

    func testSpacing_cjkFollowedByNumber_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("版本6发布")
        XCTAssertEqual(result, "版本 6 发布")
    }

    func testSpacing_numberFollowedByCJK_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("6发布")
        XCTAssertEqual(result, "6 发布")
    }

    // MARK: - 边界输入

    func testSpacing_emptyString_returnsEmpty() {
        XCTAssertEqual(CJKSpacingFormatter.spacing(""), "")
    }

    func testSpacing_pureCJK_unchanged() {
        let result = CJKSpacingFormatter.spacing("智宇知识管理")
        XCTAssertEqual(result, "智宇知识管理")
    }

    func testSpacing_pureEnglish_unchanged() {
        let result = CJKSpacingFormatter.spacing("Hello World")
        XCTAssertEqual(result, "Hello World")
    }

    // MARK: - 日文假名

    func testSpacing_hiraganaFollowedByEnglish_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("こんにちはHello")
        XCTAssertEqual(result, "こんにちは Hello")
    }

    func testSpacing_katakanaFollowedByNumber_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("カタカナ123")
        XCTAssertEqual(result, "カタカナ 123")
    }

    // MARK: - 已有空格不重复

    func testSpacing_alreadySpaced_notDoubleSpaced() {
        let result = CJKSpacingFormatter.spacing("智宇 AI")
        XCTAssertEqual(result, "智宇 AI", "已有空格不应被重复注入")
    }

    // MARK: - 特殊符号

    func testSpacing_cjkFollowedByAt_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("智宇@用户")
        XCTAssertTrue(result.contains("智宇 @"))
    }

    func testSpacing_cjkFollowedByDash_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("智宇-知识")
        XCTAssertTrue(result.contains("智宇 -"))
    }

    // MARK: - 多段混排

    func testSpacing_mixedMultipleSegments_allSpaced() {
        let result = CJKSpacingFormatter.spacing("智宇AI知识管理v6版本")
        XCTAssertTrue(result.contains("智宇 AI"))
        XCTAssertTrue(result.contains("AI 知识"))
        XCTAssertTrue(result.contains("v6 版本"))
    }

    // MARK: - PanguFormatter 别名兼容

    func testPanguFormatter_alias_equivalentToCJKSpacingFormatter() {
        let input = "智宇AI"
        let r1 = CJKSpacingFormatter.spacing(input)
        let r2 = PanguFormatter.spacing(input)
        XCTAssertEqual(r1, r2, "PanguFormatter 应为 CJKSpacingFormatter 的别名")
    }
}
