//
//  DatabaseManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
import Foundation
import UFPStorage

/// DatabaseManager 业务常量（避免魔数）。
private enum DatabaseManagerConstants {
    /// WAL 读写分离连接池的最大并发读取线程数。
    static let maximumReaderCount: Int = 5
}

/// 数据库中枢管理器（DatabaseManager）。
/// 它是知识笔记本高内聚持久化层（Persistence）的基座大脑，托管了专属笔记本数据库（Workspace DB）
/// 和全局共享设置数据库（Global DB）的双轨道生命周期。
@MainActor
final class DatabaseManager {
    
    /// 全局唯一的线程安全单例实例。
    static let shared = DatabaseManager()
    
    /// 数据库中枢当前的运行状态。
    private(set) var state: DatabaseState = .uninitialized {
        didSet {
            NotificationCenter.default.post(name: .databaseStateDidChange, object: nil)
        }
    }
    
    /// 事务门禁（Finding #18 修复）：用 actor 串行化事务计数，消除排空 TOCTOU 竞态。
    let transactionGatekeeper = TransactionGatekeeper()

    /// 并发活跃写入事务计数器（向后兼容，委托给 transactionGatekeeper）。
    /// 注：实际计数在 actor 内串行化，此属性仅供测试同步观察。
    var activeTransactionsCount: Int {
        get async { await transactionGatekeeper.activeCount }
    }

    /// 递增活跃写入事务数（事务开始前调用）。
    /// - Throws: `DatabaseError.draining` 如果正在排空。
    func incrementActiveTransactions() async throws {
        try await transactionGatekeeper.acquire()
    }

    /// 递减活跃写入事务数（事务结束后调用）。
    func decrementActiveTransactions() async {
        await transactionGatekeeper.release()
    }
    
    /// 专属笔记本数据库写入连接池（dbWriter）。
    /// 支持多线程并发读写与 WAL 安全锁隔离，是当前已激活 Vault 的核心数据通道。
    var dbWriter: DatabaseWriter?

    /// 全局配置数据库写入连接池（globalWriter）。
    /// 负责记录多租户 Vault 列表、全库 HMAC 安全防篡改指纹、系统偏好以及操作审计日志。
    var globalWriter: DatabaseWriter?

    /// 当前处于激活状态的专属笔记本数据库物理沙盒文件 URL。
    private(set) var dbURL: URL?

    /// 全局共享偏好配置库的物理沙盒文件 URL。
    private(set) var globalDBURL: URL?
    
    /// 当前数据库管理器是否运行于 Unit Test 单元测试管道中。
    var isInTesting: Bool = false
    
    /// 私有化单例构造方法。
    private init() {}
    
    // MARK: - 初始化方法组
    
    /// 为单元测试管道强制重连与注入内存/临时物理数据库连接池。
    /// - Parameter writer: 由单元测试套件临时开辟的 DatabaseWriter（通常是内存型 DatabaseQueue 实例）。
    /// - Throws: SQLite Schema 架构自动化迁移异常。
    func setupForTesting(with writer: any DatabaseWriter) throws {
        self.dbWriter = writer
        self.isInTesting = true
        
        // 核心步骤 1：对测试环境下的专属瞬态内存主数据库跑 Schema 架构迁移，建立完整的物理表、虚拟表（如 FTS5）与触发器
        try migrator.migrate(writer)
        
        // 核心步骤 2：单独开辟一个独立的内存型全局配置数据库，彻底隔离并规避不同迁移器对 grdb_migrations 表的命名冲突与擦除问题
        let globalQueue = try DatabaseQueue()
        self.globalWriter = globalQueue
        try globalMigrator.migrate(globalQueue)
        
        let tables = try writer.read { db in
            try String.fetchAll(db, sql: ["SELECT", "name", "FROM", "sqlite_master", "WHERE", "type='table'"].joined(separator: " "))
        }
        let globalTables = try globalQueue.read { db in
            try String.fetchAll(db, sql: ["SELECT", "name", "FROM", "sqlite_master", "WHERE", "type='table'"].joined(separator: " "))
        }
        Logger.shared.info(" [DatabaseManager] setupForTesting completed.")
        Logger.shared.info(["-", "Vault", "Tables:", "\(tables)"].joined(separator: StorageConstants.LogConcat.separator))
        Logger.shared.info(["-", "Global", "Tables:", "\(globalTables)"].joined(separator: StorageConstants.LogConcat.separator))
    }
    
