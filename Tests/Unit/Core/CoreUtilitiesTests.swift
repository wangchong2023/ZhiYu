//
//  CoreUtilitiesTests.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

/// PageContentUtility 单元测试
/// 验证字数统计与标签提取算法
final class PageContentUtilityTests: XCTestCase {

    // MARK: - calculateWordCount

    /// 验证空字符串字数为 0
    func testCalculateWordCountEmptyString() {
        XCTAssertEqual(PageContentUtility.calculateWordCount(""), 0)
    }

    /// 验证纯英文按单词计数
    func testCalculateWordCountPureEnglish() {
        let count = PageContentUtility.calculateWordCount("hello world foo bar")
        XCTAssertEqual(count, 4)
    }

    /// 验证纯中文按字符计数
    func testCalculateWordCountPureChinese() {
        let count = PageContentUtility.calculateWordCount("你好世界")
        XCTAssertEqual(count, 4)
    }

    /// 验证中英混排
    func testCalculateWordCountMixedChineseEnglish() {
        let count = PageContentUtility.calculateWordCount("你好 world 世界 foo")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证空白字符不计入
    func testCalculateWordCountWhitespaceOnly() {
        let count = PageContentUtility.calculateWordCount("   \n\t  ")
        XCTAssertEqual(count, 0)
    }

    // MARK: - extractAllTags

    /// 验证从内容中提取 #标签
    func testExtractAllTagsFromContent() {
        let content = "这是 #标签1 和 #标签2 的内容"
        let tags = PageContentUtility.extractAllTags(content: content, existingTags: [])
        XCTAssertTrue(tags.contains("标签1"))
        XCTAssertTrue(tags.contains("标签2"))
    }

    /// 验证 existingTags 与内容标签合并去重
    func testExtractAllTagsMergesWithExistingTags() {
        let content = "内容包含 #新标签"
        let tags = PageContentUtility.extractAllTags(content: content, existingTags: ["新标签", "旧标签"])
        let uniqueTags = Set(tags)
        XCTAssertEqual(uniqueTags.count, tags.count, "标签应去重")
        XCTAssertTrue(tags.contains("新标签"))
        XCTAssertTrue(tags.contains("旧标签"))
    }

    /// 验证英文标签提取
    func testExtractAllTagsEnglishTags() {
        let content = "this is #swift and #ios"
        let tags = PageContentUtility.extractAllTags(content: content, existingTags: [])
        XCTAssertTrue(tags.contains("swift"))
        XCTAssertTrue(tags.contains("ios"))
    }

    /// 验证无标签时只返回 existingTags
    func testExtractAllTagsNoTagsInContent() {
        let content = "这段内容没有任何标签"
        let tags = PageContentUtility.extractAllTags(content: content, existingTags: ["existing"])
        XCTAssertEqual(tags, ["existing"])
    }

    /// 验证空内容只返回 existingTags
    func testExtractAllTagsEmptyContent() {
        let tags = PageContentUtility.extractAllTags(content: "", existingTags: ["a", "b"])
        XCTAssertEqual(tags, ["a", "b"])
    }

    /// 验证标签按字母序排序
    func testExtractAllTagsReturnsSorted() {
        let content = "#zebra #apple #mango"
        let tags = PageContentUtility.extractAllTags(content: content, existingTags: [])
        XCTAssertEqual(tags, ["apple", "mango", "zebra"])
    }

    /// 验证重复标签只出现一次
    func testExtractAllTagsDeduplicates() {
        let content = "#tag #tag #tag"
        let tags = PageContentUtility.extractAllTags(content: content, existingTags: ["tag"])
        XCTAssertEqual(tags, ["tag"])
    }
}
