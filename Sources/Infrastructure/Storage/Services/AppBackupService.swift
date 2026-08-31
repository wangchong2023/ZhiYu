//
//  AppBackupService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 AppBackup 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies

// MARK: - Backup Service
/// Automatic data backup and crash recovery service.
/// Creates timestamped backups on each save, auto-cleans old backups, and recovers from crash.
@MainActor
final class BackupService: ObservableObject {
    @Published var backupEntries: [BackupEntry] = []
    @Published var lastBackupDate: Date?
    @Published var isAutoBackupEnabled: Bool = true

    /// Maximum number of backups to retain before auto-cleanup removes the oldest.
    private static let maxBackups = 20
    /// Minimum time interval (seconds) between consecutive auto-backups to avoid thrashing.
    private static let backupInterval: TimeInterval = 300

    let baseDirectory: URL

    struct BackupEntry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let pageCount: Int
        let totalWords: Int
        let fileName: String

        var displayName: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }

        /// fileSize
        /// - Returns: 字符串
        func fileSize(in directory: URL) -> String {
            let url = directory.appendingPathComponent(fileName)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64 {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            return "-"
        }
    }

    // MARK: - Directory Helper
    /// default备份Directory
    /// - Returns: 链接
    static func defaultBackupDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("AppBackups", isDirectory: true)
    }

    var backupDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("AppBackups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Init
    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        loadBackupEntries()
        checkForCrashRecovery()
    }

    // MARK: - Create Backup
    /// 创建自动备份（受 `isAutoBackupEnabled` 开关与节流策略控制）。
    /// - Parameter pages: pages
    func createBackup(pages: [KnowledgePage]) {
        guard isAutoBackupEnabled else { return }

        // Throttle: don't backup too frequently, with protection against clock rollback
        if let last = lastBackupDate {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed >= 0 && elapsed < Self.backupInterval {
                return
            }
        }

        writeBackup(pages: pages)
    }

    /// 创建强制备份（绕过 `isAutoBackupEnabled` 开关与节流策略）。
    ///
    /// 用于"立即创建备份"按钮、恢复前的安全备份等不可错过的场景，
    /// 避免因开关关闭或节流窗口未到而静默丢失数据（Bug #56/#57）。
    /// - Parameter pages: pages
    func createForcedBackup(pages: [KnowledgePage]) {
        writeBackup(pages: pages)
    }

    /// 实际写入备份文件并更新索引的内部实现，由 `createBackup`/`createForcedBackup` 共用。
    private func writeBackup(pages: [KnowledgePage]) {
        let startTime = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let timestamp = Date()
        let formatter = DateFormatter()
        // Bug #42 修复：文件名包含毫秒，避免同秒备份文件名冲突
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let fileName = "backup_\(formatter.string(from: timestamp)).json"

        do {
            let data = try encoder.encode(pages)
            let url = backupDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomicWrite)

            let entry = BackupEntry(
                id: UUID(),
                timestamp: timestamp,
                pageCount: pages.count,
                totalWords: pages.reduce(0) { $0 + $1.wordCount },
                fileName: fileName
            )
            backupEntries.append(entry)
            lastBackupDate = timestamp

            // Save entries index
            saveBackupEntries()

            // Clean old backups
            cleanOldBackups()

            let endTime = Date()
            Logger.shared.addLog(
                action: .ingest,
                target: fileName,
                details: StorageConstants.LogDetails.appBackupSuccess1,
                duration: endTime.timeIntervalSince(startTime),
                startTime: startTime,
                endTime: endTime,
                module: StorageConstants.LogModule.backupService
            )
        } catch {
            let endTime = Date()
            Logger.shared.addLog(
                action: .error,
                target: fileName,
                details: String(format: L10n.Backup.log.createFailed, error.localizedDescription),
                duration: endTime.timeIntervalSince(startTime),
                startTime: startTime,
                endTime: endTime,
                module: StorageConstants.LogModule.backupService
            )
        }
    }

    // MARK: - Restore Backup
    /// 恢复备份
    /// - Parameter entry: entry
    /// - Returns: 列表
    func restoreBackup(_ entry: BackupEntry) -> [KnowledgePage]? {
        let startTime = Date()
        let url = backupDirectory.appendingPathComponent(entry.fileName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: url)
            let pages = try decoder.decode([KnowledgePage].self, from: data)
            let endTime = Date()
            Logger.shared.addLog(
                action: .ingest,
                target: entry.fileName,
                details: StorageConstants.LogDetails.appBackupSuccess2,
                duration: endTime.timeIntervalSince(startTime),
                startTime: startTime,
                endTime: endTime,
                module: StorageConstants.LogModule.backupService
            )
            return pages
        } catch {
            let endTime = Date()
            Logger.shared.addLog(
                action: .error,
                target: entry.fileName,
                details: String(format: L10n.Backup.log.restoreFailed, error.localizedDescription),
                duration: endTime.timeIntervalSince(startTime),
                startTime: startTime,
                endTime: endTime,
                module: StorageConstants.LogModule.backupService
            )
            return nil
        }
    }

    // MARK: - Delete Backup
    /// 删除备份
    /// - Parameter entry: entry
    func deleteBackup(_ entry: BackupEntry) {
        let url = backupDirectory.appendingPathComponent(entry.fileName)
        try? FileManager.default.removeItem(at: url)
        backupEntries.removeAll { $0.id == entry.id }
        saveBackupEntries()
    }

    // MARK: - Crash Recovery
    private func checkForCrashRecovery() {
        // Check if there's a "dirty flag" file indicating unsaved changes at crash
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")

        if FileManager.default.fileExists(atPath: dirtyFlag.path) {
            Logger.shared.addLog(action: .systemInit, target: StorageConstants.LogTarget.backupService, details: L10n.Backup.log.crashRecovery)
            // The dirty flag means the app crashed before completing a save
            // BackupService will make the latest backup available for recovery
            try? FileManager.default.removeItem(at: dirtyFlag)
        }
    }

    /// markDirty
    func markDirty() {
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")
        try? Data().write(to: dirtyFlag)
    }

    /// mark清理
    func markClean() {
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")
        try? FileManager.default.removeItem(at: dirtyFlag)
    }

    var hasUnsavedChanges: Bool {
        let dirtyFlag = baseDirectory.appendingPathComponent(".knowledge-management_dirty")
        return FileManager.default.fileExists(atPath: dirtyFlag.path)
    }

    // MARK: - Clean Old Backups
    private func cleanOldBackups() {
        guard backupEntries.count > Self.maxBackups else { return }

        let sorted = backupEntries.sorted { $0.timestamp > $1.timestamp }
        let toRemove = Array(sorted.suffix(from: Self.maxBackups))

        // Bug #137 修复：删除文件成功才从 entries 移除，避免索引与磁盘不一致
        // 文件不存在的条目（如被覆盖）直接移除，避免索引孤儿
        var kept = Array(sorted.prefix(Self.maxBackups))
        for entry in toRemove {
            let url = backupDirectory.appendingPathComponent(entry.fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    // 删除失败则保留该条目，避免索引孤儿
                    kept.append(entry)
                }
            }
            // 文件不存在则直接丢弃条目（已被覆盖或手动删除）
        }
        backupEntries = kept.sorted { $0.timestamp > $1.timestamp }
        saveBackupEntries()
    }

    // MARK: - Persistence
    private func saveBackupEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(backupEntries)
            let url = backupDirectory.appendingPathComponent("backup_index.json")
            try data.write(to: url, options: .atomicWrite)
        } catch {
            Logger.shared.addLog(action: .error, target: StorageConstants.LogTarget.backupService, details: String(format: L10n.Backup.log.saveIndexFailed, error.localizedDescription))
        }
    }

    private func loadBackupEntries() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let url = backupDirectory.appendingPathComponent("backup_index.json")
        do {
            let data = try Data(contentsOf: url)
            backupEntries = try decoder.decode([BackupEntry].self, from: data)
            // Bug #138 修复：取最大时间戳而非 .last，避免降序数组下取到最旧时间
            lastBackupDate = backupEntries.map(\.timestamp).max()
        } catch {
            // No index file yet, scan directory
            scanBackupDirectory()
        }
    }

    private func scanBackupDirectory() {
        let dir = backupDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [URLResourceKey.creationDateKey]) else { return }

        var entries: [BackupEntry] = []
        for file in files where file.lastPathComponent.hasPrefix(StorageConstants.Backup.prefix) && file.pathExtension == SystemConstants.FileExtension.json {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: file),
               let pages = try? decoder.decode([KnowledgePage].self, from: data) {
                let entry = BackupEntry(
                    id: UUID(),
                    timestamp: (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date(),
                    pageCount: pages.count,
                    totalWords: pages.reduce(0) { $0 + $1.wordCount },
                    fileName: file.lastPathComponent
                )
                entries.append(entry)
            }
        }
        backupEntries = entries.sorted { $0.timestamp > $1.timestamp }
        lastBackupDate = backupEntries.first?.timestamp
    }
}

// MARK: - DependencyKey 注册

/// BackupService 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum BackupServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: BackupService {
        ServiceContainer.shared.resolve(BackupService.self)
    }

    @MainActor
    public static var testValue: BackupService {
        ServiceContainer.shared.resolveOptional(BackupService.self) ?? BackupService()
    }
}

extension DependencyValues {
    /// 备份服务依赖
    var backupService: BackupService {
        get { self[BackupServiceKey.self] }
        set { self[BackupServiceKey.self] = newValue }
    }
}
