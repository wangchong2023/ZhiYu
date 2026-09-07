//
//  CoreUtilityDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L0] 底层基座层测试
//  核心职责：验证 Core 层纯逻辑工具的完整性。
//           覆盖 PageContentUtility（字数统计、标签提取去重排序）
//           与 LogEntry（初始化、Codable 往返、Identifiable、Sendable）。
//

import XCTest
@testable import ZhiYu

// MARK: - PageContentUtility 测试

final class PageContentUtilitySupplementTests: XCTestCase {

    /// 验证 calculateWordCount 空字符串
    func testCalculateWordCountEmpty() {
        XCTAssertEqual(PageContentUtility.calculateWordCount(""), 0)
    }

    /// 验证 calculateWordCount 纯英文
    func testCalculateWordCountEnglish() {
        let count = PageContentUtility.calculateWordCount("hello world test")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证 calculateWordCount 纯中文
    func testCalculateWordCountChinese() {
        let count = PageContentUtility.calculateWordCount("你好世界")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证 calculateWordCount 中英混排
    func testCalculateWordCountMixed() {
        let count = PageContentUtility.calculateWordCount("hello 世界 test 测试")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证 extractAllTags 仅 existingTags
    func testExtractAllTagsExistingOnly() {
        let tags = PageContentUtility.extractAllTags(content: "无标签内容", existingTags: ["tag1", "tag2"])
        XCTAssertEqual(tags, ["tag1", "tag2"])
    }

    /// 验证 extractAllTags 仅内容标签
    func testExtractAllTagsContentOnly() {
        let tags = PageContentUtility.extractAllTags(content: "内容 #标签1 #标签2", existingTags: [])
        XCTAssertEqual(tags, ["标签1", "标签2"])
    }

    /// 验证 extractAllTags 合并去重
    func testExtractAllTagsMergeAndDeduplicate() {
        let tags = PageContentUtility.extractAllTags(content: "#共享 #新标签", existingTags: ["共享", "旧标签"])
        XCTAssertEqual(tags, ["共享", "新标签", "旧标签"])
    }

    /// 验证 extractAllTags 排序
    func testExtractAllTagsSorted() {
        let tags = PageContentUtility.extractAllTags(content: "#zebra #apple #mango", existingTags: [])
        XCTAssertEqual(tags, ["apple", "mango", "zebra"])
    }

    /// 验证 extractAllTags 空内容
    func testExtractAllTagsEmptyContent() {
        let tags = PageContentUtility.extractAllTags(content: "", existingTags: [])
        XCTAssertTrue(tags.isEmpty)
    }

    /// 验证 extractAllTags 英文标签
    func testExtractAllTagsEnglishTags() {
        let tags = PageContentUtility.extractAllTags(content: "#hello #world", existingTags: [])
        XCTAssertEqual(tags, ["hello", "world"])
    }
}

// MARK: - LogEntry 测试

final class LogEntryTests: XCTestCase {

    /// 验证 LogEntry init 含默认值
    func testLogEntryInitWithDefaults() {
        let entry = LogEntry(action: .create, target: "页面A")
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.action, .create)
        XCTAssertEqual(entry.target, "页面A")
        XCTAssertEqual(entry.details, "")
        XCTAssertNotNil(entry.timestamp)
        XCTAssertNil(entry.duration)
        XCTAssertNil(entry.startTime)
        XCTAssertNil(entry.endTime)
        XCTAssertNil(entry.module)
        XCTAssertNil(entry.status)
        XCTAssertNil(entry.failureReason)
    }

    /// 验证 LogEntry init 含全部参数
    func testLogEntryInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 1005)
        let entry = LogEntry(
            id: id,
            action: .ingest,
            target: "target",
            details: "详情",
            timestamp: date,
            duration: 5.0,
            startTime: start,
            endTime: end,
            module: "Knowledge",
            status: .success,
            failureReason: "无"
        )
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.action, .ingest)
        XCTAssertEqual(entry.details, "详情")
        XCTAssertEqual(entry.timestamp, date)
        XCTAssertEqual(entry.duration, 5.0)
        XCTAssertEqual(entry.startTime, start)
        XCTAssertEqual(entry.endTime, end)
        XCTAssertEqual(entry.module, "Knowledge")
        XCTAssertEqual(entry.status, .success)
        XCTAssertEqual(entry.failureReason, "无")
    }

    /// 验证 LogEntry Codable 往返
    func testLogEntryCodableRoundTrip() throws {
        let original = LogEntry(
            action: .lint,
            target: "查询",
            details: "搜索详情",
            duration: 1.5,
            module: "Search",
            status: .processing
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LogEntry.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.action, original.action)
        XCTAssertEqual(decoded.target, original.target)
        XCTAssertEqual(decoded.details, original.details)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.module, original.module)
        XCTAssertEqual(decoded.status, original.status)
    }

    /// 验证 LogEntry Identifiable
    func testLogEntryIdentifiable() {
        let entry = LogEntry(action: .create, target: "x")
        XCTAssertFalse(entry.id.uuidString.isEmpty)
    }

    /// 验证 LogEntry Sendable
    func testLogEntrySendable() {
        let entry = LogEntry(action: .create, target: "x")
        XCTAssertTrue(type(of: entry) is any Sendable.Type)
    }
}
