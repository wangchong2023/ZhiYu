//
//  SyncProtocols.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义云同步相关的抽象契约接口。
//

import Foundation

/// 云同步状态枚举
public enum CloudSyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case synced
    case error(String)
}

/// 冲突解决策略
public enum SyncConflictResolution: String, CaseIterable, Sendable {
    case keepLocal
    case keepRemote
    case merge
}

/// 云存储驱动协议 (L1 实现)
public protocol CloudStorageProvider: Sendable {
    /// 检查云存储是否可用
    func checkAvailability() async -> Bool
    
    /// 推送数据到云端
    func push(pages: [KnowledgePage], logs: [LogEntry]) async throws
    
    /// 从云端拉取数据
    func pull() async throws -> CloudSnapshot
    
    /// 订阅云端变更通知
    func subscribeToChanges() async throws
}

/// 同步冲突解决协议 (L1 或 L1.5 实现)
public protocol SyncConflictResolver: Sendable {
    /// 解决页面列表冲突
    func mergePages(local: [KnowledgePage], remote: [KnowledgePage]) -> [KnowledgePage]
    
    /// 解决审计日志冲突
    func mergeLogs(local: [LogEntry], remote: [LogEntry]) -> [LogEntry]
}

/// 云同步调度引擎协议 (L1.5 核心大脑)
@MainActor
public protocol CloudSyncOrchestrator: ObservableObject {
    var syncStatus: CloudSyncStatus { get }
    var lastSyncDate: Date? { get }
    
    /// 执行全量双向同步
    func performSync(localPages: [KnowledgePage], localLogs: [LogEntry]) async throws -> (pages: [KnowledgePage], logs: [LogEntry])
}

/// 云存储快照，包含页面、日志和最后修改时间
public struct CloudSnapshot: Sendable {
    public let pages: [KnowledgePage]
    public let logs: [LogEntry]
    public let lastModified: Date

    public init(pages: [KnowledgePage], logs: [LogEntry], lastModified: Date) {
        self.pages = pages
        self.logs = logs
        self.lastModified = lastModified
    }
}