    /// 初始化全局共享的主配置库（global.sqlite3）连接。
    /// - Parameter url: 物理沙盒中指向 `global.sqlite3` 文件的绝对路径 URL。
    /// - Throws: 目录创建失败或 GRDB 数据库连接池实例化异常。
    func setupGlobal(at url: URL) throws {
        self.globalDBURL = url
        let path = url.path
        
        // 1. 确保护航目录存在
        let folderURL = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        // 2. 配置连接池并注入物理调优 PRAGMA 参数
        let config = createDatabaseConfiguration()
        
        // 3. 建立连接并自动运行全局迁移
        let globalPool = try DatabasePool(path: path, configuration: config)
        self.globalWriter = globalPool
        
        try globalMigrator.migrate(globalPool)
        Logger.shared.info(" [DatabaseManager] Global main configuration database initialized successfully: \(url.lastPathComponent)")
    }
    
    /// 初始化激活默认专属数据库（vault.sqlite3）连接。
    /// 若专属目录或同级全局配置目录不存在，则会自动创建并级联初始化 `global.sqlite3`。
    /// - Parameter url: 指向专属数据库的物理文件 URL 路径。
    /// - Throws: 目录授权、SQLite 实例化或专属 Schema 迁移失败。
    func setup(at url: URL) throws {
        do {
            // 1. 自动计算并在专属库同级目录下建立独立的 global.sqlite3 全局库
            let globalURL = url.deletingLastPathComponent().appendingPathComponent(AppConstants.Storage.globalDatabaseName)
            try setupGlobal(at: globalURL)
            
            // 2. 连接专属物理库前，异步触发哈希签名防篡改校验 (HMAC-SHA256)
            //    不在 setup() 中同步阻塞等待校验结果，避免 @MainActor + semaphore.wait() 死锁。
            //    校验失败将通过 NotificationCenter 广播通知，由上层 UI 处理。
            if FileManager.default.fileExists(atPath: url.path) {
                scheduleIntegrityVerification(for: url)
            }
            
            // 3. 建立默认专属物理库连接
            self.dbURL = url
            let path = url.path
            let folderURL = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            
            let config = createDatabaseConfiguration()
            let dbPool = try DatabasePool(path: path, configuration: config)
            self.dbWriter = dbPool
            
            // 4. 执行专属库架构迁移
            try migrator.migrate(dbPool)
            
            // 5. 挂载成功后，异步刷新一次物理 HMAC 签名，对齐状态
            scheduleSignatureUpdate(for: url)
            
            self.state = .ready
        } catch {
            Logger.shared.error(" [DatabaseManager] Database setup failed, degrading to in-memory: \(error.localizedDescription)", error: error)
            self.state = .corrupted(error.localizedDescription)
            degradeToInMemory(error: error)
            throw error
        }
    }
    
    // MARK: - 异步 HMAC 签名校验与更新（替代 semaphore.wait 同步阻塞）
    
