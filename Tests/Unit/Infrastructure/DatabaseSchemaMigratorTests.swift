//
//  DatabaseSchemaMigratorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 DatabaseSchemaMigrator 开展自动化单元测试验证。
//
import XCTest
import UFPStorage
@testable import ZhiYu

final class DatabaseSchemaMigratorTests: XCTestCase {

    nonisolated(unsafe) var dbQueue: DatabaseQueue!
    nonisolated(unsafe) var globalQueue: DatabaseQueue!

    override func setUpWithError() throws {
        // 创建独立的内存数据库
        dbQueue = try DatabaseQueue()
        globalQueue = try DatabaseQueue()
    }

    override func tearDownWithError() throws {
        dbQueue = nil
        globalQueue = nil
    }

    @MainActor func testMigratorCreatesVaultTables() throws {
        let manager = DatabaseManager.shared
        manager.isInTesting = true
        
        // 执行迁移
        try manager.migrator.migrate(dbQueue)
        
        // 验证表是否存在
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists(KnowledgePage.databaseTableName), "pages 表应该被创建")
            XCTAssertTrue(try db.tableExists(PageChunk.databaseTableName), "pageChunks 表应该被创建")
            XCTAssertTrue(try db.tableExists(PageLink.databaseTableName), "links 表应该被创建")
            XCTAssertTrue(try db.tableExists(TagRecord.databaseTableName), "tags 表应该被创建")
        }
    }

    @MainActor func testGlobalMigratorCreatesGlobalTables() throws {
        let manager = DatabaseManager.shared
        manager.isInTesting = true
        
        // 执行迁移
        try manager.globalMigrator.migrate(globalQueue)
        
        // 验证表是否存在
        try globalQueue.read { db in
            XCTAssertTrue(try db.tableExists(VaultRecord.databaseTableName), "globalVaults 表应该被创建")
            XCTAssertTrue(try db.tableExists(FileSignatureRecord.databaseTableName), "fileSignatures 表应该被创建")
            XCTAssertTrue(try db.tableExists(GlobalSettingRecord.databaseTableName), "globalSettings 表应该被创建")
        }
    }
}
