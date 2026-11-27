//
//  GenericDatabaseManager.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：纯物理 SQLite/GRDB 引擎——建库/连接池/WAL/多库热切换/降级骨架。
//           完整性校验、数据库文件名、事务排空与通知均通过闭包/参数注入，零业务符号。
//

import Foundation
import UFPCore

/// 通用数据库运行状态（与业务完全无关）。
public enum GenericDatabaseState: Sendable, Equatable {
    /// 尚未初始化。
    case uninitialized
    /// 就绪（含正常挂载与降级到内存模式后的就绪态）。
    case ready
    /// 已损坏（携带错误描述）。
    case corrupted(String)

    /// 判等比较。
    public static func == (lhs: GenericDatabaseState, rhs: GenericDatabaseState) -> Bool {
        switch (lhs, rhs) {
        case (.uninitialized, .uninitialized): return true
        case (.ready, .ready): return true
        case (.corrupted(let e1), .corrupted(let e2)): return e1 == e2
        default: return false
        }
    }
}

/// 纯物理数据库引擎（GenericDatabaseManager）。
///
/// 托管专属数据库与全局共享数据库的双轨道生命周期：建库、连接池、WAL 配置、
/// 多库热切换与故障降级骨架。所有业务相关能力（完整性校验、签名更新、事务排空、
/// 状态通知、数据库文件名）通过闭包/参数注入，本类型不引用任何业务符号。
public final class GenericDatabaseManager: TestStateResettable, @unchecked Sendable {

    /// 全局唯一的线程安全单例实例（供自注册与便捷访问；可实例化多个用于测试）。
    nonisolated static let shared = GenericDatabaseManager()

    /// 当前运行状态。
    public private(set) var state: GenericDatabaseState = .uninitialized {
        didSet {
            onStateChange?(state)
        }
    }

    /// 专属数据库写入连接池（dbWriter）。
    public var dbWriter: (any DatabaseWriter)?

    /// 全局配置数据库写入连接池（globalWriter）。
    public var globalWriter: (any DatabaseWriter)?

    /// 当前激活的专属数据库物理沙盒文件 URL。
    public private(set) var dbURL: URL?

    /// 全局共享偏好配置库的物理沙盒文件 URL。
    public private(set) var globalDBURL: URL?

    /// 是否运行于 Unit Test 单元测试管道中。
    public var usesTransientStorage: Bool = false

    /// 挂起的异步签名刷新任务（保证 releaseDatabaseConnection / setup 与后续 switchDatabase 串行，消除 WAL 签名竞态）。
    private var pendingSignatureTask: Task<Void, Never>?

    /// 切库串行化协调器（保证并发多 Vault 热切换按 FIFO 严格串行，杜绝交错关闭连接池与 dbURL/dbWriter 错配）。
    private let switchSerializer = DatabaseSwitchSerializer()

    // MARK: - 注入点（业务能力通过闭包注入，本类型零业务依赖）

    /// 完整性校验闭包（多库热切换前调用）。返回是否通过；失败时应自行抛出业务错误。
    public var integrityVerifier: ((URL) async throws -> Bool)?

    /// 异步完整性校验处理器（setup 启动时异步触发，内部自含 DEBUG 重签 / Release 通知逻辑）。
    public var integrityCheckHandler: ((URL) async -> Void)?

    /// 异步刷新物理签名闭包。
    public var signatureUpdater: ((URL) async -> Void)?

    /// 事务排空闭包（热切换前优雅等待活跃写事务结束），返回是否在超时前排空成功。
    public var drainTransactions: (@Sendable () async -> Bool)?

    /// 状态变更回调（供上层映射业务状态或广播通知）。
    public var onStateChange: (@Sendable (GenericDatabaseState) -> Void)?

    /// 多库热切换成功回调（供上层广播业务通知）。
    public var onDatabaseDidSwitch: (@Sendable (UUID, URL) -> Void)?

    /// 专属数据库迁移执行器（业务 schema 由上层注入）。
    public var vaultMigrator: GenericSchemaMigrator?

    /// 全局数据库迁移执行器（业务 schema 由上层注入）。
    public var globalMigrator: GenericSchemaMigrator?

    /// 私有化构造：单例自注册到测试状态重置注册表。
    public init() {
        TestStateResetRegistry.shared.register(self)
    }

    // MARK: - 初始化方法组

