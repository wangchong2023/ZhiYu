//
//  AppCloudSyncService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 AppCloudSync 模块的核心业务逻辑服务。
//
#if ICLOUD_ENABLED
import Foundation
import UFPCore
import CloudKit
import Combine

// MARK: - iCloud 同步中枢服务

/// 负责通过 Apple CloudKit 实现智宇知识库地云双向全量同步的底层核心服务（iCloudSyncService）。
/// 经过 Phase 2 重构，该类已精简为业务调度器，核心算法与物理驱动已拆分。
@MainActor
public final class iCloudSyncService: ObservableObject {
    /// 向 UI 发布当前的同步生命周期状态。
    @Published public var syncStatus: SyncStatus = .idle
    /// 记录最近一次双向同步成功的绝对物理时间。
    @Published public var lastSyncDate: Date?
    /// 标记当前 iCloud 账户是否完全可用。
    @Published public var iCloudAvailable: Bool = false

    private let provider: any CloudStorageProvider
    private let resolver: any SyncConflictResolver
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 业务层协同回调钩子
    
    /// 当云端数据成功拉取并解码完成后，触发的高层数据库合并回调钩子。
    public var onRemoteDataReceived: (([KnowledgePage], [LogEntry]) -> Void)?
    
    /// 当同步链路中检测到云端有更新的数据，发生同步冲突时的双向问询回调。
    public var onConflictDetected: (([KnowledgePage], [LogEntry], [KnowledgePage], [LogEntry]) async -> ConflictResolution)?

    @Inject private var appEnv: any AppEnvironmentProtocol

    public init(provider: any CloudStorageProvider = CloudKitSyncProvider(), resolver: any SyncConflictResolver = LWWSyncConflictResolver()) {
        self.provider = provider
        self.resolver = resolver
        
        // 初始可用性检查
        Task {
            self.iCloudAvailable = await provider.checkAvailability()
        }
    }

    // MARK: - iCloud 状态监控
    
    /// checkiCloudStatus
    public func checkiCloudStatus() {
        Task {
            self.iCloudAvailable = await provider.checkAvailability()
        }
    }

    // MARK: - 核心同步 API (委托模式)
    
    /// 推送ToCloud
    /// /// - Parameter pages: pages
    /// /// - Parameter logEntries: 记录日志Entries
    public func pushToCloud(pages: [KnowledgePage], logEntries: [LogEntry]) async throws {
        self.syncStatus = .syncing
        do {
            try await provider.push(pages: pages, logs: logEntries)
            self.lastSyncDate = Date()
            self.syncStatus = .synced
        } catch {
            self.syncStatus = .error(error.localizedDescription)
            throw error
        }
    }

    /// 从云端强制拉取最新数据。
    /// - Returns: 包含云端页面和日志的元组。
    public func pullFromCloud() async throws -> ([KnowledgePage], [LogEntry]) {
        self.syncStatus = .syncing
        do {
            let remote = try await provider.pull()
            self.lastSyncDate = Date()
            self.syncStatus = .synced
            return (remote.pages, remote.logs)
        } catch {
            self.syncStatus = .error(error.localizedDescription)
            throw error
        }
    }

    /// 同步
    /// /// - Parameter localPages: localPages
    /// /// - Parameter localLogs: localLogs
    /// /// - Returns: 返回值
    public func sync(localPages: [KnowledgePage], localLogs: [LogEntry]) async throws -> ([KnowledgePage], [LogEntry]) {
        self.syncStatus = .syncing
        
        do {
            let remote = try await provider.pull()
            
            // 评估时序：如果云端有更新，执行合并；否则保持本地最新。
            let remoteDate = remote.lastModified
            let hasRemoteNewer = lastSyncDate.map { remoteDate > $0 } ?? true
            
            let finalPages: [KnowledgePage]
            let finalLogs: [LogEntry]
            
            if hasRemoteNewer {
                // 触发冲突策略询问 (支持 Legacy 注入的回调)
                let resolution: ConflictResolution
                if let onConflict = onConflictDetected {
                    resolution = await onConflict(localPages, localLogs, remote.pages, remote.logs)
                } else {
                    resolution = .merge
                }

                switch resolution {
                case .keepLocal:
                    finalPages = localPages
                    finalLogs = localLogs
                case .keepRemote:
                    finalPages = remote.pages
                    finalLogs = remote.logs
                case .merge:
                    finalPages = resolver.mergePages(local: localPages, remote: remote.pages)
                    finalLogs = resolver.mergeLogs(local: localLogs, remote: remote.logs)
                }
            } else {
                finalPages = localPages
                finalLogs = localLogs
            }
            
            // 推送黄金数据集
            try await provider.push(pages: finalPages, logs: finalLogs)
            
            self.lastSyncDate = Date()
            self.syncStatus = .synced
            
            return (finalPages, finalLogs)
        } catch {
            self.syncStatus = .error(error.localizedDescription)
            throw error
        }
    }

    /// 订阅ToRemoteChanges
    public func subscribeToRemoteChanges() async throws {
        try await provider.subscribeToChanges()
    }

    /// 在后台主动抓取并拉取云端的更新。
    /// - Returns: 云端最新的数据集元组。
    public func fetchRemoteChanges() async throws -> ([KnowledgePage], [LogEntry]) {
        return try await pullFromCloud()
    }
}
#endif // ICLOUD_ENABLED
