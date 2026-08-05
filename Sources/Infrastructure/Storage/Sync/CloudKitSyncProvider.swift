//
//  CloudKitSyncProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现基于 Apple CloudKit 的底层物理云存储驱动。
//

#if ICLOUD_ENABLED
import Foundation
import CloudKit

/// 智宇专用的 CloudKit 物理驱动实现 (@SR-02)
public final class CloudKitSyncProvider: CloudStorageProvider {
    
    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID = CKRecordZone.ID(zoneName: StorageConstants.CloudKit.appZone)
    private let recordType = "AppData"
    private let recordName = "knowledge-management_main"
    
    public init() {
        self.container = CKContainer.default()
        self.database = container.privateCloudDatabase
    }
    
    /// 检查Availability
    /// /// - Returns: 是否成功
    public func checkAvailability() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
    
    /// 推送
    /// /// - Parameter pages: pages
    /// /// - Parameter logs: logs
    public func push(pages: [KnowledgePage], logs: [LogEntry]) async throws {
        try await ensureZoneExists()
        
        // 序列化
        let pagesData = try JSONEncoder().encode(pages)
        let logsData = try JSONEncoder().encode(logs)
        
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let record: CKRecord
        
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }
        
        record["pagesData"] = pagesData as CKRecordValue
        record["logEntriesData"] = logsData as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
        
        _ = try await database.save(record)
    }
    
    /// 拉取
    /// /// - Returns: 返回值
    public func pull() async throws -> CloudSnapshot {
        try await ensureZoneExists()
        
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let record = try await database.record(for: recordID)
        
        guard let pagesData = record["pagesData"] as? Data,
              let logsData = record["logEntriesData"] as? Data else {
            throw NSError(domain: StorageConstants.ErrorDomain.cloudKitSyncProvider, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid data format in CloudKit"])
        }
        
        let pages = try JSONDecoder().decode([KnowledgePage].self, from: pagesData)
        let logs = try JSONDecoder().decode([LogEntry].self, from: logsData)
        let lastModified = record["lastModified"] as? Date ?? Date.distantPast
        
        return CloudSnapshot(pages: pages, logs: logs, lastModified: lastModified)
    }
    
    /// 配置静默推送，注册 CloudKit 的数据库变更订阅，以便系统后台唤醒更新。
    public func subscribeToChanges() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: "knowledge-management_all_changes")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        _ = try await database.save(subscription)
    }
    
    // MARK: - Private
    
    private func ensureZoneExists() async throws {
        do {
            _ = try await database.recordZone(for: zoneID)
        } catch let error as CKError where error.code == .zoneNotFound {
            let zone = CKRecordZone(zoneID: zoneID)
            _ = try await database.save(zone)
        }
    }
}

extension CloudKitSyncProvider: @unchecked Sendable {}
#endif
