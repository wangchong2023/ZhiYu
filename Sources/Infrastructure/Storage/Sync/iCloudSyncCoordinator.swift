//
//  iCloudSyncCoordinator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：负责 iCloudSync 业务流的导航路由与协作管理。
//
#if ICLOUD_ENABLED
import Foundation
import Observation
import UFPCore

// MARK: - iCloud Sync Coordinator
/// 负责 iCloud 同步的业务编排，将 View 层的同步逻辑提取到服务层。
@MainActor
@Observable
final class iCloudSyncCoordinator {
    let syncService: iCloudSyncService
    var store: AppStore?
    var settingsStore: SettingsStore?

    // MARK: - UI State
    var isSyncing = false
    var showError = false
    var errorMessage = ""
    var showConflictAlert = false
    var showPullConfirmation = false
    var showClearCloudConfirmation = false
    var showAutoSyncError = false
    var autoSyncErrorMessage = ""
    var conflictResolution: ConflictResolution = .merge
    var autoSync = false
    
    /// 触发手动冲突合并 Sheet 的状态属性
    var activeConflict: ConflictInfo?

    private var autoSyncTimer: Timer?
    private static let autoSyncInterval: TimeInterval = 300

    var iCloudAvailable: Bool { syncService.iCloudAvailable }
    var syncStatus: SyncStatus { syncService.syncStatus }

    init(syncService: iCloudSyncService = iCloudSyncService()) {
        self.syncService = syncService
    }

    // MARK: - Lifecycle

    /// 视图出现回调
    func onAppear() {
        if let raw = settingsStore?.iCloudConflictResolution,
           let resolved = ConflictResolution(rawValue: raw) {
            conflictResolution = resolved
        }
        autoSync = settingsStore?.iCloudAutoSync ?? false
        startAutoSyncIfNeeded()
    }

    /// 视图消失回调
    func onDisappear() {
        cancelAutoSync()
    }

    // MARK: - Auto Sync

