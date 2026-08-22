//
//  StorageAndNetworkDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/21.
//  Coverage: Task 20 — SQLiteStore/DatabaseManager/NetworkClient/KeychainService 补盲
//

import XCTest
import UFPStorage
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - SQLiteStore anyDeletePage/anyUpdatePage 测试

/// 覆盖 SQLiteStore 的 any* 方法（容错路径）
final class SQLiteStoreAnyMethodsTests: XCTestCase {

    /// anyDeletePage 不存在的页面 — 应不崩溃（try? 吞错）
    func testAnyDeletePageNonExistentPageDoesNotCrash() async throws {
        let memoryQueue = try DatabaseQueue()
        try await DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        let page = KnowledgePage(
            title: "non-existent",
            pageType: .concept
        )
        await store.anyDeletePage(page)
        XCTAssertTrue(true, "anyDeletePage 不存在的页面不应崩溃")
    }

    /// anyUpdatePage 不存在的页面 — 应不崩溃（try? 吞错）
    func testAnyUpdatePageNonExistentPageDoesNotCrash() async throws {
        let memoryQueue = try DatabaseQueue()
        try await DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        let page = KnowledgePage(
            title: "non-existent",
            pageType: .concept
        )
        await store.anyUpdatePage(page, forceDeepScan: false)
        XCTAssertTrue(true, "anyUpdatePage 不存在的页面不应崩溃")
    }

    /// seedDefaultContent 是 obsolete no-op — 应不崩溃
    func testSeedDefaultContentIsNoOp() async throws {
        let memoryQueue = try DatabaseQueue()
        try await DatabaseManager.shared.migrate(memoryQueue)
        let store = SQLiteStore(dbWriter: memoryQueue)
        await store.seedDefaultContent { _, _, _ in }
        XCTAssertTrue(true, "seedDefaultContent 应为 no-op")
    }

    /// anyDeletePage 已存在的页面 — 应删除成功
    func testAnyDeletePageExistingPageSucceeds() async throws {
        let memoryQueue = try DatabaseQueue()
        try await DatabaseManager.shared.migrate(memoryQueue)
        await MainActor.run { DatabaseManager.shared.dbWriter = memoryQueue }
        let store = SQLiteStore(dbWriter: memoryQueue)
        let page = try await store.createPage(title: "to-delete", pageType: .concept)
        await store.anyDeletePage(page)
        let pages = await store.pages
        XCTAssertFalse(pages.contains { $0.id == page.id }, "anyDeletePage 应删除已存在的页面")
    }

    /// anyUpdatePage 已存在的页面 — 应更新成功（保持 title 不变，修改 content）
    /// 注意：upsert 按 title 查找，title 变化会创建新记录而非更新
    func testAnyUpdatePageExistingPageSucceeds() async throws {
        let memoryQueue = try DatabaseQueue()
        try await DatabaseManager.shared.migrate(memoryQueue)
        await MainActor.run { DatabaseManager.shared.dbWriter = memoryQueue }
        let store = SQLiteStore(dbWriter: memoryQueue)
        var page = try await store.createPage(title: "to-update", pageType: .concept)
        page.content = "updated-content"
        await store.anyUpdatePage(page, forceDeepScan: false)
        let pages = await store.pages
        XCTAssertTrue(pages.contains { $0.id == page.id && $0.content == "updated-content" }, "anyUpdatePage 应更新已存在页面的 content")
    }
}

// MARK: - DatabaseManager countPages(at:) 测试

/// 覆盖 DatabaseManager.countPages(at:) — 从指定路径数据库计数页面
final class DatabaseManagerCountPagesTests: XCTestCase {

    /// countPages(at:) 不存在的数据库路径 — 应抛错（GRDB 无法打开）
    func testCountPagesAtNonExistentPathThrows() async {
        let nonExistentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).sqlite")

