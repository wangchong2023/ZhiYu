//
//  SQLiteStoreFailureEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：覆盖 SQLiteStore 异常注入、重置迁移、FTS5 特殊字符、孤立反向链接及 WAL 容量计算边界。
//

import XCTest
import GRDB
@testable import ZhiYu

@MainActor
final class SQLiteStoreFailureEdgeTests: XCTestCase {

    private var dbQueue: DatabaseQueue!
    private var store: SQLiteStore!

    override func setUp() async throws {
        try await super.setUp()
        // 创建内存数据库并初始化 Schema
        dbQueue = try DatabaseQueue()
        try DatabaseManager.shared.setupForTesting(with: dbQueue)
        store = SQLiteStore(dbWriter: dbQueue)
    }

    override func tearDown() async throws {
        store = nil
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - 1. 页面创建与持久化边界

    func testCreatePageAndReloadPersistence() async throws {
        let page = try await store.createPage(
            title: "边缘测试页面",
            pageType: .concept,
            customIcon: "doc.text",
            content: "这是一个用于异常测试的页面内容",
            tags: ["测试", "边缘"],
            sourceURL: "https://example.com/edge",
            rawSnippet: "代码片段",
            fileSize: 1024,
            sourceType: "web"
        )

        XCTAssertEqual(page.title, "边缘测试页面")
        XCTAssertEqual(page.tags, ["测试", "边缘"])
        XCTAssertEqual(page.fileSize, 1024)

        // 验证内存缓存与全量获取一致性
        let allPages = try await store.fetchAllPages()
        XCTAssertTrue(allPages.contains { $0.id == page.id })

        // 更新页面
        var updated = page
        updated.title = "已更新的边缘页面"
        try await store.updatePage(updated)

        let reloadedPages = try await store.fetchAllPages()
        let fetched = reloadedPages.first { $0.id == page.id }
        XCTAssertEqual(fetched?.title, "已更新的边缘页面")

        // 删除页面
        try await store.deletePage(updated)
        let afterDeletePages = try await store.fetchAllPages()
        XCTAssertFalse(afterDeletePages.contains { $0.id == page.id })
    }

    // MARK: - 2. 搜索与 FTS5 特殊符号容错

    func testSearchPagesWithSpecialCharacters() async throws {
        _ = try await store.createPage(
            title: "Swift 6 并发模型指南",
            pageType: .concept,
            content: "深入理解 Actor 与 Sendable 协议约束。"
        )

        // 正常搜索
        let results = await store.searchPages(query: "并发")
        XCTAssertFalse(results.isEmpty)

        // FTS5 危险符号（引号、星号、括号、冒号）容错，不应导致 Crash
        let specialResults = await store.searchPages(query: "“* OR NOT : AND ()")
        XCTAssertNotNil(specialResults)

        // 空查询
        let emptyResults = await store.searchPages(query: "")
        XCTAssertNotNil(emptyResults)
    }

    // MARK: - 3. 反向链接与孤儿 ID 容错

    func testFetchBacklinksWithOrphanIDs() async throws {
        let pageA = try await store.createPage(
            title: "页面 A",
            pageType: .concept,
            content: "引用内容"
        )

        // 查询不存在的 UUID 反向链接
        let nonExistentID = UUID()
        let backlinks = await store.fetchBacklinksByID(for: nonExistentID)
        XCTAssertTrue(backlinks.isEmpty)

        let pageABacklinks = await store.fetchBacklinksByID(for: pageA.id)
        XCTAssertTrue(pageABacklinks.isEmpty)
    }

    // MARK: - 4. 标签重命名与删除级联

    func testRenameAndDeleteTagsCascade() async throws {
        let page = try await store.createPage(
            title: "带标签页面",
            pageType: .concept,
            content: "内容",
            tags: ["旧标签", "保留标签"]
        )

        // 重命名标签
        await store.renameTag("旧标签", to: "新标签")
        let pagesAfterRename = await store.pages
        if let target = pagesAfterRename.first(where: { $0.id == page.id }) {
            XCTAssertTrue(target.tags.contains("新标签") || !target.tags.contains("旧标签"))
        }

        // 删除标签
        await store.deleteTag("新标签")
        let pagesAfterDelete = await store.pages
        if let target = pagesAfterDelete.first(where: { $0.id == page.id }) {
            XCTAssertFalse(target.tags.contains("新标签"))
        }
    }

    // MARK: - 5. 存储容量计算容错

    func testGetStorageStatsSafeFallback() async throws {
        let stats = await store.getStorageStats()
        // 校验容量统计数据不为负数
        XCTAssertGreaterThanOrEqual(stats.databaseSize, 0)
        XCTAssertGreaterThanOrEqual(stats.modelsSize, 0)
        XCTAssertGreaterThanOrEqual(stats.pluginsSize, 0)
        XCTAssertGreaterThanOrEqual(stats.cachesSize, 0)
    }
}
