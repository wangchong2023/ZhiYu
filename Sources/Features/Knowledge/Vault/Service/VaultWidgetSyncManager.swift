//
//  VaultWidgetSyncManager.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Vault 的 Widget/Watch 同步 — 页面计数刷新、App Group JSON 快照写入与主库兜底统计。
//
import Foundation

// MARK: - Widget / Watch 同步管理

extension VaultService {

    /// 从当前活跃数据库查询实际页面数并写回全局元数据 + App Group JSON 快照
    public func refreshPageCount(for vaultID: UUID) async {
        guard let databaseSwitcher = databaseSwitcher,
              let vaultRepository = vaultRepository else {
            Logger.shared.warning(" [VaultService] refreshPageCount 被跳过，因为数据库相关依赖未在 DI 注册")
            return
        }
        do {
            let count = try await databaseSwitcher.countPagesInCurrentVault()
            Logger.shared.info("[VaultService] refreshPageCount: vault=\(vaultID.uuidString.prefix(8)) count=\(count)")
            if let index = vaults.firstIndex(where: { $0.id == vaultID }) {
                vaults[index].pageCount = count
                try await vaultRepository.saveVault(vaults[index])
            }
            await writeWidgetStatsSnapshot(pageCount: count, linkCount: 0, tagCount: 0)
        } catch {
            Logger.shared.warning("[VaultService] refreshPageCount failed: \(error.localizedDescription)")
        }
    }

    /// 将当前 vault 的统计与每日洞察快照写入 App Group JSON（供 Widget Extension & Watch 读取）
    func writeWidgetStatsSnapshot(
        pageCount: Int,
        linkCount: Int = 0,
        tagCount: Int = 0,
        dailyInsightTitle: String = L10n.Widget.llmWikiChunking,
        dailyInsightContent: String = L10n.Widget.llmWikiDescription,
        flashThoughtSummary: String = L10n.Widget.flashThoughtSub,
        distribution: [String: Double] = ["source": 0.4, "concept": 0.3, "entity": 0.2, "map": 0.1]
    ) async {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.zhiyu.app"
        ) else { return }

        let snapshot: [String: Any] = [
            "pageCount": pageCount,
            "linkCount": linkCount,
            "tagCount": tagCount,
            "dailyInsightTitle": dailyInsightTitle,
            "dailyInsightContent": dailyInsightContent,
            "flashThoughtSummary": flashThoughtSummary,
            "distribution": distribution,
            "recentPages": []
        ]
        let url = groupURL.appendingPathComponent("widget_stats.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: snapshot)
            try data.write(to: url, options: .atomic)
            Logger.shared.info("[VaultService] Widget & Watch snapshot written: pageCount=\(pageCount) to \(url.lastPathComponent)")
        } catch {
            Logger.shared.warning("[VaultService] Widget snapshot write failed: \(error.localizedDescription)")
        }
    }

    /// 启动后刷新全部笔记本的页面计数（直接读取各 vault 数据库 file）
    func refreshAllPageCounts() async {
        guard let databaseSwitcher = databaseSwitcher,
              let vaultRepository = vaultRepository else {
            Logger.shared.warning(" [VaultService] refreshAllPageCounts 被跳过，因为数据库依赖未在 DI 注册")
            return
        }
        var anyVaultHasDB = false
        for vault in vaults {
            let dbURL = getVaultDatabaseURL(for: vault.id)
            guard FileManager.default.fileExists(atPath: dbURL.path) else { continue }
            anyVaultHasDB = true
            do {
                let count = try await databaseSwitcher.countPages(at: dbURL)
                if let index = vaults.firstIndex(where: { $0.id == vault.id }) {
                    vaults[index].pageCount = count
                    try? await vaultRepository.saveVault(vaults[index])
                }
            } catch {
                Logger.shared.warning("[VaultService] refreshPageCount failed for \(vault.name): \(error.localizedDescription)")
            }
        }
        if !anyVaultHasDB, let activeID = selectedVaultID {
            await refreshPageCountFromMainDB(for: activeID)
        }
    }

    /// 从主数据库（App.sqlite）读取页面计数，仅赋值给指定 vault。
    func refreshPageCountFromMainDB(for vaultID: UUID) async {
        guard let writer = DatabaseManager.shared.dbWriter else { return }
        guard let vaultRepository = vaultRepository else {
            Logger.shared.warning(" [VaultService] refreshPageCountFromMainDB 被跳过，因为 vaultRepository 未在 DI 注册")
            return
        }
        do {
            let count = try await writer.read { db in
                try KnowledgePage.fetchCount(db)
            }
            if let index = vaults.firstIndex(where: { $0.id == vaultID }) {
                vaults[index].pageCount = count
                try? await vaultRepository.saveVault(vaults[index])
            }
            Logger.shared.info("[VaultService] Fallback: set pageCount=\(count) from main DB for active vault")
        } catch {
            Logger.shared.error("[VaultService] refreshPageCountFromMainDB failed", error: error)
        }
    }
}
