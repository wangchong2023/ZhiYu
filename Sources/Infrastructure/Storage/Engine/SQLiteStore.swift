//
//  SQLiteStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
import Foundation
import Combine
import UFPStorage

/// 核心持久化存储引擎 (L1Actor)
/// 采用 actor 模式确保多端并发下的数据一致性，封装复杂的 SQL 事务。
public actor SQLiteStore: AnyPageStoreCapabilities {
    
    // ── 内存缓存 ──
    private var _pages: [KnowledgePage] = []
    
    // ── 物理写入器 ──
    private var dbWriter: any DatabaseWriter {
        get async {
            // 等待 notebook 切换完成（selectVault 异步 Task 可能尚未完成）
            // 使用直接 await 避免 MainActor.run 在 XCTest 并行 worker 中死锁
            for _ in 0..<20 {
                if let writer = await DatabaseManager.shared.dbWriter {
                    return writer
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms × 20 = 1s
            }
            // 极端降级：DatabaseQueue() 创建在调用方 actor 上执行
            do { return try DatabaseQueue() } catch { fatalError("无法创建内存数据库(SQLiteStore): \(error)") }
        }
    }
    
    // ── 仓库依赖 (DI) ──
    private let knowledgeRepository: any KnowledgeRepository
    private let vectorRepository: any VectorRepository
    private let governanceRepository: any RAGGovernanceRepository
    
    // ── 助手服务 ──
    public let embeddingProvider: any EmbeddingProvider

    // MARK: - 初始化
    
    public init(dbWriter: any DatabaseWriter) {
        let knowledgeRepo = KnowledgePageRepository(dbWriter: dbWriter)
        let vectorRepo = VectorDataRepository(dbWriter: dbWriter)
        let governanceRepo = RAGGovernanceSQLiteStore()
        
        self.knowledgeRepository = knowledgeRepo
        self.vectorRepository = vectorRepo
        self.governanceRepository = governanceRepo
        self.embeddingProvider = EmbeddingManager(repository: vectorRepo)
        
        // 初始同步
        Task {
            await reloadFromDisk()
        }
    }

    // MARK: - 基础访问 (AnyPageStoreCapabilities)
    
    public var pages: [KnowledgePage] { _pages }
    
    /// reloadFromDisk
    public func reloadFromDisk() async {
        _pages = (try? await knowledgeRepository.fetchAll()) ?? []
        if let url = await DatabaseManager.shared.dbURL {
            await SecurityManager.shared.updateSignature(for: url)
        }
    }

    /// 全量获取页面列表
    public func fetchAllPages() async throws -> [KnowledgePage] {
        try await knowledgeRepository.fetchAll()
    }

    // MARK: - 页面操作

    /// 创建Page
    public func createPage(
        title: String,
        pageType: PageType,
        customIcon: String? = nil,
        content: String = "",
        tags: [String] = [],
        sourceURL: String? = nil,
        rawSnippet: String? = nil,
        fileSize: Int64? = nil,
        sourceType: String? = nil
    ) async throws -> KnowledgePage {
        let page = KnowledgePage(
            title: title,
            pageType: pageType,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawTextSnippet: rawSnippet,
            fileSize: fileSize,
            sourceType: sourceType
        )
        try await knowledgeRepository.save(page)
        await reloadFromDisk()
        return page
    }
    
    /// 更新Page
    /// - Parameter page: page
    public func updatePage(_ page: KnowledgePage) async throws {
        try await knowledgeRepository.save(page)
        await reloadFromDisk()
    }
    
    /// 删除Page
    /// - Parameter page: page
    public func deletePage(_ page: KnowledgePage) async throws {
        try await knowledgeRepository.delete(id: page.id)
        await reloadFromDisk()
    }

    /// 同步RemotePage
    /// - Parameter page: page
    public func syncRemotePage(_ page: KnowledgePage) async {
        _ = try? await knowledgeRepository.save(page)
        await reloadFromDisk()
    }

    /// 重置Database
    public func resetDatabase() async throws {
        let writer = await dbWriter
        // 核心步骤：直接使用绑定的局部 dbWriter 进行数据清空，不再强耦合 MainActor 全局单例
        try await writer.erase()
        _pages = []
        
        // 🚨 极其重要：因为 erase() 会把全部表及 grdb_migrations 抹除，
        // 必须立刻重新运行数据库迁移器来建立空表、触发器与 FTS 索引，从而保全数据库重置后的后续读写可用性
        try await DatabaseManager.shared.migrate(writer)
        
        if let url = await DatabaseManager.shared.dbURL {
            await SecurityManager.shared.updateSignature(for: url)
        }
    }

    // MARK: - 搜索与关联

    /// 搜索Pages
    /// - Parameter query: query
    /// - Returns: 列表
    public func searchPages(query: String) async -> [KnowledgePage] {
        return (try? await knowledgeRepository.search(query: query)) ?? []
    }

    /// 拉取BacklinksByID
    /// - Returns: 列表
    public func fetchBacklinksByID(for id: UUID) async -> [KnowledgePage] {
        let backlinkIDs = (try? await knowledgeRepository.fetchBacklinks(for: id)) ?? []
        return _pages.filter { backlinkIDs.contains($0.id) }
    }
    
    // MARK: - 标签管理
    
    /// 重命名Tag
    /// - Parameter oldTag: oldTag
    public func renameTag(_ oldTag: String, to newTag: String) async {
        _ = try? await knowledgeRepository.renameTag(old: oldTag, to: newTag)
        await reloadFromDisk()
    }
    
    /// 删除Tag
    /// - Parameter tag: tag
    public func deleteTag(_ tag: String) async {
        _ = try? await knowledgeRepository.deleteTag(tag)
        await reloadFromDisk()
    }
    
    // MARK: - 统计与系统

    /// 获取存储资源统计信息，级联累加多笔记本分库及全局配置库大小
    /// - Returns: 数据库总大小、日志总大小、导出文件总大小 (字节)
    public func getStorageStats() async -> StorageStats {
        // 直接 await @MainActor 属性，避免 MainActor.run 死锁
        let dbPath = await DatabaseManager.shared.dbURL?.path ?? ""
        let globalDBPath = await DatabaseManager.shared.globalDBURL?.path ?? ""
        
        var totalDbSize: Int64 = 0
        
        // 1. 累加当前活跃的专属笔记本数据库物理文件大小及其 WAL/SHM 缓存文件
        if !dbPath.isEmpty {
            totalDbSize += (try? FileManager.default.attributesOfItem(atPath: dbPath)[.size] as? Int64) ?? 0
            
            let walPath = dbPath + "-wal"
            let shmPath = dbPath + "-shm"
            totalDbSize += (try? FileManager.default.attributesOfItem(atPath: walPath)[.size] as? Int64) ?? 0
            totalDbSize += (try? FileManager.default.attributesOfItem(atPath: shmPath)[.size] as? Int64) ?? 0
        }
        
        // 2. 累加全局主配置库大小及其 WAL/SHM 缓存文件
        if !globalDBPath.isEmpty {
            totalDbSize += (try? FileManager.default.attributesOfItem(atPath: globalDBPath)[.size] as? Int64) ?? 0
            
            let globalWalPath = globalDBPath + "-wal"
            let globalShmPath = globalDBPath + "-shm"
            totalDbSize += (try? FileManager.default.attributesOfItem(atPath: globalWalPath)[.size] as? Int64) ?? 0
            totalDbSize += (try? FileManager.default.attributesOfItem(atPath: globalShmPath)[.size] as? Int64) ?? 0
        }
        
        // 3. 级联遍历扫描沙盒目录，累加其他非激活状态笔记本专属库大小
        // swiftlint:disable:next force_unwrapping
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaultsDir = appSupport.appendingPathComponent(AppConstants.Storage.vaultsDirectoryName)
        
        if let fileURLs = try? FileManager.default.contentsOfDirectory(at: vaultsDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for fileURL in fileURLs {
                let isSqlite = fileURL.pathExtension == "sqlite3" || fileURL.pathExtension == "sqlite"
                let isCompanion = fileURL.path.hasSuffix("-wal") || fileURL.path.hasSuffix("-shm")
                
                if isSqlite || isCompanion {
                    // 排除已经累计过的当前活跃库路径
                    if !dbPath.isEmpty && !fileURL.path.hasPrefix(dbPath) {
                        let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                        if let fileSize = resourceValues?.fileSize {
                            totalDbSize += Int64(fileSize)
                        }
                    }
                }
            }
        }
        
        let totalModelSize = calculateLocalModelsStorageSize(appSupport: appSupport)
        let totalPluginSize = calculatePluginsStorageSize(appSupport: appSupport)
        let totalCachesSize = calculateCachesStorageSize()
        
        return StorageStats(
            databaseSize: totalDbSize,
            logsSize: 0,
            exportsSize: 0,
            modelsSize: totalModelSize,
            pluginsSize: totalPluginSize,
            cachesSize: totalCachesSize
        )
    }

    private func calculateLocalModelsStorageSize(appSupport: URL) -> Int64 {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let modelDirs = [
            docDir?.appendingPathComponent("Models"),
            appSupport.appendingPathComponent("Models")
        ].compactMap { $0 }
        return modelDirs.reduce(0) { $0 + folderSize(at: $1) }
    }

    private func calculatePluginsStorageSize(appSupport: URL) -> Int64 {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let pluginDirs = [
            docDir?.appendingPathComponent("Plugins"),
            appSupport.appendingPathComponent("Plugins")
        ].compactMap { $0 }
        return pluginDirs.reduce(0) { $0 + folderSize(at: $1) }
    }

    private func calculateCachesStorageSize() -> Int64 {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return 0 }
        return folderSize(at: cachesDir)
    }

    private func folderSize(at dir: URL) -> Int64 {
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
    
    /// 执行批量数据库写入操作 (在隔离环境内)
    public func performBatchWrite(_ block: @escaping @Sendable (Database) throws -> Void) async throws {
        let writer = await dbWriter
        // 核心步骤：直接使用局部的 dbWriter 执行写入，实现 100% 线程安全的隔离事务
        try await writer.write { db in try block(db) }
    }
    
    /// 填充默认引导内容 (Obsolete)
    public func seedDefaultContent(logger: @escaping @Sendable (LogAction, String, String) -> Void) async {
        // Obsolete: Content generation is now fully handled by InitialNotebookGenerator and MaintenanceService
    }

    /// 替换AllPages
    /// - Parameter newPages: newPages
    public func replaceAllPages(_ newPages: [KnowledgePage]) async {
        try? await performBatchWrite { db in
            try KnowledgePage.deleteAll(db)
            for p in newPages { try p.insert(db) }
        }
        await reloadFromDisk()
    }
}

// MARK: - 类型抹除适配 (AnyPageStore)

extension SQLiteStore {

    /// any创建Page
    public func anyCreatePage(
        title: String,
        pageType: PageType,
        customIcon: String?,
        content: String,
        tags: [String],
        sourceURL: String?,
        rawSnippet: String?,
        fileSize: Int64?,
        sourceType: String?,
        forceDeepScan: Bool
    ) async -> KnowledgePage {
        (try? await createPage(
            title: title,
            pageType: pageType,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawSnippet: rawSnippet,
            fileSize: fileSize,
            sourceType: sourceType
        )) ?? KnowledgePage(title: title, pageType: pageType)
    }

    /// any更新Page
    /// - Parameter page: page
    /// - Parameter forceDeepScan: forceDeep扫描
    public func anyUpdatePage(_ page: KnowledgePage, forceDeepScan: Bool) async {
        _ = try? await updatePage(page)
    }
    
    /// any删除Page
    /// - Parameter page: page
    public func anyDeletePage(_ page: KnowledgePage) async {
        _ = try? await deletePage(page)
    }

    /// 添加记录日志
    /// - Parameter action: action
    /// - Parameter target: target
    /// - Parameter details: details
    /// - Parameter duration: duration
    /// - Parameter startTime: 启动Time
    /// - Parameter endTime: 结束Time
    /// - Parameter module: module
    public nonisolated func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?) {
        // 存储引擎层不直接记录日志，由上层协调
    }
}