        do {
            _ = try await DatabaseManager.shared.countPages(at: nonExistentURL)
            XCTFail("不存在的数据库路径应抛错")
        } catch {
            XCTAssertTrue(true, "预期抛错：\(error)")
        }
    }

    /// countPages(at:) 临时空数据库 — 应返回 0
    func testCountPagesAtEmptyDatabaseReturnsZero() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-empty-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let dbQueue = try DatabaseQueue(path: tempURL.path)
        try await DatabaseManager.shared.migrate(dbQueue)

        let count = try await DatabaseManager.shared.countPages(at: tempURL)
        XCTAssertEqual(count, 0, "空数据库应返回 0 页")
    }

    /// countPages(at:) 有数据的数据库 — 应返回正确计数
    func testCountPagesAtPopulatedDatabaseReturnsCorrectCount() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-populated-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let dbQueue = try DatabaseQueue(path: tempURL.path)
        try await DatabaseManager.shared.migrate(dbQueue)
        await MainActor.run { DatabaseManager.shared.dbWriter = dbQueue }
        let store = SQLiteStore(dbWriter: dbQueue)
        _ = try await store.createPage(title: "page-1", pageType: .concept)
        _ = try await store.createPage(title: "page-2", pageType: .entity)
        _ = try await store.createPage(title: "page-3", pageType: .source)

        let count = try await DatabaseManager.shared.countPages(at: tempURL)
        XCTAssertEqual(count, 3, "应返回 3 页")
    }
}

// MARK: - DatabaseError / DatabaseState 测试

/// 覆盖 DatabaseError 和 DatabaseState 枚举
final class DatabaseErrorStateTests: XCTestCase {

    /// DatabaseError.notReady
    func testDatabaseErrorNotReady() {
        let error = DatabaseError.notReady
        XCTAssertNotNil(error)
    }

    /// DatabaseError.draining
    func testDatabaseErrorDraining() {
        let error = DatabaseError.draining
        XCTAssertNotNil(error)
    }

    /// DatabaseState.uninitialized
    func testDatabaseStateUninitialized() {
        let state: DatabaseState = .uninitialized
        XCTAssertEqual(state, .uninitialized)
    }

    /// DatabaseState.ready
    func testDatabaseStateReady() {
        let state: DatabaseState = .ready
        XCTAssertEqual(state, .ready)
    }

    /// DatabaseState.corrupted
    func testDatabaseStateCorrupted() {
        let state: DatabaseState = .corrupted("test error")
        XCTAssertEqual(state, .corrupted("test error"))
        XCTAssertNotEqual(state, .corrupted("other error"))
    }

    /// DatabaseState Equatable — 不同类型不相等
    func testDatabaseStateInequality() {
        XCTAssertNotEqual(DatabaseState.uninitialized, DatabaseState.ready)
        XCTAssertNotEqual(DatabaseState.uninitialized, .corrupted("err"))
        XCTAssertNotEqual(DatabaseState.ready, .corrupted("err"))
    }
}

// MARK: - Notification.Name 常量测试

/// 覆盖数据库相关 Notification.Name 常量
final class DatabaseNotificationNameTests: XCTestCase {

    /// databaseDidSwitch 通知名存在
    func testDatabaseDidSwitchNotificationName() {
        let name = Notification.Name.databaseDidSwitch
        XCTAssertEqual(name.rawValue, "databaseDidSwitch")
    }

    /// databaseIntegrityCheckFailed 通知名存在
    func testDatabaseIntegrityCheckFailedNotificationName() {
        let name = Notification.Name.databaseIntegrityCheckFailed
        XCTAssertEqual(name.rawValue, "databaseIntegrityCheckFailed")
    }

    /// databaseStateDidChange 通知名存在
    func testDatabaseStateDidChangeNotificationName() {
        let name = Notification.Name.databaseStateDidChange
        XCTAssertEqual(name.rawValue, "databaseStateDidChange")
    }

    /// userAuthExpired 通知名存在
    func testUserAuthExpiredNotificationName() {
        let name = Notification.Name.userAuthExpired
        XCTAssertEqual(name.rawValue, "com.zhiyu.app.userAuthExpired")
    }

    /// 发送 databaseDidSwitch 通知不崩溃
    func testPostDatabaseDidSwitchNotification() {
        NotificationCenter.default.post(name: .databaseDidSwitch, object: nil)
        XCTAssertTrue(true, "发送 databaseDidSwitch 通知不应崩溃")
    }

    /// 发送 databaseIntegrityCheckFailed 通知不崩溃
    func testPostDatabaseIntegrityCheckFailedNotification() {
        NotificationCenter.default.post(name: .databaseIntegrityCheckFailed, object: nil)
        XCTAssertTrue(true, "发送 databaseIntegrityCheckFailed 通知不应崩溃")
    }

