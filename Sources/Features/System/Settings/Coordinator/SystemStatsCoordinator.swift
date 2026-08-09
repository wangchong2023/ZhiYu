//
//  SystemStatsCoordinator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：负责 SystemStats 业务流的导航路由与协作管理。
//
import SwiftUI
import UFPCore
import Observation

@MainActor
@Observable
final class SystemStatsCoordinator {
    // ── 状态属性 ──
    var dailyStats: [DailyAIUsage] = []
    var monthlyStats: [MonthlyToken] = []
    var totalStorage: Int64 = 0
    struct ProvenanceStats { var importedCount: Int; var importedSize: Int64; var createdCount: Int; var createdSize: Int64 }
    var provenance = ProvenanceStats(importedCount: 0, importedSize: 0, createdCount: 0, createdSize: 0)
    var exportCount: Int = 0
    var exportSize: Int64 = 0
    
    struct AssetStats: Sendable {
        var count: Int
        var size: Int64
    }
    var assetCategoryStats: [String: AssetStats] = [:]
    var avgLatency: Int = 0
    var maxLatency: Int = 0
    var minLatency: Int = 0
    var latencyCount: Int = 0
    var storageCategories: [StorageCategory] = []
    var totalPages: Int = 0
    /// 原始文件（.raw）的存储情况
    var rawStorageStats: RawStats?
    
    /// 原始文件统计结构
    struct RawStats: Sendable {
        var count: Int
        var size: Int64
    }
    var isLoading = true
    var isCleaning = false
    var cleanedCount: Int?
    
    // ── 内部类型定义与多笔记本存储状态 ──
    struct VaultStorageItem: Identifiable, Sendable {
        let id: UUID
        let name: String
        let icon: String
        let size: Int64
    }
    
    /// 各多笔记本 (Vault) 的精细化存储大小发布列表
    var vaultStorageItems: [VaultStorageItem] = []

    // ── 基础设施依赖 ──
    @ObservationIgnored @Inject private var pageStore: any AnyPageStoreCapabilities
    @ObservationIgnored @Inject private var knowledgeRepo: any KnowledgeRepository
    @ObservationIgnored @Inject private var vectorRepo: any VectorRepository
    @ObservationIgnored @Inject private var governanceRepo: any RAGGovernanceRepository
    @ObservationIgnored @Inject private var importRecordRepo: any ImportRecordRepository
    @ObservationIgnored @Inject private var logger: any LoggerProtocol
    @ObservationIgnored @Inject private var haptic: any HapticFeedbackProtocol

    init() {}

    // ── 业务动作 ──

    /// 加载系统统计数据
    func loadStats() async {
        let startTime = Date()
        await fetchAIDailyStats()
        await fetchMonthlyStats()
        await fetchStorageStats()
        await fetchVaultStorageSizes()
        await fetchRawPageStats()
        self.totalPages = (try? await knowledgeRepo.count()) ?? 0

        let endTime = Date()
        logger.addLog(
            action: .update,
            target: L10n.Dashboard.stats.navigationTitleMonitor,
            details: L10n.Dashboard.updateSuccess,
            duration: endTime.timeIntervalSince(startTime),
            startTime: startTime,
            endTime: endTime,
            module: "Dashboard"
        )
        self.isLoading = false
    }

    /// 从知识库仓库中提取所有 .raw (原始) 页面的存储统计数据（字数与字节大小）
    /// 并将其保存到 rawStorageStats 结构中，用于开发调试查看基于卡帕西 Wiki 的原始数据存储。
    private func fetchRawPageStats() async {
        guard let allPages = try? await knowledgeRepo.fetchAll() else { return }
        // 过滤出所有原始未解析类型的页面
        let rawPages = allPages.filter { $0.pageType == .raw }
        
        // 计算其总内容字节大小 (基于 UTF8 字节统计)
        let totalSize = rawPages.reduce(Int64(0)) { $0 + Int64($1.content.utf8.count) }
        
        self.rawStorageStats = RawStats(count: rawPages.count, size: totalSize)
    }

