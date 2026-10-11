//
//  DatabaseManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：数据库中枢业务装配层（二次拆分后）——基于 UFPStorage GenericDatabaseManager 纯物理引擎，
//           叠加业务扩展：SecurityManager 完整性校验适配、VaultDatabaseSwitcher conform、
//           countPages、L10n/AppConstants/App 层 StorageConstants、事务门禁。
//
import Foundation
import UFPStorage
import UFPCore
import Dependencies

/// DatabaseManager 业务常量（避免魔数）。
private enum DatabaseManagerConstants {
    /// 事务排空的最大等待时长（毫秒）。
    static let drainMaxWaitMilliseconds: Int64 = 1500
}

/// 数据库中枢管理器（DatabaseManager）。
/// 物理引擎逻辑（建库/连接池/WAL/热切换/降级骨架）已下沉至 UFPStorage `GenericDatabaseManager`，
/// 本类型保留业务装配与安全增强，作为业务层的唯一数据库入口。
@MainActor
final class DatabaseManager: TestStateResettable, @unchecked Sendable {
    
    /// 全局唯一的线程安全单例实例。
    nonisolated static let shared = DatabaseManager()

    /// 底层纯物理引擎（UFPStorage）。
    private let engine: GenericDatabaseManager

    /// 引擎注入是否已完成（惰性配置，避免 nonisolated init 访问 @MainActor 成员）。
    private var engineConfigured = false

    /// 解析 Application Support 目录下的默认数据库 URL（业务常量 AppConstants/CoreConstants）。
    /// - Returns: 默认沙盒数据库文件 URL。
    /// - Throws: 当 Application Support 目录不可用时抛出 `NSError`。
    func defaultSandboxDatabaseURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw NSError(
                domain: CoreConstants.ErrorDomain.insight,
                code: SystemConstants.ErrorCode.default
            )
        }
        return appSupport.appendingPathComponent(AppConstants.Storage.databaseName)
    }
    
    /// 数据库中枢当前的运行状态（业务状态，映射自引擎 GenericDatabaseState）。
    private(set) var state: DatabaseState = .uninitialized {
        didSet {
            NotificationCenter.default.post(name: .databaseStateDidChange, object: nil)
        }
    }
    
    /// 事务门禁（Finding #18 修复）：用 actor 串行化事务计数，消除排空 TOCTOU 竞态。
    let transactionGatekeeper = TransactionGatekeeper()

    /// 并发活跃写入事务计数器（向后兼容，委托给 transactionGatekeeper）。
    var activeTransactionsCount: Int {
        get async { await transactionGatekeeper.activeCount }
    }

    /// 递增活跃写入事务数（事务开始前调用）。
    func incrementActiveTransactions() async throws {
        try await transactionGatekeeper.acquire()
    }

    /// 递减活跃写入事务数（事务结束后调用）。
    func decrementActiveTransactions() async {
        await transactionGatekeeper.release()
    }
    
    /// 专属笔记本数据库写入连接池（委托引擎）。
    var dbWriter: (any DatabaseWriter)? {
        get { engine.dbWriter }
        set { engine.dbWriter = newValue }
    }

    /// 全局配置数据库写入连接池（委托引擎）。
    var globalWriter: (any DatabaseWriter)? {
        get { engine.globalWriter }
        set { engine.globalWriter = newValue }
    }

    /// 当前处于激活状态的专属笔记本数据库物理沙盒文件 URL。
    var dbURL: URL? { engine.dbURL }

    /// 全局共享偏好配置库的物理沙盒文件 URL。
    var globalDBURL: URL? { engine.globalDBURL }
    
    /// 当前数据库管理器是否运行于 Unit Test 单元测试管道中。
    var isInTesting: Bool {
        get { engine.isInTesting }
        set { engine.isInTesting = newValue }
    }
    
    /// 私有化单例构造方法（nonisolated：仅注册测试重置注册表 + 建引擎，允许跨线程初始化）。
    nonisolated private init() {
        self.engine = GenericDatabaseManager()
        TestStateResetRegistry.shared.register(self)
    }

    /// 惰性配置引擎注入（迁移器 + 安全/事务/通知闭包）。所有引擎方法调用前先确保注入就绪。
    private func configureEngineIfNeeded() {
        guard !engineConfigured else { return }
        engineConfigured = true

        engine.vaultMigrator = migrator
        engine.globalMigrator = globalMigrator

        engine.integrityVerifier = { url in
            let isVerified = await SecurityManager.shared.verifyIntegrity(for: url)
            if isVerified { return true }
            #if DEBUG
            await SecurityManager.shared.updateSignature(for: url)
            return true
            #else
            throw NSError(
                domain: StorageConstants.ErrorDomain.databaseManager,
                code: SystemConstants.HTTPStatusCode.forbidden,
                userInfo: [NSLocalizedDescriptionKey: L10n.Security.targetIntegrityVerificationFailed]
            )
            #endif
        }

        engine.integrityCheckHandler = { url in
            let isVerified = await SecurityManager.shared.verifyIntegrity(for: url)
            if !isVerified {
                #if DEBUG
                await SecurityManager.shared.updateSignature(for: url)
                #else
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: .databaseIntegrityCheckFailed,
                        object: nil,
                        userInfo: [StorageConstants.JSONKey.url: url]
                    )
                }
                #endif
            }
        }

        engine.signatureUpdater = { url in
            await SecurityManager.shared.updateSignature(for: url)
        }

        engine.drainTransactions = { [weak self] in
            guard let self else { return true }
            return await self.transactionGatekeeper.drain(
                maxWaitTime: .milliseconds(DatabaseManagerConstants.drainMaxWaitMilliseconds)
            )
        }

        engine.onStateChange = { [weak self] genericState in
            Task { @MainActor [weak self] in
                self?.applyState(genericState)
            }
        }

        engine.onDatabaseDidSwitch = { vaultID, _ in
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .databaseDidSwitch,
                    object: nil,
                    userInfo: [StorageConstants.JSONKey.vaultID: vaultID]
                )
            }
        }
    }

    /// 将引擎通用状态映射为业务状态。
    private func applyState(_ genericState: GenericDatabaseState) {
        switch genericState {
        case .uninitialized: state = .uninitialized
        case .ready: state = .ready
        case .corrupted(let message): state = .corrupted(message)
        }
    }
    
    // MARK: - 初始化方法组
    
    /// 为单元测试管道强制重连与注入内存/临时物理数据库连接池。
    /// - Parameter writer: 由单元测试套件临时开辟的 DatabaseWriter。
    /// - Throws: SQLite Schema 架构自动化迁移异常。
    func setupForTesting(with writer: any DatabaseWriter) throws {
        configureEngineIfNeeded()
        try engine.setupForTesting(with: writer)
    }
    
    /// 初始化全局共享的主配置库连接。
    /// - Parameter url: 物理沙盒中指向 `global.sqlite3` 文件的绝对路径 URL。
    /// - Throws: 目录创建失败或 GRDB 数据库连接池实例化异常。
    func setupGlobal(at url: URL) throws {
        configureEngineIfNeeded()
        try engine.setupGlobal(at: url)
    }

    /// 初始化激活默认专属数据库（vault.sqlite3）连接，并级联初始化 global.sqlite3。
    /// - Parameter url: 指向专属数据库的物理文件 URL 路径。
    /// - Throws: 目录授权、SQLite 实例化或专属 Schema 迁移失败。
    func setup(at url: URL) throws {
        configureEngineIfNeeded()
        try engine.setup(at: url, globalDatabaseName: AppConstants.Storage.globalDatabaseName)
    }
    
    /// 物理热切换当前激活的专属笔记本数据库（Multi-Vault Switching）。
    func switchDatabase(to vaultID: UUID, at url: URL) async throws {
        configureEngineIfNeeded()
        try await engine.switchDatabase(to: vaultID, at: url)
    }
    
    /// 重置并释放所有已挂载的数据库 Pool 连接资源。
    func reset() {
        configureEngineIfNeeded()
        engine.reset()
    }

    /// 强制对指定的数据库连接执行 Schema 架构迁移。
    func migrate(_ writer: any DatabaseWriter) throws {
        configureEngineIfNeeded()
        try engine.migrate(writer)
    }

    /// 确定性物理关闭专属物理数据库连接池，强刷写 WAL 并释放文件描述符。
    func releaseDatabaseConnection() {
        configureEngineIfNeeded()
        engine.releaseDatabaseConnection()
    }

    // MARK: - TestStateResettable

    /// 重置单例状态用于测试隔离
    nonisolated func resetStateForTesting() {
        runOnMainSync {
            reset()
        }
    }
    
    // MARK: - 测试辅助方法

    /// 设置排空状态（仅测试使用）。
    func setDrainingForTesting(_ value: Bool) async {
        await transactionGatekeeper.setDrainingForTesting(value)
    }

    /// 重置排空状态（仅测试使用）。
    func resetDrainingState() async {
        await transactionGatekeeper.reset()
    }
}

