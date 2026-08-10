//
//  VaultDataCoordinator.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Vault 数据协调器 — 笔记本元数据加载/初始化、演示库构建与自动热恢复活跃笔记本连接。
//
import Foundation

// MARK: - 数据迁移与统计

extension VaultService {

    /// 加载所有笔记本元数据。
    /// 确保系统预置的初始笔记本（"知识图谱"与"项目调研"）始终存在，
    /// 同时保留用户已创建的旧版笔记本数据不丢失。
    func loadVaults() {
        Task {
            guard let vaultRepository = vaultRepository else {
                Logger.shared.warning(" [VaultService] loadVaults 被跳过，因为 vaultRepository 未在 DI 注册")
                // 降级兜底：即使持久化仓储不可用，也要确保 UI 至少有内存级演示笔记本可展示
                self.vaults = buildFallbackDemoVaults()
                return
            }
            do {
                var loadedVaults = try await vaultRepository.fetchAllVaults()

                // 1. 针对历史语言切换可能产生的重复内置笔记本（如简体"知识图谱"与繁体"知識圖譜"）进行物理去重合并
                var seenDemoEnglishNames = Set<String>()
                var cleanedVaults: [Vault] = []
                var vaultsToDelete: [UUID] = []
                for vault in loadedVaults {
                    if vault.englishName == BuiltinVaultEnglishName.personalKM || vault.englishName == BuiltinVaultEnglishName.projectResearch {
                        if seenDemoEnglishNames.contains(vault.englishName) {
                            // 收集待删除的冗余笔记本 ID，遍历结束后串行删除避免竞态
                            vaultsToDelete.append(vault.id)
                            continue
                        }
                        seenDemoEnglishNames.insert(vault.englishName)
                    }
                    cleanedVaults.append(vault)
                }
                loadedVaults = cleanedVaults

                // 串行删除冗余的脏笔记本数据，避免遍历中启动未结构化 Task 导致竞态
                for vaultID in vaultsToDelete {
                    try? await vaultRepository.deleteVault(id: vaultID)
                }

                // 2. 通过 englishName（locale-independent）确保 2 个内置笔记本始终存在，
                // 避免因 locale 变更或旧版命名差异导致内置笔记本缺失
                let demoVaults = buildDefaultDemoVaults()
                for demo in demoVaults {
                    let expectedName = demo.englishName
                    if !loadedVaults.contains(where: { $0.englishName == expectedName }) {
                        loadedVaults.append(demo)
                        try await vaultRepository.saveVault(demo)
                    }
                }

                self.vaults = loadedVaults
                await refreshAllPageCounts()
            } catch {
                Logger.shared.error(" [VaultService] Failed to asynchronously load notebook metadata: \(error)", error: error)
                self.vaults = buildFallbackDemoVaults()
            }
        }

        autoRestoreActiveVault()
    }

    /// 构建初始化的默认演示笔记本
    func buildDefaultDemoVaults() -> [Vault] {
        let id1 = UUID()
        let id2 = UUID()
        return [
            Vault(
                id: id1,
                name: L10n.Vault.defaultName,
                createdAt: Date(),
                updatedAt: Date(),
                pageCount: 0,
                themePayload: nil,
                icon: DesignSystem.Icons.Notebook.defaultBook,
                description: L10n.Vault.defaultDescription
            ),
            Vault(
                id: id2,
                name: L10n.Vault.researchName,
                createdAt: Date(),
                updatedAt: Date(),
                pageCount: 0,
                themePayload: nil,
                icon: DesignSystem.Icons.Notebook.defaultResearch,
                description: L10n.Vault.researchDescription
            )
        ]
    }

    /// 极端降级兜底：建立支持多语言本地化的内存级缓存笔记本
    /// 注意：pageCount 设为 0，实际页面数需在数据库可用后调用 refreshAllPageCounts 更新
    func buildFallbackDemoVaults() -> [Vault] {
        return [
            Vault(
                id: UUID(),
                name: L10n.Vault.defaultName,
                createdAt: Date(),
                updatedAt: Date(),
                pageCount: 0,
                themePayload: nil,
                icon: DesignSystem.Icons.Notebook.defaultBook,
                description: L10n.Vault.defaultDescription
            ),
            Vault(
                id: UUID(),
                name: L10n.Vault.researchName,
                createdAt: Date(),
                updatedAt: Date(),
                pageCount: 0,
                themePayload: nil,
                icon: DesignSystem.Icons.Notebook.defaultResearch,
                description: L10n.Vault.researchDescription
            )
        ]
    }

    /// 自动从持久化偏好中恢复最近一次使用的笔记本并执行底层 SQLite 物理热重载联接
    func autoRestoreActiveVault() {
        if let idString = keyStore?.string(forKey: AppConstants.Keys.Storage.vaultsSelectedID),
           let id = UUID(uuidString: idString),
           let vault = vaults.first(where: { $0.id == id }) {
            self.selectedVaultID = id
            keyStore?.set(vault.englishName, forKey: AppConstants.Keys.Storage.vaultSelectedEnglishName)
            Task {
                guard let databaseSwitcher = databaseSwitcher else {
                    Logger.shared.warning(" [VaultService] autoRestoreActiveVault 被跳过，因为 databaseSwitcher 未在 DI 注册")
                    return
                }
                do {
                    let dbURL = getVaultDatabaseURL(for: id)
                    try await databaseSwitcher.switchDatabase(to: id, at: dbURL)
                } catch {
                    Logger.shared.error(" [VaultService] Failed to auto-connect to the recently used physical database: \(error)", error: error)
                }
            }
        }
    }
}