    private func fetchAIDailyStats() async {
        guard let daily = try? await governanceRepo.fetchDailyAIStats(days: AppConstants.Keys.Stats.dailyStatsDays) else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = AppConstants.Keys.Stats.dailyDateFormat
        dateFormatter.locale = Locale(identifier: Localized.currentLanguage)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.year, .month], from: today)
        let startDate = calendar.date(from: components) ?? today
        let numberOfDays = (calendar.dateComponents([.day], from: startDate, to: today).day ?? 0) + 1

        var statsMap: [String: DailyAIUsage] = [:]
        for i in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let ds = dateFormatter.string(from: date)
                statsMap[ds] = DailyAIUsage(date: date, dateString: ds, tokens: 0, requests: 0)
            }
        }
        for item in daily {
            if let date = dateFormatter.date(from: item.date), statsMap[item.date] != nil {
                statsMap[item.date] = DailyAIUsage(date: date, dateString: item.date, tokens: item.tokens, requests: item.requests)
            }
        }
        self.dailyStats = statsMap.values.sorted { $0.date < $1.date }
    }

    private func fetchMonthlyStats() async {
        if let monthly = try? await governanceRepo.fetchMonthlyTokenStats() {
            self.monthlyStats = monthly.map { MonthlyToken(month: $0.month, total: $0.total) }
        }
    }

    private func fetchStorageStats() async {
        let stats = await pageStore.getStorageStats()
        let allLogEntries = await logger.getLogEntries()
        
        let records = (try? await importRecordRepo.fetchAll(category: nil, limit: 2000)) ?? []
        var voiceStats = AssetStats(count: 0, size: 0)
        var ocrStats = AssetStats(count: 0, size: 0)
        var fileStats = AssetStats(count: 0, size: 0)
        
        for record in records {
            let size = record.fileSize ?? 0
            if record.category == ImportCategory.voice.rawValue {
                voiceStats.count += 1
                voiceStats.size += size
            } else if record.category == ImportCategory.ocr.rawValue {
                ocrStats.count += 1
                ocrStats.size += size
            } else if record.category == ImportCategory.file.rawValue {
                fileStats.count += 1
                fileStats.size += size
            }
        }

        self.assetCategoryStats = [
            ImportCategory.voice.rawValue: voiceStats,
            ImportCategory.ocr.rawValue: ocrStats,
            ImportCategory.file.rawValue: fileStats
        ]
        
        let modelManagerSize = GlobalModelManager.shared.modelStorageUsage.values.reduce(Int64(0), +)
        let effectiveModelsSize = max(stats.modelsSize, modelManagerSize)
        let modelCount = GlobalModelManager.shared.modelStorageUsage.count
        
        let categories = [
            StorageCategory(label: L10n.Dashboard.System.database, value: stats.databaseSize, count: VaultService.shared.vaults.count, color: .blue),
            StorageCategory(label: L10n.Dashboard.System.models, value: effectiveModelsSize, count: modelCount, color: .purple),
            StorageCategory(label: L10n.Dashboard.System.plugins, value: stats.pluginsSize, count: 0, color: .indigo),
            StorageCategory(label: L10n.Dashboard.System.logs, value: stats.logsSize, count: allLogEntries.count, color: .orange),
            StorageCategory(label: L10n.Dashboard.stats.storageImport, value: (try? await importRecordRepo.totalStorageSize()) ?? 0, count: records.count, color: .green),
            StorageCategory(label: L10n.Dashboard.stats.storageExport, value: stats.exportsSize, count: allLogEntries.filter { $0.action == .export }.count, color: .pink),
            StorageCategory(label: L10n.Dashboard.System.caches, value: stats.cachesSize, count: 0, color: .gray)
        ]
        self.storageCategories = categories
        self.totalStorage = categories.reduce(0) { $0 + $1.value }
        self.exportSize = stats.exportsSize
        self.exportCount = allLogEntries.filter { $0.action == .export }.count
    }

    private func fetchVaultStorageSizes() async {
        var items: [VaultStorageItem] = []
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let vaultsDir = appSupport.appendingPathComponent(AppConstants.Storage.vaultsDirectoryName)
            for vault in VaultService.shared.vaults {
                let vaultDir = vaultsDir.appendingPathComponent(vault.id.uuidString)
                var totalVaultSize: Int64 = 0
                if let enumerator = fileManager.enumerator(at: vaultDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                    while let fileURL = enumerator.nextObject() as? URL {
                        if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                           let fileSize = resourceValues.fileSize {
                            totalVaultSize += Int64(fileSize)
                        }
                    }
                }
                items.append(VaultStorageItem(id: vault.id, name: vault.name, icon: vault.icon ?? "", size: totalVaultSize))
            }
        }
        self.vaultStorageItems = items.sorted { $0.size > $1.size }
    }

    /// 执行数据库深度清理
    func cleanupData() async {
        isCleaning = true
        do {
            let count = try await vectorRepo.cleanupOrphanedChunks()
            self.cleanedCount = count
            haptic.trigger(.success)
            await loadStats() // 刷新统计
        } catch {
            logger.error("[SystemStats] Data_cleanup_failed", error: error)
        }
        isCleaning = false
    }

    /// 字节格式化助手
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// 标签图标选择器
    func iconForCategory(_ label: String) -> String {
        if label == L10n.Dashboard.System.database { return DesignSystem.Icons.StorageStats.database }
        if label == L10n.Dashboard.System.logs { return DesignSystem.Icons.StorageStats.logs }
        if label == L10n.Dashboard.stats.storageImport { return DesignSystem.Icons.StorageStats.storageImport }
        if label == L10n.Dashboard.stats.storageExport { return DesignSystem.Icons.StorageStats.storageExport }
        return DesignSystem.Icons.StorageStats.fallback
    }
}