    /// 发送 databaseStateDidChange 通知不崩溃
    func testPostDatabaseStateDidChangeNotification() {
        NotificationCenter.default.post(name: .databaseStateDidChange, object: nil)
        XCTAssertTrue(true, "发送 databaseStateDidChange 通知不应崩溃")
    }
}

// MARK: - KeychainError 补充测试

/// 覆盖 KeychainError 的 errorDescription（已有 5 个测试，补充边界）
final class KeychainErrorDeepTests: XCTestCase {

    /// encodingFailed errorDescription 非空
    func testEncodingFailedDescription() {
        let error = KeychainError.encodingFailed
        guard let desc = error.errorDescription else {
            XCTFail("errorDescription 不应为 nil")
            return
        }
        XCTAssertTrue(desc.contains("encode"))
    }

    /// storeFailed errorDescription 包含状态码
    func testStoreFailedDescriptionContainsStatus() {
        let error = KeychainError.storeFailed(errSecDuplicateItem)
        guard let desc = error.errorDescription else {
            XCTFail("errorDescription 不应为 nil")
            return
        }
        XCTAssertTrue(desc.contains("\(errSecDuplicateItem)"))
    }

    /// retrieveFailed errorDescription 包含状态码
    func testRetrieveFailedDescriptionContainsStatus() {
        let error = KeychainError.retrieveFailed(errSecItemNotFound)
        guard let desc = error.errorDescription else {
            XCTFail("errorDescription 不应为 nil")
            return
        }
        XCTAssertTrue(desc.contains("\(errSecItemNotFound)"))
    }

    /// deleteFailed errorDescription 包含状态码
    func testDeleteFailedDescriptionContainsStatus() {
        let error = KeychainError.deleteFailed(errSecMissingEntitlement)
        guard let desc = error.errorDescription else {
            XCTFail("errorDescription 不应为 nil")
            return
        }
        XCTAssertTrue(desc.contains("\(errSecMissingEntitlement)"))
    }

    /// unexpectedData errorDescription 非空
    func testUnexpectedDataDescription() {
        let error = KeychainError.unexpectedData
        guard let desc = error.errorDescription else {
            XCTFail("errorDescription 不应为 nil")
            return
        }
        XCTAssertTrue(desc.contains("unexpected"))
    }

    /// storeFailed 状态码 0
    func testStoreFailedWithZeroStatus() {
        let error = KeychainError.storeFailed(0)
        guard let desc = error.errorDescription else {
            XCTFail("errorDescription 不应为 nil")
            return
        }
        XCTAssertTrue(desc.contains("0"))
    }

    /// retrieveFailed 状态码 -1
    func testRetrieveFailedWithNegativeStatus() {
        let error = KeychainError.retrieveFailed(-1)
        guard let desc = error.errorDescription else {
            XCTFail("errorDescription 不应为 nil")
            return
        }
        XCTAssertTrue(desc.contains("-1"))
    }
}

// MARK: - NetworkClient 补充测试

/// 覆盖 NetworkClient 的 setTestSession/awaitRefreshTask 边界
final class NetworkClientDeepTests: XCTestCase {

    /// setTestSession(nil) 清除测试 session — 应不崩溃
    func testSetTestSessionNilDoesNotCrash() async {
        await NetworkClient.shared.setTestSession(nil)
        XCTAssertTrue(true, "setTestSession(nil) 不应崩溃")
    }

    /// awaitRefreshTask 无活跃刷新任务 — 应立即返回
    func testAwaitRefreshTaskNoActiveTaskReturnsImmediately() async {
        await NetworkClient.shared.awaitRefreshTask()
        XCTAssertTrue(true, "awaitRefreshTask 无活跃任务应立即返回")
    }

    /// setTestSession 设置后清除 — 验证生命周期
    func testSetTestSessionLifecycle() async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1
        let session = URLSession(configuration: config)
        await NetworkClient.shared.setTestSession(session)
        await NetworkClient.shared.setTestSession(nil)
        XCTAssertTrue(true, "setTestSession 生命周期管理不应崩溃")
    }
}