    /// 初始化全局共享主配置库连接。
    /// - Parameter url: 指向全局库文件的绝对路径 URL。
    /// - Throws: 目录创建失败或连接池实例化异常。
    public func setupGlobal(at url: URL) throws {
        self.globalDBURL = url
        guard let globalMigrator else {
            throw DatabaseError.migratorNotConfigured("globalMigrator")
        }
        let globalPool = try createAndMigrateDatabase(at: url, migrator: globalMigrator)
        self.globalWriter = globalPool
        MinimalLogger.shared.info(" [GenericDatabaseManager] Global main configuration database initialized successfully: \(url.lastPathComponent)")
    }

    /// 初始化激活默认专属数据库连接，并级联初始化全局库。
    /// - Parameters:
    ///   - url: 专属数据库物理文件 URL。
    ///   - globalDatabaseName: 全局库文件名（由上层注入，本类型不引用 App 常量）。
    /// - Throws: 目录授权、SQLite 实例化或专属 Schema 迁移失败。
    public func setup(at url: URL, globalDatabaseName: String) throws {
        do {
            // 1. 自动计算并在专属库同级目录下建立独立的全局库
            let globalURL = url.deletingLastPathComponent().appendingPathComponent(globalDatabaseName)
            try setupGlobal(at: globalURL)

            // 2. 连接专属物理库前，异步触发完整性校验（不阻塞，失败由上层通知处理）
            if FileManager.default.fileExists(atPath: url.path) {
                scheduleIntegrityVerification(for: url)
            }

            // 3. 建立默认专属物理库连接
            self.dbURL = url
            guard let vaultMigrator else {
                throw DatabaseError.migratorNotConfigured("vaultMigrator")
            }
            let dbPool = try createAndMigrateDatabase(at: url, migrator: vaultMigrator)
            self.dbWriter = dbPool

            // 4. 挂载成功后异步刷新一次物理签名
            scheduleSignatureUpdate(for: url)

            self.state = .ready
        } catch {
            MinimalLogger.shared.error(" [GenericDatabaseManager] Database setup failed, degrading to in-memory: \(error.localizedDescription)")
            self.state = .corrupted(error.localizedDescription)
            degradeToInMemory(error: error)
            throw error
        }
    }

    /// 配置瞬态数据库连接及独立的内存全局库，供临时工作区使用。
    /// - Parameter writer: 调用方持有的瞬态 DatabaseWriter。
    /// - Throws: Schema 迁移异常。
    public func setupInMemory(with writer: any DatabaseWriter) throws {
        self.dbWriter = writer
        self.usesTransientStorage = true

        // 对专属瞬态内存主数据库执行迁移
        guard let vaultMigrator else {
            throw DatabaseError.migratorNotConfigured("vaultMigrator")
        }
        try vaultMigrator.migrate(writer)

        // 独立开辟内存型全局库，规避不同迁移器对 grdb_migrations 表的命名冲突
        let globalQueue = try DatabaseQueue()
        self.globalWriter = globalQueue
        guard let globalMigrator else {
            throw DatabaseError.migratorNotConfigured("globalMigrator")
        }
        try globalMigrator.migrate(globalQueue)

        let tables = try fetchTableNames(from: writer)
        let globalTables = try fetchTableNames(from: globalQueue)
        MinimalLogger.shared.info(" [GenericDatabaseManager] setupForTesting completed.")
        MinimalLogger.shared.info(" [GenericDatabaseManager] Vault Tables: \(tables)")
        MinimalLogger.shared.info(" [GenericDatabaseManager] Global Tables: \(globalTables)")
    }

    // MARK: - 异步完整性校验与签名更新

    /// 异步触发完整性校验。
    private func scheduleIntegrityVerification(for url: URL) {
        Task.detached { [weak self] in
            guard let self else { return }
            await self.integrityCheckHandler?(url)
        }
    }

    /// 异步刷新物理签名（串行排队，避免并发切库时竞态）。
    private func scheduleSignatureUpdate(for url: URL) {
        let previousTask = pendingSignatureTask
        pendingSignatureTask = Task.detached { [weak self] in
            await previousTask?.value
            await self?.signatureUpdater?(url)
        }
    }

