//
//  SQLitePluginRepositoryEdgeCaseTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 SQLitePluginRepository 的 upsert 语义、updateStats 静默返回、
//           FTS5 搜索降级、deleteAll 清空 FTS 索引等边界条件。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class PluginRepoEdgeTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var globalWriter: DatabaseQueue!
    var pluginRepo: SQLitePluginRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        let writer: any DatabaseWriter = await DatabaseManager.shared.globalWriter ?? dbQueue
        // 缺陷 #9 绕过：globalMigrator 未创建 plugin_records 表，手动创建
        try await writer.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS plugin_records (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    version TEXT NOT NULL,
                    author TEXT NOT NULL,
                    source TEXT NOT NULL DEFAULT 'local',
                    status TEXT NOT NULL DEFAULT 'active',
                    permissions_json TEXT NOT NULL DEFAULT '[]',
                    load_duration REAL NOT NULL DEFAULT 0,
                    unload_duration REAL NOT NULL DEFAULT 0,
                    total_execution_time REAL NOT NULL DEFAULT 0,
                    call_count INTEGER NOT NULL DEFAULT 0,
                    installed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    manifest_json TEXT NOT NULL DEFAULT ''
                )
                """)
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS plugin_records_fts USING fts5(
                    id UNINDEXED, name, author, description
                )
                """)
        }
        pluginRepo = SQLitePluginRepository(dbWriter: writer)
    }

    override func tearDownWithError() throws {
        pluginRepo = nil
        globalWriter = nil
        dbQueue = nil
    }

    // MARK: - 辅助方法

    private func makePluginRecord(id: String = "test-plugin",
                                  name: String = "Test Plugin",
                                  version: String = "1.0.0",
                                  author: String = "TestAuthor") -> PluginRecord {
        PluginRecord(
            id: id,
            name: name,
            version: version,
            author: author,
            source: "builtin",
            status: "installed",
            permissionsJSON: "[]",
            loadDuration: 0,
            unloadDuration: 0,
            totalExecutionTime: 0,
            callCount: 0,
            manifestJSON: "{\"descriptions\":{\"en\":\"A test plugin\"}}"
        )
    }

    // MARK: - save upsert 语义

    /// 验证：save 对已存在的插件执行更新而非插入。
    func testSaveUpdatesExistingPlugin() async throws {
        let record = makePluginRecord(name: "Original", version: "1.0.0")
        try await pluginRepo.save(record)

        let updated = makePluginRecord(name: "Updated", version: "2.0.0")
        try await pluginRepo.save(updated)

        let all = try await pluginRepo.fetchAllInstalled()
        XCTAssertEqual(all.count, 1, "同 ID 插件应更新而非创建副本")
        XCTAssertEqual(all.first?.name, "Updated")
        XCTAssertEqual(all.first?.version, "2.0.0")
    }

    /// 验证：save 新插件执行插入。
    func testSaveInsertsNewPlugin() async throws {
        let record = makePluginRecord(id: "new-plugin", name: "New Plugin")
        try await pluginRepo.save(record)

        let fetched = try await pluginRepo.fetch(id: "new-plugin")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "New Plugin")
    }

    // MARK: - updateStats 静默返回

    /// 验证：updateStats 对不存在的插件 ID 静默返回，不抛错也不创建。
    func testUpdateStatsNonExistentPluginIsSilentNoop() async throws {
        try await pluginRepo.updateStats(
            id: "non-existent",
            loadDuration: 1.0,
            unloadDuration: 0.5,
            totalExecutionTime: 10.0,
            callCount: 5,
            status: "active"
        )

        let fetched = try await pluginRepo.fetch(id: "non-existent")
        XCTAssertNil(fetched, "不存在的插件不应被创建")
    }

    /// 验证：updateStats 只更新提供的字段，nil 字段保持不变。
    func testUpdateStatsPartialUpdatePreservesOtherFields() async throws {
        var record = makePluginRecord()
        record.callCount = 10
        record.totalExecutionTime = 100.0
        try await pluginRepo.save(record)

        // 只更新 callCount，其他字段传 nil
        try await pluginRepo.updateStats(
            id: "test-plugin",
            loadDuration: nil,
            unloadDuration: nil,
            totalExecutionTime: nil,
            callCount: 20,
            status: nil
        )

        let fetched = try await pluginRepo.fetch(id: "test-plugin")
        XCTAssertEqual(fetched?.callCount, 20, "callCount 应被更新")
        XCTAssertEqual(fetched?.totalExecutionTime, 100.0, "totalExecutionTime 应保持不变")
    }

    /// 验证：updateStats 更新状态字段。
    func testUpdateStatsUpdatesStatus() async throws {
        let record = makePluginRecord()
        try await pluginRepo.save(record)

        try await pluginRepo.updateStats(
            id: "test-plugin",
            loadDuration: nil,
            unloadDuration: nil,
            totalExecutionTime: nil,
            callCount: nil,
            status: "running"
        )

        let fetched = try await pluginRepo.fetch(id: "test-plugin")
        XCTAssertEqual(fetched?.status, "running")
    }

    // MARK: - delete 清理 FTS 索引

    /// 验证：delete 同时清理主表和 FTS5 索引。
    func testDeleteRemovesPluginAndFTSIndex() async throws {
        let record = makePluginRecord(id: "del-plugin", name: "DeleteMe")
        try await pluginRepo.save(record)

        // 确认能搜索到
        let searchResults = try await pluginRepo.search(query: "DeleteMe")
        XCTAssertFalse(searchResults.isEmpty, "保存后应能搜索到")

        try await pluginRepo.delete(id: "del-plugin")

        let fetched = try await pluginRepo.fetch(id: "del-plugin")
        XCTAssertNil(fetched, "删除后主表记录应不存在")

        // FTS 索引也应被清理
        let searchAfterDelete = try await pluginRepo.search(query: "DeleteMe")
        XCTAssertTrue(searchAfterDelete.isEmpty, "删除后 FTS 索引应被清理")
    }

    /// 验证：delete 不存在的 ID 不报错。
    func testDeleteNonExistentIsNoop() async throws {
        try await pluginRepo.delete(id: "non-existent")
        // 不应抛出异常
    }

    // MARK: - deleteAll 清空

    /// 验证：deleteAll 清空所有插件和 FTS 索引。
    func testDeleteAllClearsEverything() async throws {
        try await pluginRepo.save(makePluginRecord(id: "p1", name: "Plugin1"))
        try await pluginRepo.save(makePluginRecord(id: "p2", name: "Plugin2"))

        try await pluginRepo.deleteAll()

        let all = try await pluginRepo.fetchAllInstalled()
        XCTAssertTrue(all.isEmpty, "deleteAll 后应无插件记录")

        let searchResults = try await pluginRepo.search(query: "Plugin")
        XCTAssertTrue(searchResults.isEmpty, "deleteAll 后 FTS 索引也应清空")
    }

    // MARK: - search 降级

    /// 验证：search 对空查询返回结果（LIKE %% 匹配全部）或空结果。
    func testSearchWithEmptyQuery() async throws {
        try await pluginRepo.save(makePluginRecord(name: "TestPlugin"))

        let results = try await pluginRepo.search(query: "")
        // LIKE "%%" 匹配所有记录
        XCTAssertFalse(results.isEmpty, "空查询 LIKE '%%' 应匹配所有记录")
    }

    /// 验证：search 对不存在的关键词返回空。
    func testSearchNonExistentReturnsEmpty() async throws {
        try await pluginRepo.save(makePluginRecord(name: "RealPlugin"))

        let results = try await pluginRepo.search(query: "NonExistentPluginName12345")
        XCTAssertTrue(results.isEmpty, "不存在的关键词应返回空")
    }

    /// 验证：search 通过 author 字段也能匹配。
    func testSearchMatchesAuthorField() async throws {
        try await pluginRepo.save(makePluginRecord(name: "MyPlugin", author: "SpecialAuthor"))

        let results = try await pluginRepo.search(query: "SpecialAuthor")
        XCTAssertFalse(results.isEmpty, "应能通过 author 字段搜索到")
        XCTAssertEqual(results.first?.author, "SpecialAuthor")
    }

    // MARK: - fetchAllInstalled 排序

    /// 验证：fetchAllInstalled 按 updatedAt 降序排列。
    func testFetchAllInstalledOrderedByUpdatedAtDesc() async throws {
        let old = makePluginRecord(id: "old", name: "Old")
        try await pluginRepo.save(old)

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let new = makePluginRecord(id: "new", name: "New")
        try await pluginRepo.save(new)

        let all = try await pluginRepo.fetchAllInstalled()
        XCTAssertEqual(all.first?.id, "new", "最新更新的应排在前面")
        XCTAssertEqual(all.last?.id, "old", "最早更新的应排在后面")
    }
}