    /// 启动Auto同步IfNeeded
    func startAutoSyncIfNeeded() {
        autoSyncTimer?.invalidate()
        guard autoSync, syncService.iCloudAvailable else { return }

        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: Self.autoSyncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !isSyncing else { return }
                await performAutoSync()
            }
        }

        Task { @MainActor [weak self] in
            guard let self, !isSyncing else { return }
            await performAutoSync()
        }
    }

    /// 取消Auto同步
    func cancelAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    /// 执行静默自动同步：将本地页面和日志推送到云端并合并拉取远端数据。
    /// 发生冲突时使用预设策略（merge），成功后替换本地数据。
    private func performAutoSync() async {
        guard let store else { return }
        isSyncing = true
        syncService.onConflictDetected = { [weak self] _, _, _, _ in
            self?.conflictResolution ?? .merge
        }

        do {
            let (finalPages, _) = try await syncService.sync(
                localPages: store.pages,
                localLogs: store.logEntries
            )
            if !finalPages.isEmpty {
                replaceLocalData(with: finalPages)
            }
        } catch {
            autoSyncErrorMessage = error.localizedDescription
            showAutoSyncError = true
        }
        isSyncing = false
    }

    // MARK: - Sync Actions

    /// 推送ToCloud
    func pushToCloud() {
        guard let store else { return }
        isSyncing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await syncService.pushToCloud(pages: store.pages, logEntries: store.logEntries)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    /// 拉取FromCloud
    func pullFromCloud() {
        guard store != nil else { return }
        isSyncing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let (pages, _) = try await syncService.pullFromCloud()
                if !pages.isEmpty {
                    replaceLocalData(with: pages)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    /// bidirectional同步
    func bidirectionalSync() {
        guard let store else { return }
        isSyncing = true
        
        // 挂载异步冲突判定回调，用于唤醒手动合并 Sheet
        syncService.onConflictDetected = { [weak self] localPages, localLogs, remotePages, remoteLogs in
            guard let self else { return .merge }
            // 利用 withCheckedContinuation 将当前 iCloud 同步工作线程挂起，等待 UI 主线程决议
            return await withCheckedContinuation { continuation in
                self.activeConflict = ConflictInfo(
                    localPages: localPages,
                    localLogs: localLogs,
                    remotePages: remotePages,
                    remoteLogs: remoteLogs,
                    continuation: continuation
                )
            }
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let (finalPages, _) = try await syncService.sync(
                    localPages: store.pages,
                    localLogs: store.logEntries
                )
                replaceLocalData(with: finalPages)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    /// 清除CloudData
    func clearCloudData() {
        isSyncing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await syncService.pushToCloud(pages: [], logEntries: [])
                syncService.syncStatus = .idle
                syncService.lastSyncDate = nil
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSyncing = false
        }
    }

    // MARK: - Data Management

    /// 以拉取到的云端页面全量替换本地数据：清空 → 逐条导入 → 落盘。
    func replaceLocalData(with pages: [KnowledgePage]) {
        guard let store else { return }
        try? store.clearAllData()
        for page in pages {
            await store.addImportedPage(page)
        }
        store.saveToDisk()
    }

    /// 对以 .json 结尾的非数据库偏好配置文件进行自动冲突解决。
    /// 解析两端的修改时间戳（updatedAt），自动采用 LWW (Last-Write-Wins) 进行覆盖，免去手动 Diff 的打扰。
    /// - Parameters:
    ///   - local: 本地配置文件 URL
    ///   - remote: 云端冲突副本 URL
    /// - Returns: true 表示已成功执行 LWW 冲突解决
    @discardableResult

    /// 基于时间戳的 LWW（Last-Write-Wins）冲突解决策略。
    /// 解析本地与云端 JSON 中的 updatedAt 字段，较新者覆盖较旧者。
    func resolveConflictedMetadata(local: URL, remote: URL) -> Bool {
        // 仅处理 JSON 配置文件
        guard local.pathExtension == SystemConstants.FileExtension.json && remote.pathExtension == SystemConstants.FileExtension.json else {
            return false
        }
        
        do {
            let localData = try Data(contentsOf: local)
            let remoteData = try Data(contentsOf: remote)
            
            // Step 1: 配置 JSON 日期解码器，兼容 ISO8601 与多格式回退
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateStr = try container.decode(String.self)
                // 尝试多种常见的日期格式
                let formatters = [
                    ISO8601DateFormatter(),
                    {
                        let formatter = DateFormatter()
                        formatter.dateFormat = ""
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        return f
                    }()
                ]
                for formatter in formatters {
                    if let date = formatter.date(from: dateStr) {
                        return date
                    }
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
            }
            
            struct ConfigMetadata: Codable {
                var updatedAt: Date?
            }
            
            let localMeta = try? decoder.decode(ConfigMetadata.self, from: localData)
            let remoteMeta = try? decoder.decode(ConfigMetadata.self, from: remoteData)
            
            let localDate = localMeta?.updatedAt ?? (try? local.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let remoteDate = remoteMeta?.updatedAt ?? (try? remote.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            
            // Step 2: LWW 裁决 — 时间戳较新者覆盖较旧者
            if remoteDate > localDate {
                // Remote 更新，云端覆盖本地
                if FileManager.default.fileExists(atPath: local.path) {
                    try FileManager.default.removeItem(at: local)
                }
                try FileManager.default.copyItem(at: remote, to: local)
                Logger.shared.info("ICloudSync_LWW_Remote")
            } else {
                // Local 更新，本地覆盖云端
                if FileManager.default.fileExists(atPath: remote.path) {
                    try FileManager.default.removeItem(at: remote)
                }
                try FileManager.default.copyItem(at: local, to: remote)
                Logger.shared.info("ICloudSync_LWW_Local")
            }
            return true
        } catch {
            Logger.shared.error("ICloudSync_LWW_Failed", error: error)
            return false
        }
    }
}

// MARK: - iCloud 同步冲突详细信息
/// 封装物理同步冲突时两端数据，包含用于恢复同步流的 checked continuation 句柄
struct ConflictInfo: Identifiable {
    let id = UUID()
    let localPages: [KnowledgePage]
    let localLogs: [LogEntry]
    let remotePages: [KnowledgePage]
    let remoteLogs: [LogEntry]
    let continuation: CheckedContinuation<ConflictResolution, Never>
}
#endif // ICLOUD_ENABLED
