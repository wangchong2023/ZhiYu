//
//  VaultLifecycleManager.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Vault 生命周期管理 — 创建/删除/重命名/选择/退出笔记本，含物理数据库级联切换与沙盒销毁。
//
import Foundation

// MARK: - Vault 生命周期管理

extension VaultService {

    /// 异步选择并等待数据库切换完成（用于批量数据操作等需要确保切换完成的场景）
    public func selectVaultAndWait(_ vault: Vault) async throws {
        self.selectedVaultID = vault.id
        keyStore?.set(vault.id.uuidString, forKey: AppConstants.Keys.Storage.vaultsSelectedID)
        keyStore?.set(vault.englishName, forKey: AppConstants.Keys.Storage.vaultSelectedEnglishName)

        guard let vaultRepository = vaultRepository,
              databaseSwitcher != nil else {
            Logger.shared.warning(" [VaultService] selectVaultAndWait 被跳过，因为相关数据库依赖未在 DI 注册")
            return
        }

        try? await vaultRepository.saveSetting(key: AppConstants.Keys.Storage.vaultsSelectedID, value: vault.id.uuidString)
        NotificationCenter.default.post(name: .vaultWillSwitch, object: vault.id)

        try await performVaultDatabaseSwitch(for: vault.id)
    }

    /// 选择并激活目标笔记本，同时触发底层的专属物理数据库 WAL 切换。
    public func selectVault(_ vault: Vault) {
        self.selectedVaultID = vault.id
        keyStore?.set(vault.id.uuidString, forKey: AppConstants.Keys.Storage.vaultsSelectedID)
        keyStore?.set(vault.englishName, forKey: AppConstants.Keys.Storage.vaultSelectedEnglishName)
        Task {
            guard let vaultRepository = vaultRepository else { return }
            try? await vaultRepository.saveSetting(key: AppConstants.Keys.Storage.vaultsSelectedID, value: vault.id.uuidString)
        }

        NotificationCenter.default.post(name: .vaultWillSwitch, object: vault.id)

        Task {
            guard databaseSwitcher != nil,
                  vaultRepository != nil else {
                Logger.shared.warning(" [VaultService] selectVault 物理切换被跳过，因为底层依赖未在 DI 注册")
                return
            }
            do {
                try await performVaultDatabaseSwitch(for: vault.id)
            } catch {
                Logger.shared.error("[VaultService] selectVault switch failed: \(error.localizedDescription)", error: error)
            }
        }
    }

    /// 统一执行保险库专属物理数据库切换与元数据更新
    private func performVaultDatabaseSwitch(for vaultID: UUID) async throws {
        guard let databaseSwitcher = databaseSwitcher else { return }
        let dbURL = getVaultDatabaseURL(for: vaultID)
        try await databaseSwitcher.switchDatabase(to: vaultID, at: dbURL)
        try? await vaultRepository?.updateLastAccessed(id: vaultID)
        await refreshPageCount(for: vaultID)
    }

    /// 退出当前选中的笔记本笔记本。
    public func exitVault() {
        NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)

        self.selectedVaultID = nil
        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultsSelectedID)
        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultSelectedEnglishName)
        databaseSwitcher?.releaseDatabaseConnection()
    }

    /// 创建全新的笔记本笔记本。
    public func createVault(name: String, icon: String? = nil, description: String? = nil) {
        let newVault = Vault(
            id: UUID(),
            name: name,
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 0,
            themePayload: nil,
            icon: icon,
            description: description
        )
        saveVaultToDatabase(newVault)
        vaults.append(newVault)
        keyStore?.set(true, forKey: "\(AppConstants.Keys.Storage.seededVaultPrefix)\(newVault.id.uuidString)")
    }

    /// 更新已存在笔记本的配置元数据。
    public func updateVault(id: UUID, name: String, icon: String?, description: String?) {
        if let index = vaults.firstIndex(where: { $0.id == id }) {
            vaults[index].name = name
            vaults[index].icon = icon
            vaults[index].description = description
            vaults[index].updatedAt = Date()

            saveVaultToDatabase(vaults[index])
        }
    }

    /// 重命名特定的笔记本。
    public func renameVault(id: UUID, newName: String) {
        if let index = vaults.firstIndex(where: { $0.id == id }) {
            vaults[index].name = newName
            vaults[index].updatedAt = Date()

            saveVaultToDatabase(vaults[index])
        }
    }

    /// 物理删除特定的笔记本（敏感操作，物理擦除物理磁盘文件）。
    public func deleteVault(id: UUID) {
        vaults.removeAll { $0.id == id }
        if selectedVaultID == id {
            NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)
            selectedVaultID = nil
            keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultsSelectedID)
            keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultSelectedEnglishName)
            databaseSwitcher?.releaseDatabaseConnection()
        }

        Task {
            guard let vaultRepository = vaultRepository else {
                Logger.shared.warning(" [VaultService] deleteVault 中的元数据删除被跳过，因为 vaultRepository 未在 DI 注册")
                return
            }
            do {
                try await vaultRepository.deleteVault(id: id)
            } catch {
                Logger.shared.error(" [VaultService] Failed to delete notebook record from global metadata database: \(error)", error: error)
            }

            let dbURL = getVaultDatabaseURL(for: id)
            let folderURL = dbURL.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: folderURL.path) {
                try? FileManager.default.removeItem(at: folderURL)
                Logger.shared.info(" [VaultService] Physically erased notebook sandbox storage: \(id.uuidString)")
            }
        }
    }
}