// MARK: - VaultDatabaseSwitcher 协议遵循

extension DatabaseManager: VaultDatabaseSwitcher {
    public func countPagesInCurrentVault() async throws -> Int {
        guard let writer = dbWriter else { return 0 }
        return try await writer.read { db in
            try KnowledgePage.fetchCount(db)
        }
    }

    public func countPages(at url: URL) async throws -> Int {
        let dbQueue = try DatabaseQueue(path: url.path)
        return try await dbQueue.read { db in
            try KnowledgePage.fetchCount(db)
        }
    }
}

// MARK: - 核心通知扩展

extension Notification.Name {
    /// 专属数据库多库热切换成功完成时的全局广播通知。
    static let databaseDidSwitch = Notification.Name("databaseDidSwitch")
    /// 数据库物理文件 HMAC 完整性校验失败时的全局广播通知。
    static let databaseIntegrityCheckFailed = Notification.Name("databaseIntegrityCheckFailed")
}

// MARK: - 物理隔离层强类型异常

enum DatabaseError: Error {
    /// 数据库未就绪（dbWriter 为 nil，如启动早期、Vault 热切换瞬态、reset 后）。
    case notReady
    /// 数据库正在排空（Vault 热切换中，拒绝新事务）。
    case draining
}

/// 数据库中枢当前的运行状态。
enum DatabaseState: Sendable, Equatable {
    case uninitialized
    case ready
    case corrupted(String)
    
    /// 判等比较
    static func == (lhs: DatabaseState, rhs: DatabaseState) -> Bool {
        switch (lhs, rhs) {
        case (.uninitialized, .uninitialized): return true
        case (.ready, .ready): return true
        case (.corrupted(let e1), .corrupted(let e2)): return e1 == e2
        default: return false
        }
    }
}

extension Notification.Name {
    /// 数据库运行状态发生改变的全局广播通知。
    static let databaseStateDidChange = Notification.Name("databaseStateDidChange")
}

// MARK: - DependencyKey

enum DatabaseManagerKey: DependencyKey {
    nonisolated static var liveValue: DatabaseManager { DatabaseManager.shared }
    nonisolated static var testValue: DatabaseManager { DatabaseManager.shared }
    nonisolated static var previewValue: DatabaseManager { DatabaseManager.shared }
}

extension DependencyValues {
    nonisolated var databaseManager: DatabaseManager {
        get { self[DatabaseManagerKey.self] }
        set { self[DatabaseManagerKey.self] = newValue }
    }
}