    /// 发生严重故障时降级至纯内存模式。
    private func degradeToInMemory(error: Error) {
        do {
            MinimalLogger.shared.error("[GenericDatabaseManager] 安全警告：由于错误回退到临时内存数据库配置：\(error.localizedDescription)")

            // 1. 物理重置以清理潜在冲突
            self.dbURL = nil
            self.globalDBURL = nil

            // 2. 挂载内存型专属数据库并运行迁移
            let memoryQueue = try DatabaseQueue()
            self.dbWriter = memoryQueue
            guard let vaultMigrator else {
                throw DatabaseError.migratorNotConfigured("vaultMigrator")
            }
            try vaultMigrator.migrate(memoryQueue)

            // 3. 挂载内存型全局库并运行迁移
            let memoryGlobalQueue = try DatabaseQueue()
            self.globalWriter = memoryGlobalQueue
            guard let globalMigrator else {
                throw DatabaseError.migratorNotConfigured("globalMigrator")
            }
            try globalMigrator.migrate(memoryGlobalQueue)

            MinimalLogger.shared.info(" [GenericDatabaseManager] Fallback in-memory database successfully initialized.")

            // 4. 降级成功后恢复 state 为 .ready
            self.state = .ready
        } catch {
            // 内存库是最后降级手段，若仍失败应用无法继续运行
            MinimalLogger.shared.error("[GenericDatabaseManager] 内存回退数据库初始化失败，应用无法继续运行: \(error.localizedDescription)")
            fatalError(" Fatal recovery failure: In-memory fallback database could not be initialized: \(error.localizedDescription)")
        }
    }

    // MARK: - 多库热切换

    /// 物理热切换当前激活的专属数据库（Multi-Vault Switching）。
    /// - Important: `async throws`，通过 `DatabaseSwitchSerializer` 严格串行化并发切库请求，
    ///   并通过注入的事务排空闭包消除主线程信号量等待死锁隐患。
    public func switchDatabase(to vaultID: UUID, at url: URL) async throws {
        try await switchSerializer.enqueue { [self] in
            try await self.performSwitchDatabase(to: vaultID, at: url)
        }
    }

    /// 实际执行单次物理热切换逻辑（由 `switchSerializer` 保证互斥串行）
    private func performSwitchDatabase(to vaultID: UUID, at url: URL) async throws {
        MinimalLogger.shared.info(" [GenericDatabaseManager] Starting physical multi-database hot swap => Target: \(url.lastPathComponent)")

        // 等待前一次释放连接或初始化触发的签名更新落盘，消除 exitVault → selectVault 竞态
        await pendingSignatureTask?.value
        pendingSignatureTask = nil

        // 0. 切换前对目标专属库进行完整性校验
        if FileManager.default.fileExists(atPath: url.path), let integrityVerifier {
            let isVerified = try await integrityVerifier(url)
            if !isVerified {
                MinimalLogger.shared.debug(" [GenericDatabaseManager] Target integrity verification failed during hot swap.")
            }
        }

        // 1. 优雅连接排空，等待后台写事务结束
        let drained = await drainTransactions?() ?? true
        if !drained {
            MinimalLogger.shared.warning(" [GenericDatabaseManager] switchDatabase warning: Transactions draining timed out. Forcing connection close.")
        } else {
            MinimalLogger.shared.info(" [GenericDatabaseManager] switchDatabase: All active transactions drained successfully.")
        }

        let oldURL = self.dbURL
        closeWriter(self.dbWriter)
        self.dbWriter = nil

        // 旧库关闭后，异步更新物理签名
        if let oldURL, FileManager.default.fileExists(atPath: oldURL.path) {
            await signatureUpdater?(oldURL)
            MinimalLogger.shared.info(" [GenericDatabaseManager] Closed database connection and updated signature for: \(oldURL.lastPathComponent)")
        }

        self.dbURL = url

        // 2. 重新配置并开辟新库连接池，自动运行 Schema 迁移
        guard let vaultMigrator else {
            throw DatabaseError.migratorNotConfigured("vaultMigrator")
        }
        // 缺陷 #82 修复：新库创建/迁移失败时降级到内存模式并重抛，避免留下
        // 「dbURL 已指向新库但 dbWriter == nil」的半开不一致状态（旧连接已关闭不可回滚）。
        do {
            let dbPool = try createAndMigrateDatabase(at: url, migrator: vaultMigrator)
            self.dbWriter = dbPool
        } catch {
            MinimalLogger.shared.error(" [GenericDatabaseManager] Database hot-swap failed, degrading to in-memory: \(error.localizedDescription)")
            self.state = .corrupted(error.localizedDescription)
            degradeToInMemory(error: error)
            throw error
        }

        MinimalLogger.shared.info(" [GenericDatabaseManager] Exclusive physical database successfully switched and remounted => \(url.lastPathComponent)")

        // 3. 切换成功，异步刷新物理签名
        await signatureUpdater?(url)

        // 4. 广播切换回调
        onDatabaseDidSwitch?(vaultID, url)
    }

