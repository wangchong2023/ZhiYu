//
//  WikiLinkExtractorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 WikiLinkExtractor 对 [[页面标题]] 与 [[显示文案|目标页面]] 的提取、转义、边界处理。
//

import XCTest
@testable import ZhiYu

final class WikiLinkExtractorEdgeTests: XCTestCase {

    // MARK: - 基本提取

    func testExtractLinks_singleStandardLink() {
        let matches = WikiLinkExtractor.extractLinks(from: "参考 [[架构设计]] 文档")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].targetTitle, "架构设计")
        XCTAssertNil(matches[0].alias)
        XCTAssertEqual(matches[0].displayTitle, "架构设计")
        XCTAssertEqual(matches[0].rawMatch, "[[架构设计]]")
    }

    func testExtractLinks_aliasedLink() {
        let matches = WikiLinkExtractor.extractLinks(from: "[[数据模型|Database Schema]]")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].targetTitle, "数据模型")
        XCTAssertEqual(matches[0].alias, "Database Schema")
        XCTAssertEqual(matches[0].displayTitle, "Database Schema")
    }

    func testExtractLinks_multipleLinks() {
        let text = "[[页面A]] 和 [[页面B]] 以及 [[页面C|别名C]]"
        let matches = WikiLinkExtractor.extractLinks(from: text)
        XCTAssertEqual(matches.count, 3)
    }

    // MARK: - 边界输入

    func testExtractLinks_emptyText_returnsEmpty() {
        XCTAssertTrue(WikiLinkExtractor.extractLinks(from: "").isEmpty)
    }

    func testExtractLinks_noLinks_returnsEmpty() {
        XCTAssertTrue(WikiLinkExtractor.extractLinks(from: "普通文本无链接").isEmpty)
    }

    func testExtractLinks_unclosedBracket_notMatched() {
        let matches = WikiLinkExtractor.extractLinks(from: "未闭合 [[页面标题")
        XCTAssertTrue(matches.isEmpty, "未闭合的双链不应被匹配")
    }

    func testExtractLinks_emptyTitle_notMatched() {
        let matches = WikiLinkExtractor.extractLinks(from: "[[ ]]")
        XCTAssertTrue(matches.isEmpty, "空标题的双链不应被匹配")
    }

    // MARK: - 转义字符

    func testExtractLinks_escapedBackslash_notMatched() {
        let matches = WikiLinkExtractor.extractLinks(from: "\\[[不应匹配]]")
        XCTAssertTrue(matches.isEmpty, "反斜杠转义的双链不应被匹配")
    }

    // MARK: - 空白处理

    func testExtractLinks_titleWithSpaces_trimmed() {
        let matches = WikiLinkExtractor.extractLinks(from: "[[  带空格的标题  ]]")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].targetTitle, "带空格的标题")
    }

    func testExtractLinks_aliasWithSpaces_trimmed() {
        let matches = WikiLinkExtractor.extractLinks(from: "[[目标|  带空格别名  ]]")
        XCTAssertEqual(matches[0].alias, "带空格别名")
    }

    // MARK: - displayTitle 语义

    func testDisplayTitle_withAlias_returnsAlias() {
        let match = WikiLinkMatch(rawMatch: "[[a|b]]", targetTitle: "a", alias: "b")
        XCTAssertEqual(match.displayTitle, "b")
    }

    func testDisplayTitle_withoutAlias_returnsTargetTitle() {
        let match = WikiLinkMatch(rawMatch: "[[a]]", targetTitle: "a", alias: nil)
        XCTAssertEqual(match.displayTitle, "a")
    }

    // MARK: - Identifiable 与 Equatable

    func testWikiLinkMatch_id_isRawMatch() {
        let match = WikiLinkMatch(rawMatch: "[[test]]", targetTitle: "test", alias: nil)
        XCTAssertEqual(match.id, "[[test]]")
    }

    func testWikiLinkMatch_equatable() {
        let m1 = WikiLinkMatch(rawMatch: "[[a]]", targetTitle: "a", alias: nil)
        let m2 = WikiLinkMatch(rawMatch: "[[a]]", targetTitle: "a", alias: nil)
        XCTAssertEqual(m1, m2)
    }

    // MARK: - 嵌套与复杂场景

    func testExtractLinks_aliasContainsSpecialChars() {
        let matches = WikiLinkExtractor.extractLinks(from: "[[目标|别名(含特殊)]]")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].targetTitle, "目标")
        XCTAssertEqual(matches[0].alias, "别名(含特殊)")
    }

    func testExtractLinks_consecutiveLinks() {
        let matches = WikiLinkExtractor.extractLinks(from: "[[A]][[B]]")
        XCTAssertEqual(matches.count, 2)
    }
}
