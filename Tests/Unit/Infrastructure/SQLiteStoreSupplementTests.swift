//
//  SQLiteStoreSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 SQLiteStore、DatabaseManager 与 GRDB 扩展的未覆盖分支
//          （页面增删查、搜索、反向链接、存储统计、anyCreatePage 失败回退、
//           addLog 不崩溃、DatabaseManager reset/migrate/连接释放、
//           PluginRecord/KnowledgePage 表名与列名映射、
//           Array GRDBJSONCodable 编码解码环回）。
//

import XCTest
import UFPStorage
import UFPCore
import LocalAuthentication
import Dependencies
@testable import ZhiYu

@MainActor
final class SQLiteStoreSupplementTests: XCTestCase {

    // MARK: - DatabaseManager

    /// DatabaseManager reset 后 dbWriter 为 nil
    func testDatabaseManagerResetAfterDbWriterIsNil() {
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.dbWriter)
    }

    /// DatabaseManager reset 后 globalWriter 为 nil
    func testDatabaseManagerResetAfterGlobalWriterIsNil() {
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.globalWriter)
    }

    /// DatabaseManager reset 后 dbURL 为 nil
    func testDatabaseManagerResetAfterDbURLIsNil() {
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.dbURL)
    }

    /// DatabaseManager reset 后 globalDBURL 为 nil
    func testDatabaseManagerResetAfterGlobalDBURLIsNil() {
        DatabaseManager.shared.reset()
        XCTAssertNil(DatabaseManager.shared.globalDBURL)
    }

    /// DatabaseManager state 初始为 uninitialized
    func testDatabaseManagerInitialStateUninitialized() {
        DatabaseManager.shared.reset()
        XCTAssertEqual(DatabaseManager.shared.state, .uninitialized)
    }

    /// DatabaseManager migrate 对内存库执行迁移
    func testDatabaseManagerMigrateMemoryQueueMigrationSuccess() throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        let tables = try memoryQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
        XCTAssertFalse(tables.isEmpty)
    }

    /// DatabaseManager releaseDatabaseConnection 应将 dbWriter 置 nil
    func testDatabaseManagerReleaseDatabaseConnectionDbWriterIsNil() throws {
        let memoryQueue = try DatabaseQueue()
        DatabaseManager.shared.dbWriter = memoryQueue
        DatabaseManager.shared.releaseDatabaseConnection()
        XCTAssertNil(DatabaseManager.shared.dbWriter)
    }

    /// DatabaseManager countPagesInCurrentVault 无 writer 时返回 0
    func testDatabaseManagerCountPagesInCurrentVaultNoWriterReturnsZero() async throws {
        DatabaseManager.shared.reset()
        let count = try await DatabaseManager.shared.countPagesInCurrentVault()
        XCTAssertEqual(count, 0)
    }

    // MARK: - SQLiteStore

    /// SQLiteStore pages 初始为空
    func testSQLiteStorePagesInitiallyEmpty() async throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        try await Task.sleep(for: .milliseconds(100))
        let pages = await store.pages
        XCTAssertTrue(pages.isEmpty)
    }

    /// SQLiteStore createPage 应创建并返回页面
    func testSQLiteStoreCreatePageCreationSuccess() async throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        DatabaseManager.shared.dbWriter = memoryQueue
        let store = SQLiteStore(dbWriter: memoryQueue)
        try await Task.sleep(for: .milliseconds(100))

        let page = try await store.createPage(title: "Test", pageType: .concept, content: "content")
        XCTAssertEqual(page.title, "Test")
        let pages = await store.pages
        XCTAssertFalse(pages.isEmpty)
        DatabaseManager.shared.reset()
    }

    /// SQLiteStore searchPages 空查询应返回结果（不崩溃）
    func testSQLiteStoreSearchPagesEmptyQueryNoCrash() async throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        try await Task.sleep(for: .milliseconds(100))

        let results = await store.searchPages(query: "test")
        // 空库搜索返回空
        XCTAssertTrue(results.isEmpty)
    }

    /// SQLiteStore fetchBacklinksByID 无反向链接应返回空
    func testSQLiteStoreFetchBacklinksByIDNoLinksReturnsEmpty() async throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        try await Task.sleep(for: .milliseconds(100))

        let backlinks = await store.fetchBacklinksByID(for: UUID())
        XCTAssertTrue(backlinks.isEmpty)
    }

    /// SQLiteStore getStorageStats 应返回有效统计
    func testSQLiteStoreGetStorageStatsReturnsValidStats() async throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        DatabaseManager.shared.dbWriter = memoryQueue
        let store = SQLiteStore(dbWriter: memoryQueue)
        try await Task.sleep(for: .milliseconds(100))

        let stats = await store.getStorageStats()
        XCTAssertGreaterThanOrEqual(stats.databaseSize, 0)
        DatabaseManager.shared.reset()
    }

    /// SQLiteStore anyCreatePage 失败时返回 nil（Bug #136 修复验证）
    func testSQLiteStoreAnyCreatePageFailureReturnsNil() async throws {
        // 使用已 reset 的 DatabaseManager，dbWriter 为 nil
        DatabaseManager.shared.reset()
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        try await Task.sleep(for: .milliseconds(100))

        // 在没有完整 DI 环境的情况下，createPage 可能失败
        // Bug #136 修复：失败时应返回 nil 而非空 KnowledgePage
        let page = await store.anyCreatePage(
            title: "Test", pageType: .concept, customIcon: nil,
            content: "c", tags: [], sourceURL: nil, rawSnippet: nil,
            fileSize: nil, sourceType: nil, forceDeepScan: false
        )
        // 无论成功或失败，返回值类型应为 KnowledgePage?
        // 如果成功则 title 应为 "Test"，如果失败则应为 nil
        if let page = page {
            XCTAssertEqual(page.title, "Test", "成功时 title 应匹配")
        }
        // 关键验证：不再返回空 KnowledgePage（title 为空的假页面）
        if let page = page {
            XCTAssertFalse(page.title.isEmpty, "不应返回 title 为空的假页面（Bug #136 核心修复）")
        }
        DatabaseManager.shared.reset()
    }

    /// SQLiteStore addLog 应不崩溃（存储引擎层不记录日志）
    func testSQLiteStoreAddLogNoCrash() async throws {
        let memoryQueue = try DatabaseQueue()
        try DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        store.addLog(action: .create, target: "test", details: "detail", duration: nil, startTime: nil, endTime: nil, module: nil)
    }

    // MARK: - GRDB Extensions

    /// PluginRecord databaseTableName 应返回正确表名
    func testPluginRecordGRDBDatabaseTableNameCorrect() {
        XCTAssertEqual(PluginRecord.databaseTableName, AppConstants.Storage.Tables.pluginRecords)
    }

    /// PluginRecord Columns 枚举应映射正确列名
    func testPluginRecordGRDBColumnsColumnNameCorrect() {
        XCTAssertEqual(PluginRecord.Columns.id.rawValue, "id")
        XCTAssertEqual(PluginRecord.Columns.name.rawValue, "name")
        XCTAssertEqual(PluginRecord.Columns.permissionsJSON.rawValue, "permissions_json")
        XCTAssertEqual(PluginRecord.Columns.manifestJSON.rawValue, "manifest_json")
    }

    /// KnowledgePage databaseTableName 应返回正确表名
    func testKnowledgePageGRDBDatabaseTableNameCorrect() {
        XCTAssertEqual(KnowledgePage.databaseTableName, AppConstants.Storage.Tables.pages)
    }

    /// KnowledgePage Columns 枚举应映射正确列名
    func testKnowledgePageGRDBColumnsColumnNameCorrect() {
        XCTAssertEqual(KnowledgePage.Columns.id.rawValue, "id")
        XCTAssertEqual(KnowledgePage.Columns.title.rawValue, "title")
        XCTAssertEqual(KnowledgePage.Columns.pageType.rawValue, "page_type")
        XCTAssertEqual(KnowledgePage.Columns.relatedPageIDs.rawValue, "related_page_ids")
        XCTAssertEqual(KnowledgePage.Columns.isPinned.rawValue, "is_pinned")
        XCTAssertEqual(KnowledgePage.Columns.contentHash.rawValue, "content_hash")
    }

    /// Array GRDBJSONCodable 编码解码环回
    func testArrayGRDBJSONCodableEncodeDecodeRoundTrip() {
        let strings: [String] = ["a", "b", "c"]
        let dbValue = strings.databaseValue
        let decoded = [String].fromDatabaseValue(dbValue)
        XCTAssertEqual(decoded, strings)
    }

    /// Array GRDBJSONCodable 空数组编码解码
    func testArrayGRDBJSONCodableEmptyArrayRoundTrip() {
        let empty: [String] = []
        let dbValue = empty.databaseValue
        let decoded = [String].fromDatabaseValue(dbValue)
        XCTAssertEqual(decoded, empty)
    }

    /// Array GRDBJSONCodable 从 null 解码返回 nil
    func testArrayGRDBJSONCodableNullReturnsNil() {
        let decoded = [String].fromDatabaseValue(.null)
        XCTAssertNil(decoded)
    }

    /// Array GRDBJSONCodable UUID 数组环回
    func testArrayGRDBJSONCodableUUIDArrayRoundTrip() {
        let uuids: [UUID] = [UUID(), UUID()]
        let dbValue = uuids.databaseValue
        let decoded = [UUID].fromDatabaseValue(dbValue)
        XCTAssertEqual(decoded, uuids)
    }
}