    /// 异步触发完整性校验，校验失败时广播通知
    private func scheduleIntegrityVerification(for url: URL) {
        Task.detached { [weak self] in
            guard self != nil else { return }
            let isVerified = await SecurityManager.shared.verifyIntegrity(for: url)
            if !isVerified {
                #if DEBUG
                Logger.shared.debug(" [DatabaseManager] DEBUG: Signature_mismatch_during_async_check_realigning")
                await SecurityManager.shared.updateSignature(for: url)
                #else
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .databaseIntegrityCheckFailed,
                        object: nil,
                        userInfo: [StorageConstants.JSONKey.url: url]
                    )
                }
                #endif
            }
        }
    }
    
    /// 异步刷新物理 HMAC 签名
    private func scheduleSignatureUpdate(for url: URL) {
        Task.detached {
            await SecurityManager.shared.updateSignature(for: url)
        }
    }
    
    /// 发生严重故障时，高可用降级至纯内存模式，阻止 DI 崩溃并允许应用启动。
    private func degradeToInMemory(error: Error) {
        do {
            Logger.shared.error("[DatabaseManager] 安全警告：由于错误回退到临时内存数据库配置：\(error.localizedDescription)", error: error)
            
            // 1. 物理重置以清理潜在冲突
            self.dbURL = nil
            self.globalDBURL = nil
            
            // 2. 挂载内存型专属数据库并运行 Schema 架构迁移
            let memoryQueue = try DatabaseQueue()
            self.dbWriter = memoryQueue
            try migrator.migrate(memoryQueue)
            
            // 3. 挂载内存型全局配置库并运行全局 Schema 架构迁移
            let memoryGlobalQueue = try DatabaseQueue()
            self.globalWriter = memoryGlobalQueue
            try globalMigrator.migrate(memoryGlobalQueue)
            
            Logger.shared.info(" [DatabaseManager] Fallback in-memory database successfully initialized.")

            // 4. 降级成功后恢复 state 为 .ready，避免 UI 层持续显示损坏警告
            //    内存数据库已正常工作，用户应看到正常界面而非损坏提示
            self.state = .ready
        } catch {
            // fatalError 审查结论（任务 8）：不可恢复 — 内存数据库是最后的降级手段，
            // 若连内存数据库都无法初始化（极端资源限制/系统损坏），应用无法继续运行。
            // 此场景概率极低，保留 fatalError 确保开发者能从崩溃日志定位问题。
            Logger.shared.error("[DatabaseManager] 内存回退数据库初始化失败，应用无法继续运行: \(error)", error: error)
            fatalError(" Fatal recovery failure: In-memory fallback database could not be initialized: \(error.localizedDescription)")
        }
    }
    
    /// 物理热切换当前激活的专属笔记本数据库（Multi-Vault Switching）。
    /// - Important: 此方法为 `async throws`，替换了原 `semaphore.wait()` 同步阻塞实现，
    ///   消除了 @MainActor + 主线程信号量等待导致的死锁隐患。
    func switchDatabase(to vaultID: UUID, at url: URL) async throws {
        Logger.shared.info(" [DatabaseManager] Starting physical multi-database hot swap => Target: \(url.lastPathComponent)")
        
        // 0. 切换前对目标专属库进行完整性哈希签名防篡改校验
        if FileManager.default.fileExists(atPath: url.path) {
            let isVerified = await SecurityManager.shared.verifyIntegrity(for: url)
            
            if !isVerified {
                #if DEBUG
                Logger.shared.debug(" [DatabaseManager] DEBUG: Target_hash_verification_failed_during_hot_swap_realigning")
                await SecurityManager.shared.updateSignature(for: url)
                #else
                throw NSError(domain: StorageConstants.ErrorDomain.databaseManager, code: 403, userInfo: [NSLocalizedDescriptionKey: L10n.Security.targetIntegrityVerificationFailed])
                #endif
            }
        }
        
        // 1. 【安全核心步骤】：优雅连接排空，异步等待后台写事务结束
        // Finding #18 修复：用 TransactionGatekeeper actor 排空，排空期间拒绝新事务（抛 draining）
        let drained = await transactionGatekeeper.drain(maxWaitTime: .milliseconds(1500))
        if !drained {
            Logger.shared.warning(" [DatabaseManager] switchDatabase warning: Transactions draining timed out. Forcing connection close.")
        } else {
            Logger.shared.info(" [DatabaseManager] switchDatabase: All active transactions drained successfully.")
        }
        
        let oldURL = self.dbURL
        closeWriter(self.dbWriter)
        self.dbWriter = nil
        
        // 旧数据库连接关闭后，WAL 已安全写回，异步更新物理防篡改 HMAC 签名
        if let oldURL = oldURL, FileManager.default.fileExists(atPath: oldURL.path) {
            await SecurityManager.shared.updateSignature(for: oldURL)
            Logger.shared.info(" [DatabaseManager] Closed database connection and updated signature for: \(oldURL.lastPathComponent)")
        }
        
        self.dbURL = url
        
        // 2. 确保目标文件夹在沙盒中物理存在
        let folderURL = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        // 3. 重新配置并开辟新库的并发池连接
        let config = createDatabaseConfiguration()
        let dbPool = try DatabasePool(path: url.path, configuration: config)
        self.dbWriter = dbPool
        
        // 4. 对新专属库自动运行 Schema 迁移
        try migrator.migrate(dbPool)
        Logger.shared.info(" [DatabaseManager] Exclusive physical database successfully switched and remounted => \(url.lastPathComponent)")
        
        // 5. 切换成功，异步刷新物理完整性指纹
        await SecurityManager.shared.updateSignature(for: url)
        
        // 6. 广播通知
        NotificationCenter.default.post(
            name: .databaseDidSwitch,
            object: nil,
            userInfo: [StorageConstants.JSONKey.vaultID: vaultID]
        )
    }
    
    // MARK: - 数据库高性能配置
    
    /// 构建极尽压榨物理 I/O 并发吞吐的 SQLite 高性能配置
    /// 包含：WAL 读写分离最大并发度、NORMAL 同步级别、内存 temp_store、10MB 连接页缓存、256MB mmap 内存映射与 5秒锁延迟。
    private func createDatabaseConfiguration() -> Configuration {
        var config = Configuration()
        
        // 1. 设置并发读取最大线程数（WAL 读写分离高阶连接池）
        config.maximumReaderCount = DatabaseManagerConstants.maximumReaderCount
        // 2. 将读取线程的系统优先调度级别（QoS）调至用户高优先级，防范卡顿
        config.qos = .userInitiated
        
        config.prepareDatabase { db in
            // 3. 开启物理级外键约束
            try db.execute(sql: ["PRAGMA", "foreign_keys", "=", "ON"].joined(separator: " "))
            // 4. 采用 SQLite NORMAL 同步模式：WAL 模式下的黄金同步级别，兼顾 100% 事务安全性与超高写吞吐
            try db.execute(sql: ["PRAGMA", "synchronous", "=", "NORMAL"].joined(separator: " "))
            // 5. 将临时表及中间索引文件全部强制置于 RAM 内存中，缩短排序耗时
            try db.execute(sql: ["PRAGMA", "temp_store", "=", "MEMORY"].joined(separator: " "))
            // 6. 分配 10MB 的连接级大页面缓存页（缓存大小为 10000 字节，负数代表以 KB 为单位）
            try db.execute(sql: ["PRAGMA", "cache_size", "=", "-10000"].joined(separator: " "))
            // 7. 启用 256MB 的内存映射 I/O，极速加载 FTS5 全文索引虚拟表，免除系统调用开销
            try db.execute(sql: ["PRAGMA", "mmap_size", "=", "268435456"].joined(separator: " "))
            // 8. 设定 5000 毫秒锁等待超时，打消多线程冷读写瞬时争用触发的 SQLITE_BUSY 风险
            try db.execute(sql: ["PRAGMA", "busy_timeout", "=", "5000"].joined(separator: " "))
        }
        
        return config
    }

    /// 重置并释放所有已挂载的数据库 Pool 连接资源（在物理移动、抹除文件或退出登录前必须强制调用）。
    func reset() {
        closeWriter(dbWriter)
        closeWriter(globalWriter)
        dbWriter = nil
        globalWriter = nil
        dbURL = nil
        globalDBURL = nil
    }
    
    /// 强制对指定的数据库连接执行 Schema 架构迁移以重新构建物理表。
    /// - Parameter writer: 目标数据库连接写入器 (DatabaseWriter)。
    /// - Throws: 数据库迁移执行异常。
    func migrate(_ writer: any DatabaseWriter) throws {
        try migrator.migrate(writer)
    }
    
    /// 确定性物理关闭 DatabasePool 数据库连接池，强刷写 WAL 并释放文件描述符，防范 vnode 资源残留泄露 (@P1-6)
    private func closeWriter(_ writer: DatabaseWriter?) {
        guard let writer = writer else { return }
        if let dbPool = writer as? DatabasePool {
            do {
                try dbPool.close()
                Logger.shared.info(" [DatabaseManager] DatabasePool connection closed successfully.")
            } catch {
                Logger.shared.error(" [DatabaseManager] Failed to close DatabasePool connection: \(error.localizedDescription)", error: error)
            }
        }
    }
}

// MARK: - VaultDatabaseSwitcher 协议遵循

extension DatabaseManager: VaultDatabaseSwitcher {
    /// 物理断开专属物理数据库连接以闭合通道锁并安全刷新 WAL。
    ///
    /// 此方法显式将 `dbWriter` 置为 nil。通过 Swift ARC 机制，这会触发底层已挂载的
    /// `DatabasePool` 及其全部活跃的 SQLite 读写连接句柄的同步析构与销毁。
    /// 这一步骤是强物理释放 WAL 文件锁、规避 `SQLITE_BUSY` 死锁风险的关键环节。
    public func releaseDatabaseConnection() {
        // 核心步骤：确定性物理关闭 Exclusive Pool 以闭合并写回 WAL 文件锁，防范句柄碎片挂起
        closeWriter(self.dbWriter)
        self.dbWriter = nil
    }

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
