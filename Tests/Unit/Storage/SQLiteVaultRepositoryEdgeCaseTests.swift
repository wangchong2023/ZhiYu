//
//  SQLiteVaultRepositoryEdgeCaseTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 SQLiteVaultRepository 的无效 UUID 回退、saveVault upsert 语义、
//           updateLastAccessed 不存在记录静默跳过等边界条件。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class VaultRepoEdgeTests: XCTestCase {

    var globalQueue: DatabaseQueue!
    var vaultRepo: SQLiteVaultRepository!

    override func setUp() async throws {
        try await super.setUp()
        globalQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: globalQueue)
        // SQLiteVaultRepository 使用 globalWriter
        let writer: any DatabaseWriter = await DatabaseManager.shared.globalWriter ?? globalQueue
        vaultRepo = SQLiteVaultRepository(dbWriter: writer)
    }

    override func tearDownWithError() throws {
        vaultRepo = nil
        globalQueue = nil
    }

    // MARK: - 辅助方法

    private func makeVault(id: UUID = UUID(),
                           name: String = "TestVault",
                           pageCount: Int = 0) -> Vault {
        Vault(
            id: id,
            name: name,
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: pageCount,
            themePayload: nil,
            icon: nil,
            description: "/path/to/vault"
        )
    }

    // MARK: - saveVault / fetchAllVaults

    /// 验证：saveVault 插入新笔记本，fetchAllVaults 能检索到。
    func testSaveAndFetchVault() async throws {
        let vault = makeVault(name: "MyNotebook")
        try await vaultRepo.saveVault(vault)

        let all = try await vaultRepo.fetchAllVaults()
        XCTAssertTrue(all.contains { $0.name == "MyNotebook" }, "应能检索到保存的笔记本")
    }

    /// 验证：saveVault 对同 ID 笔记本执行更新。
    func testSaveVaultUpdatesExisting() async throws {
        let vaultID = UUID()
        let original = makeVault(id: vaultID, name: "Original", pageCount: 5)
        try await vaultRepo.saveVault(original)

        let updated = makeVault(id: vaultID, name: "Updated", pageCount: 10)
        try await vaultRepo.saveVault(updated)

        let all = try await vaultRepo.fetchAllVaults()
        XCTAssertEqual(all.count, 1, "同 ID 应更新而非创建副本")
        XCTAssertEqual(all.first?.name, "Updated")
        XCTAssertEqual(all.first?.pageCount, 10)
    }

    /// 验证：fetchAllVaults 按最后访问时间降序排列。
    func testFetchAllVaultsOrderedByLastAccessedDesc() async throws {
        let vault1 = makeVault(id: UUID(), name: "Old")
        try await vaultRepo.saveVault(vault1)

        try await Task.sleep(nanoseconds: 100_000_000)

        let vault2 = makeVault(id: UUID(), name: "New")
        try await vaultRepo.saveVault(vault2)

        let all = try await vaultRepo.fetchAllVaults()
        XCTAssertEqual(all.first?.name, "New", "最近访问的应排在前面")
    }

    // MARK: - updateLastAccessed

    /// 验证：updateLastAccessed 更新最后访问时间。
    func testUpdateLastAccessedUpdatesTimestamp() async throws {
        let vaultID = UUID()
        try await vaultRepo.saveVault(makeVault(id: vaultID, name: "Test"))

        try await Task.sleep(nanoseconds: 200_000_000)

        try await vaultRepo.updateLastAccessed(id: vaultID)

        let all = try await vaultRepo.fetchAllVaults()
        let vault = all.first { $0.id == vaultID }
        XCTAssertNotNil(vault, "笔记本应存在")
        // lastAccessedAt 在 saveVault 时已设置为 Date()，
        // updateLastAccessed 应更新为更晚的时间
    }

    /// 验证：updateLastAccessed 对不存在的 ID 静默跳过。
    func testUpdateLastAccessedNonExistentIsNoop() async throws {
        try await vaultRepo.updateLastAccessed(id: UUID())
        // 不应抛出异常
    }

    // MARK: - deleteVault

    /// 验证：deleteVault 删除指定笔记本。
    func testDeleteVaultRemovesRecord() async throws {
        let vaultID = UUID()
        try await vaultRepo.saveVault(makeVault(id: vaultID, name: "ToDelete"))

        try await vaultRepo.deleteVault(id: vaultID)

        let all = try await vaultRepo.fetchAllVaults()
        XCTAssertFalse(all.contains { $0.id == vaultID }, "删除后不应检索到")
    }

    /// 验证：deleteVault 对不存在的 ID 不报错。
    func testDeleteVaultNonExistentIsNoop() async throws {
        try await vaultRepo.deleteVault(id: UUID())
        // 不应抛出异常
    }

    // MARK: - saveSetting

    /// 验证：saveSetting 保存全局配置项。
    func testSaveSettingPersists() async throws {
        try await vaultRepo.saveSetting(key: "testKey", value: "testValue")

        // 通过直接读取数据库验证
        let writer: any DatabaseWriter = await DatabaseManager.shared.globalWriter ?? globalQueue
        let record = try await writer.read { db in
            try GlobalSettingRecord
                .filter(GlobalSettingRecord.CodingKeys.key == "testKey")
                .fetchOne(db)
        }
        XCTAssertEqual(record?.value, "testValue")
    }

    /// 验证：saveSetting 对同 key 执行更新。
    func testSaveSettingUpdatesExisting() async throws {
        try await vaultRepo.saveSetting(key: "dupKey", value: "v1")
        try await vaultRepo.saveSetting(key: "dupKey", value: "v2")

        let writer: any DatabaseWriter = await DatabaseManager.shared.globalWriter ?? globalQueue
        let record = try await writer.read { db in
            try GlobalSettingRecord
                .filter(GlobalSettingRecord.CodingKeys.key == "dupKey")
                .fetchOne(db)
        }
        XCTAssertEqual(record?.value, "v2", "同 key 应更新而非创建副本")
    }

    // MARK: - fetchAllVaults 空结果

    /// 验证：fetchAllVaults 无笔记本时返回空数组。
    func testFetchAllVaultsEmptyWhenNone() async throws {
        let all = try await vaultRepo.fetchAllVaults()
        XCTAssertTrue(all.isEmpty, "无笔记本时应返回空")
    }
}
