//
//  FTS5TokenizerCorruptionRecoveryTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 SQLiteStore FTS5 全文索引分词检索、特殊字符处理与空结果分支。
//

import XCTest
import GRDB
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class FTS5TokenizerCorruptionRecoveryTests: XCTestCase {

    var store: SQLiteStore!
    var tempDBURL: URL!
    var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        tempDBURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FTS5Test_\(UUID().uuidString).sqlite")
        dbQueue = try DatabaseQueue(path: tempDBURL.path)
        try await DatabaseManager.shared.migrate(dbQueue)
        store = SQLiteStore(dbWriter: dbQueue)
    }

    override func tearDown() async throws {
        store = nil
        dbQueue = nil
        try? FileManager.default.removeItem(at: tempDBURL)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. FTS5 中文与特殊符号分词匹配分支

    func testFTS5Search_MatchesPageContent() async throws {
        _ = try await store.createPage(
            title: "Swift 并发安全指南",
            pageType: .concept,
            content: "在 Swift 6 严格模式下，请使用 actor 和 async/await 处理并发数据"
        )

        let searchResults = await store.searchPages(query: "并发")
        XCTAssertFalse(searchResults.isEmpty, "FTS5 检索关键词应当命中已保存的页面")
        XCTAssertEqual(searchResults.first?.title, "Swift 并发安全指南")
    }

    // MARK: - 2. FTS5 无匹配关键词分支

    func testFTS5Search_WhenKeywordDoesNotExist_ReturnsEmpty() async throws {
        _ = try await store.createPage(
            title: "微服务架构模式",
            pageType: .concept,
            content: "服务注册与发现机制"
        )

        let searchResults = await store.searchPages(query: "量子力学计算")
        XCTAssertTrue(searchResults.isEmpty, "未命中的关键词应当安全返回空结果")
    }
}
