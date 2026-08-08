//
//  DatabaseManagerDegradationTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 DatabaseManager 降级到内存模式的边界条件与状态一致性。
//

import XCTest
@testable import ZhiYu

// MARK: - DatabaseManager 降级逻辑测试

@MainActor
final class DatabaseManagerDegradationTests: XCTestCase {

    private var tempDir: String!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = NSTemporaryDirectory() + "DBDegradationTests_\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        // 重置单例状态
        DatabaseManager.shared.reset()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        if let tempDir, FileManager.default.fileExists(atPath: tempDir) {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        tempDir = nil
        try await super.tearDown()
    }

    // MARK: - 降级状态一致性测试

    /// 验证 setup 失败后降级到内存模式时，state 是否正确反映实际状态
    /// 问题：degradeToInMemory 成功后，state 仍为 .corrupted 而非 .ready
    /// 导致 UI 层显示"数据库损坏"但实际内存数据库已正常工作
    func testStateAfterDegradationToInMemory() {
        // 使用一个无法创建 DatabasePool 的路径触发降级
        // /dev/null 是特殊文件，无法作为 SQLite 数据库路径
        let invalidPath = "/dev/null/cannot_create_db/vault.sqlite3"

        do {
            try DatabaseManager.shared.setup(at: URL(fileURLWithPath: invalidPath))
            XCTFail("setup 应抛出异常")
        } catch {
            // 预期抛出异常
        }

        // 检查降级后的状态
        let state = DatabaseManager.shared.state

        // 降级到内存模式后，dbWriter 应非 nil（内存数据库已挂载）
        XCTAssertNotNil(DatabaseManager.shared.dbWriter,
                        "降级后 dbWriter 应为内存数据库，不应为 nil")

        // 关键断言：state 应该反映"已降级到内存模式"而非"损坏"
        // 如果 state 仍为 .corrupted，说明降级后状态未更新——这是 bug
        if case .corrupted = state {
            // state 为 .corrupted 但 dbWriter 非 nil，状态不一致
            // 这意味着 UI 层会显示"数据库损坏"警告，但实际数据在内存中正常工作
            // 用户无法区分"真的损坏"和"已降级到内存模式"
            XCTFail("降级到内存模式成功后 state 仍为 .corrupted，但 dbWriter 非 nil。" +
                    "状态不一致：UI 会显示损坏警告但实际内存数据库已正常工作。" +
                    "应在 degradeToInMemory 成功后将 state 更新为 .ready 或新增 .degraded 状态")
        }
    }

    // MARK: - 降级后数据持久性测试

    /// 验证降级到内存模式后，数据是否为临时的（app 重启后丢失）
    /// 这是降级模式的预期行为，但用户可能不知道数据在内存中
    func testDegradedDataIsInMemory() throws {
        let invalidPath = "/dev/null/cannot_create_db/vault.sqlite3"

        do {
            try DatabaseManager.shared.setup(at: URL(fileURLWithPath: invalidPath))
            XCTFail("setup 应抛出异常")
        } catch {
            // 预期抛出异常
        }

        // 降级后 dbURL 应为 nil（内存模式无文件路径）
        XCTAssertNil(DatabaseManager.shared.dbURL,
                     "降级到内存模式后 dbURL 应为 nil")

        // dbWriter 应非 nil（内存数据库）
        XCTAssertNotNil(DatabaseManager.shared.dbWriter,
                        "降级后应有内存数据库连接")
    }

    // MARK: - 正常 setup 状态测试

    /// 验证正常 setup 后 state 应为 .ready
    func testNormalSetupStateIsReady() throws {
        let validPath = tempDir + "valid_vault.sqlite3"
        try DatabaseManager.shared.setup(at: URL(fileURLWithPath: validPath))

        XCTAssertEqual(DatabaseManager.shared.state, .ready,
                       "正常 setup 后 state 应为 .ready")
        XCTAssertNotNil(DatabaseManager.shared.dbWriter)
        XCTAssertNotNil(DatabaseManager.shared.dbURL)
    }

    // MARK: - 重复 setup 测试

    /// 验证先失败再成功 setup 的状态恢复
    func testRecoveryAfterFailedSetup() throws {
        // 第一次 setup 失败
        let invalidPath = "/dev/null/cannot_create_db/vault.sqlite3"
        do {
            try DatabaseManager.shared.setup(at: URL(fileURLWithPath: invalidPath))
            XCTFail("setup 应抛出异常")
        } catch {
            // 预期失败
        }

        // 重置后第二次 setup 成功
        DatabaseManager.shared.reset()
        let validPath = tempDir + "recovery_vault.sqlite3"
        try DatabaseManager.shared.setup(at: URL(fileURLWithPath: validPath))

        XCTAssertEqual(DatabaseManager.shared.state, .ready,
                       "重置后成功 setup，state 应恢复为 .ready")
    }
}
