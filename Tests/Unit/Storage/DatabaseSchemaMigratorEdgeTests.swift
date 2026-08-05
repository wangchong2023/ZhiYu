//
//  DatabaseSchemaMigratorEdgeTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 DatabaseSchemaMigrator 的迁移幂等性、表完整性、缺陷 #9
//           （globalMigrator 缺失 plugin_records 表）回归测试。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class DatabaseSchemaMigratorEdgeTests: XCTestCase {

    var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
    }

    override func tearDownWithError() throws {
        dbQueue = nil
    }

    // MARK: - 专属笔记本库表完整性

    /// 验证：migrator 创建所有预期表。
    func testVaultMigratorCreatesAllExpectedTables() async throws {
        let tables = try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
                .map { $0["name"] as? String ?? "" }
        }

        let expectedTables = [
            KnowledgePage.databaseTableName,
            PageLink.databaseTableName,
            PageChunk.databaseTableName,
            PageEmbedding.databaseTableName,
            TokenUsage.databaseTableName,
            LLMCallLog.databaseTableName,
            RAGEvaluation.databaseTableName,
            TagRecord.databaseTableName,
            PageTagRecord.databaseTableName,
            SRSMetadataRecord.databaseTableName,
            RetrievalSnapshot.databaseTableName,
            RelevanceJudgment.databaseTableName,
            ImportRecord.databaseTableName,
            FeedbackEntry.databaseTableName
        ]

        for expected in expectedTables {
            XCTAssertTrue(tables.contains(expected), "应创建表: \(expected)")
        }
    }

    /// 验证：FTS5 虚拟表已创建。
    func testFTS5VirtualTableCreated() async throws {
        let tables = try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'pages_fts%'")
                .map { $0["name"] as? String ?? "" }
        }

        XCTAssertTrue(tables.contains("pages_fts"), "应创建 pages_fts 虚拟表")
        XCTAssertTrue(tables.contains("pages_fts_data"), "应创建 pages_fts_data 影子表")
        XCTAssertTrue(tables.contains("pages_fts_idx"), "应创建 pages_fts_idx 影子表")
    }

    /// 验证：pages 表的触发器已创建。
    func testPagesTriggersCreated() async throws {
        let triggers = try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name")
                .map { $0["name"] as? String ?? "" }
        }

        XCTAssertTrue(triggers.contains("trigger_update_pages_timestamp"), "应有 updatedAt 自动更新触发器")
        XCTAssertTrue(triggers.contains("pages_ai"), "应有 FTS5 AFTER INSERT 触发器")
        XCTAssertTrue(triggers.contains("pages_ad"), "应有 FTS5 AFTER DELETE 触发器")
        XCTAssertTrue(triggers.contains("pages_au"), "应有 FTS5 AFTER UPDATE 触发器")
    }

    // MARK: - 全局库表完整性

    /// 验证：globalMigrator 创建所有预期表。
    func testGlobalMigratorCreatesAllExpectedTables() async throws {
        let writer = await DatabaseManager.shared.globalWriter
        guard let unwrappedWriter = writer else {
            XCTFail("globalWriter 不应为 nil")
            return
        }
        let tables = try await unwrappedWriter.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
                .map { $0["name"] as? String ?? "" }
        }

        let expectedTables = [
            VaultRecord.databaseTableName,
            FileSignatureRecord.databaseTableName,
            GlobalSettingRecord.databaseTableName,
            AuditLogRecord.databaseTableName
        ]

        for expected in expectedTables {
            XCTAssertTrue(tables.contains(expected), "全局库应创建表: \(expected)")
        }
    }

    // MARK: - 缺陷 #9 回归测试：globalMigrator 创建 plugin_records 表

    /// 验证：globalMigrator 已创建 plugin_records 表（缺陷 #9 已修复）。
    func testGlobalMigratorCreatesPluginRecordsTable_Bug9() async throws {
        let writer = await DatabaseManager.shared.globalWriter
        guard let unwrappedWriter = writer else {
            XCTFail("globalWriter 不应为 nil")
            return
        }
        let tables = try await unwrappedWriter.read { db in
            try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='plugin_records'")
                .map { $0["name"] as? String ?? "" }
        }

        XCTAssertTrue(tables.contains("plugin_records"),
                       "缺陷 #9 已修复：globalMigrator 应创建 plugin_records 表")
    }

    // MARK: - 迁移幂等性

    /// 验证：重复运行 migrator 不崩溃（幂等性）。
    func testMigratorIsIdempotent() async throws {
        // setupForTesting 已运行一次迁移，再运行一次应不崩溃
        let migrator = await DatabaseManager.shared.migrator
        try migrator.migrate(dbQueue)
        // 不应抛出异常
    }

    /// 验证：重复运行 globalMigrator 不崩溃（幂等性）。
    func testGlobalMigratorIsIdempotent() async throws {
        let writer = await DatabaseManager.shared.globalWriter
        guard let unwrappedWriter = writer else {
            XCTFail("globalWriter 不应为 nil")
            return
        }
        let migrator = await DatabaseManager.shared.globalMigrator
        try migrator.migrate(unwrappedWriter)
        // 不应抛出异常
    }

    // MARK: - V5/V10/V11 幂等列检查

    /// 验证：RAGEvaluation 表包含 V5/V10/V11 新增列。
    func testRAGEvaluationHasExtendedColumns() async throws {
        let columns = try await dbQueue.read { db in
            try db.columns(in: RAGEvaluation.databaseTableName).map(\.name)
        }

        XCTAssertTrue(columns.contains(RAGEvaluation.Columns.hallucinationRate.name), "应有 hallucinationRate 列（V5）")
        XCTAssertTrue(columns.contains(RAGEvaluation.Columns.citationAccuracy.name), "应有 citationAccuracy 列（V5）")
        XCTAssertTrue(columns.contains(RAGEvaluation.Columns.answerCorrectness.name), "应有 answerCorrectness 列（V10）")
        XCTAssertTrue(columns.contains(RAGEvaluation.Columns.contextSufficiency.name), "应有 contextSufficiency 列（V11）")
        XCTAssertTrue(columns.contains(RAGEvaluation.Columns.userRating.name), "应有 userRating 列（V12）")
    }

    /// 验证：FeedbackEntry 表包含 V13 新增 status 列。
    func testFeedbackEntryHasStatusColumn() async throws {
        let columns = try await dbQueue.read { db in
            try db.columns(in: FeedbackEntry.databaseTableName).map(\.name)
        }

        XCTAssertTrue(columns.contains(FeedbackEntry.CodingKeys.status.rawValue), "应有 status 列（V13）")
    }

    /// 验证：ImportRecord 表包含 V8 新增 tags 列。
    func testImportRecordHasTagsColumn() async throws {
        let columns = try await dbQueue.read { db in
            try db.columns(in: ImportRecord.databaseTableName).map(\.name)
        }

        XCTAssertTrue(columns.contains(ImportRecord.CodingKeys.tags.name), "应有 tags 列（V8）")
    }

    // MARK: - 外键约束

    /// 验证：page_chunks 表有外键引用 pages 表。
    func testPageChunksHasForeignKeyToPages() async throws {
        let fkInfo = try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA foreign_key_list(page_chunks)")
        }
        XCTAssertFalse(fkInfo.isEmpty, "page_chunks 应有外键约束")
        let referencesPages = fkInfo.contains { ($0["table"] as? String) == "pages" }
        XCTAssertTrue(referencesPages, "page_chunks 外键应引用 pages")
    }

    /// 验证：page_embeddings 表有外键引用 pages 表。
    func testPageEmbeddingsHasForeignKeyToPages() async throws {
        let fkInfo = try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA foreign_key_list(page_embeddings)")
        }
        XCTAssertFalse(fkInfo.isEmpty, "page_embeddings 应有外键约束")
        let referencesPages = fkInfo.contains { ($0["table"] as? String) == "pages" }
        XCTAssertTrue(referencesPages, "page_embeddings 外键应引用 pages")
    }

    /// 验证：links 表有外键引用 pages 表（双向）。
    func testLinksHasForeignKeysToPages() async throws {
        let fkInfo = try await dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA foreign_key_list(links)")
        }
        XCTAssertGreaterThanOrEqual(fkInfo.count, 2, "links 应有至少 2 个外键（source + target）")
        let referencesPages = fkInfo.filter { ($0["table"] as? String) == "pages" }.count
        XCTAssertEqual(referencesPages, 2, "links 两个外键都应引用 pages")
    }

    // MARK: - 唯一约束

    /// 验证：pages.title 有 UNIQUE 约束。
    func testPagesTitleIsUnique() async throws {
        // UNIQUE 内联在 CREATE TABLE 中，通过插入重复 title 验证
        try await dbQueue.write { db in
            try db.execute(sql: "INSERT INTO pages (id, title, page_type, content, status, confidence, is_pinned, lamport_timestamp, created_at, updated_at) VALUES (randomblob(16), 'unique-test', 'concept', '', 'active', 'medium', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
        }
        do {
            try await dbQueue.write { db in
                try db.execute(sql: "INSERT INTO pages (id, title, page_type, content, status, confidence, is_pinned, lamport_timestamp, created_at, updated_at) VALUES (randomblob(16), 'unique-test', 'concept', '', 'active', 'medium', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
            }
            XCTFail("重复 title 应触发 UNIQUE 约束")
        } catch {
            // 预期抛出约束冲突错误
        }
    }

    /// 验证：tags.name 有 UNIQUE 约束。
    func testTagsNameIsUnique() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "INSERT INTO tags (id, name, created_at) VALUES ('unique-tag', 'UniqueTag', CURRENT_TIMESTAMP)")
        }
        do {
            try await dbQueue.write { db in
                try db.execute(sql: "INSERT INTO tags (id, name, created_at) VALUES ('unique-tag-2', 'UniqueTag', CURRENT_TIMESTAMP)")
            }
            XCTFail("重复 name 应触发 UNIQUE 约束")
        } catch {
            // 预期抛出约束冲突错误
        }
    }
}
