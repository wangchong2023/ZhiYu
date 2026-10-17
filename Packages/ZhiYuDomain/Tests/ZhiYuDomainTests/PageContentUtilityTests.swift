//
//  PageContentUtilityTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证页面内容工具（extractAllTags 标签提取 / calculateWordCount 字数统计）的
//           标签提取、中文支持、去重排序与边界场景，确保下沉后行为等价无回归。
//

import XCTest
@testable import ZhiYuDomain

final class PageContentUtilityTests: XCTestCase {

    // MARK: - extractAllTags

    /// 验证提取内容中的 #标签，并与既有标签合并排序
    func testExtractAllTags_MergesAndSorts() {
        let tags = PageContentUtility.extractAllTags(content: "这是一个 #科技 文章", existingTags: ["AI"])
        XCTAssertEqual(tags, ["AI", "科技"])
    }

    /// 验证支持中文标签
    func testExtractAllTags_ChineseTags() {
        let tags = PageContentUtility.extractAllTags(content: "今天聊 #机器学习 和 #深度学习", existingTags: [])
        XCTAssertEqual(tags, ["机器学习", "深度学习"])
    }

    /// 验证数字标签可被提取
    func testExtractAllTags_NumericTags() {
        let tags = PageContentUtility.extractAllTags(content: "版本 #2024 发布", existingTags: [])
        XCTAssertEqual(tags, ["2024"])
    }

    /// 验证连续多个 # 只提取一个标签（后续 # 后无内容）
    func testExtractAllTags_ConsecutiveHashes() {
        let tags = PageContentUtility.extractAllTags(content: "##标题", existingTags: [])
        XCTAssertEqual(tags, ["标题"])
    }

    /// 验证 # 后紧跟非单词字符时返回空
    func testExtractAllTags_HashFollowedByNonWord_ReturnsEmpty() {
        let tags = PageContentUtility.extractAllTags(content: "这里有个 # 空格", existingTags: [])
        XCTAssertEqual(tags, [])
    }

    /// 验证无标签内容与空既有标签返回空数组
    func testExtractAllTags_NoTags() {
        let tags = PageContentUtility.extractAllTags(content: "纯文本没有标签", existingTags: [])
        XCTAssertEqual(tags, [])
    }

    /// 验证去重：重复标签只保留一次
    func testExtractAllTags_Deduplicates() {
        let tags = PageContentUtility.extractAllTags(content: "#AI 讨论 #AI", existingTags: ["AI"])
        XCTAssertEqual(tags, ["AI"])
    }

    // MARK: - calculateWordCount

    /// 验证中英混排字数统计（转发 UFPCore.TextAnalyzer）
    func testCalculateWordCount_MixedText() {
        let count = PageContentUtility.calculateWordCount("hello 世界 world")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证空串字数为 0
    func testCalculateWordCount_Empty() {
        XCTAssertEqual(PageContentUtility.calculateWordCount(""), 0)
    }
}