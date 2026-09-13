//
//  PageContentAndAppConstantsTests.swift
//  ZhiYuTests
//
//  系统层级：[L0] 基础内核测试
//  核心职责：验证 PageContentUtility 标签提取边界以及 AppConstants.Version 构建注入配置完整性。
//

import XCTest
@testable import ZhiYu

// MARK: - PageContentUtility.extractAllTags 边界问题验证

final class PageContentUtilityTagExtractionTests: XCTestCase {

    /// 验证正则匹配纯数字标签（#123）
    func testPageContentUtility_numericTagExtraction_extractsDigits() {
        let tags = PageContentUtility.extractAllTags(content: "#123 标签", existingTags: [])
        XCTAssertTrue(tags.contains("123"), "\\w 应包含数字，#123 应被提取")
    }

    /// 验证正则不匹配带连字符的标签（#tag-name）
    func testPageContentUtility_hyphenTagExtraction_extractsPrefix() {
        let tags = PageContentUtility.extractAllTags(content: "#tag-name", existingTags: [])
        XCTAssertFalse(tags.contains("tag-name"), "\\w 不含连字符，#tag-name 只提取 'tag'")
        XCTAssertTrue(tags.contains("tag"), "只提取到 'tag' 部分")
    }

    /// 验证正则匹配带空格的标签
    func testPageContentUtility_spaceDelimitedTag_extractsSingleWord() {
        let tags = PageContentUtility.extractAllTags(content: "#标签 内容", existingTags: [])
        XCTAssertEqual(tags, ["标签"], "#标签 后跟空格，正确提取")
    }

    /// 验证多个连续 # 的处理
    func testPageContentUtility_multipleConsecutiveHashes_extractsTag() {
        let tags = PageContentUtility.extractAllTags(content: "##标题", existingTags: [])
        XCTAssertTrue(tags.contains("标题"), "##标题 应提取 '标题'")
    }

    /// 验证 # 后直接跟空格等非字词字符的情况
    func testPageContentUtility_hashFollowedByNonWordChar_returnsEmpty() {
        let tags = PageContentUtility.extractAllTags(content: "# 标签", existingTags: [])
        XCTAssertFalse(tags.contains("标签"), "# 后跟空格，不应提取")
    }
}

// MARK: - AppConstants.Version 构建注入验证

final class AppConstantsVersionTests: XCTestCase {

    /// 验证 git 短哈希格式
    func testAppConstants_gitShortHash_hasValidHexFormat() {
        let hash = AppConstants.Version.gitShortHash
        XCTAssertEqual(hash.count, 8, "git 短哈希应为 8 字符")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "git 短哈希应为十六进制")
    }

    /// 验证 buildTimestamp 是有效 ISO 8601 格式
    func testAppConstants_buildTimestamp_hasValidISO8601Format() {
        let ts = AppConstants.Version.buildTimestamp
        let formatter = ISO8601DateFormatter()
        XCTAssertNotNil(formatter.date(from: ts), "buildTimestamp 应为有效 ISO 8601 格式")
    }

    /// 验证 semVer 非空
    func testAppConstants_semVer_isNotEmpty() {
        XCTAssertFalse(AppConstants.Version.semVer.isEmpty)
    }
}