    // MARK: - 数据库高性能配置

    /// 查询指定数据库连接中所有用户表名。
    private func fetchTableNames(from writer: any DatabaseWriter) throws -> [String] {
        try writer.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
    }

    /// 确保数据库文件所在目录在沙盒中物理存在。
    private func ensureDirectoryExists(at url: URL) throws {
        let folderURL = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }

    /// 在指定 URL 建立数据库连接池并运行迁移。
    private func createAndMigrateDatabase(at url: URL, migrator: GenericSchemaMigrator) throws -> any DatabaseWriter {
        let path = url.path
        try ensureDirectoryExists(at: url)
        let config = createDatabaseConfiguration()
        let pool = try DatabasePool(path: path, configuration: config)
        try migrator.migrate(pool)
        return pool
    }

    /// 构建 SQLite 高性能配置（WAL 读写分离高阶连接池）。
    private func createDatabaseConfiguration() -> Configuration {
        var config = Configuration()

        config.maximumReaderCount = StorageConstants.maximumReaderCount
        config.qos = .userInitiated

        let foreignKeysPragma = "PRAGMA foreign_keys = ON"
        config.prepareDatabase { db in
            try db.execute(sql: foreignKeysPragma)
            try db.execute(sql: "PRAGMA synchronous = \(StorageConstants.synchronousModeNormal)")
            try db.execute(sql: "PRAGMA temp_store = \(StorageConstants.tempStoreMemory)")
            try db.execute(sql: "PRAGMA cache_size = \(StorageConstants.cacheSizeBytes)")
            try db.execute(sql: "PRAGMA mmap_size = \(StorageConstants.mmapSizeBytes)")
            try db.execute(sql: "PRAGMA busy_timeout = \(StorageConstants.busyTimeoutMilliseconds)")
        }

        return config
    }

    // MARK: - 生命周期

    /// 重置并释放所有已挂载的数据库 Pool 连接资源。
    public func reset() {
        closeWriter(dbWriter)
        closeWriter(globalWriter)
        dbWriter = nil
        globalWriter = nil
        dbURL = nil
        globalDBURL = nil
        state = .uninitialized
    }

    /// 对指定数据库连接执行 Schema 迁移。
    public func migrate(_ writer: any DatabaseWriter) throws {
        guard let vaultMigrator else {
            throw DatabaseError.migratorNotConfigured("vaultMigrator")
        }
        try vaultMigrator.migrate(writer)
    }

    /// 确定性物理关闭 DatabasePool 连接池，强刷写 WAL 并释放文件描述符，随后刷新该文件签名。
    public func releaseDatabaseConnection() {
        let closedURL = self.dbURL
        closeWriter(self.dbWriter)
        self.dbWriter = nil
        self.dbURL = nil
        // WAL checkpoint 在 closeWriter 完成后才会改写主 .sqlite3 文件，必须在关闭后立即刷新签名，
        // 否则下次 switchDatabase 回到同一笔记本时会触发 HMAC 哈希不匹配。
        if let closedURL, FileManager.default.fileExists(atPath: closedURL.path) {
            scheduleSignatureUpdate(for: closedURL)
        }
    }

    /// 物理关闭写入连接（强刷 WAL 并释放文件句柄）。
    private func closeWriter(_ writer: (any DatabaseWriter)?) {
        guard let writer else { return }
        if let dbPool = writer as? DatabasePool {
            do {
                try dbPool.close()
                MinimalLogger.shared.info(" [GenericDatabaseManager] DatabasePool connection closed successfully.")
            } catch {
                MinimalLogger.shared.error(" [GenericDatabaseManager] Failed to close DatabasePool connection: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - TestStateResettable

    /// 重置单例状态用于测试隔离。
    public func resetStateForTesting() {
        reset()
    }
}

/// 切库串行化协调器：按 FIFO 顺序串行化所有并发 `switchDatabase` 请求，防止交错关闭连接池。
private actor DatabaseSwitchSerializer {
    private var lastTask: Task<Void, Never>?

    func enqueue<T: Sendable>(_ operation: @Sendable @escaping () async throws -> T) async throws -> T {
        let previous = lastTask
        let task = Task<T, Error> {
            await previous?.value
            return try await operation()
        }
        lastTask = Task {
            _ = try? await task.value
        }
        return try await task.value
    }
}
