//
//  MaintenanceService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 Maintenance 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies
import Observation
import UFPStorage

/// 系统维护服务 (L1-Infra)
/// 负责处理非核心业务的系统级管理任务。
@MainActor
public final class MaintenanceService {
    
    @ObservationIgnored @Dependency(\.pageStoreCapabilities) private var pageStore: any AnyPageStoreCapabilities
    @ObservationIgnored @Dependency(\.vaultService) private var vaultService: any VaultServiceProtocol
    @ObservationIgnored @Dependency(\.backupService) private var backupService: BackupService
    @ObservationIgnored @Dependency(\.logger) private var logger: any LoggerProtocol
    @ObservationIgnored @Dependency(\.undoService) private var undoService: UndoService?

    private var activeLogger: any LoggerProtocol {
        logger ?? Logger.shared
    }

    public init() {}
    
    // MARK: - 演示数据与种子

    /// 生成演示数据
    @discardableResult

    /// 生成初始笔记本
    /// - Returns: 数值
    /// 生成演示数据，返回总数和每个笔记本的注入详情
    public func generateInitialNotebooks() async -> (total: Int, details: [(name: String, count: Int)]) {
        struct VaultConfig { let name: String; let icon: String; let description: String }
        let demoVaultConfigs: [VaultConfig] = [
            VaultConfig(name: L10n.Vault.defaultName, icon: DesignSystem.Icons.Notebook.defaultBook, description: L10n.Vault.defaultDescription),
            VaultConfig(name: L10n.Vault.researchName, icon: DesignSystem.Icons.Notebook.defaultResearch, description: L10n.Vault.researchDescription)
        ]

        var existingVaults = vaultService.vaults
        for config in demoVaultConfigs {
            let targetEnglishName = Vault(name: config.name).englishName
            if !existingVaults.contains(where: { $0.englishName == targetEnglishName }) {
                vaultService.createVault(name: config.name, icon: config.icon, description: config.description)
                activeLogger.addLog(action: .create, target: config.name, details: StorageConstants.LogDetails.initialNotebookVaultCreated, module: StorageConstants.LogModule.maintenance)
            }
        }

        existingVaults = vaultService.vaults
        guard !existingVaults.isEmpty else {
            do {
                let count = try await InitialNotebookGenerator.generate(in: pageStore)
                return (total: count, details: [(L10n.Vault.defaultName, count)])
            } catch {
                return (total: 0, details: [])
            }
        }

        var totalCount = 0
        var vaultDetails: [(name: String, count: Int)] = []
        for vault in existingVaults {
            do {
                try await vaultService.selectVaultAndWait(vault)
                
                // 根据笔记本名称注入相应的数据源，彻底解决出厂预置数据归属混乱的问题
                let count: Int
                if vault.name == L10n.Vault.researchName || vault.name == L10n.Vault.researchNameZh || vault.name == L10n.Vault.researchNameEn || vault.name == L10n.InitialNotebook.Log.projectResearch {
                    count = try await InitialNotebookGenerator.generateResearchNotebook(in: pageStore)
                } else {
                    count = try await InitialNotebookGenerator.generate(in: pageStore)
                }
                
                totalCount += count
                vaultDetails.append((name: vault.name, count: count))
                await vaultService.refreshPageCount(for: vault.id)
                activeLogger.addLog(action: .create, target: vault.name, details: StorageConstants.LogDetails.initialNotebookPageCountRefreshed, module: StorageConstants.LogModule.maintenance)
            } catch {
                activeLogger.addLog(action: .error, target: vault.name, details: StorageConstants.LogDetails.initialNotebookFailed, module: StorageConstants.LogModule.maintenance)
            }
        }
        return (total: totalCount, details: vaultDetails)
    }

    /// 填充默认引导内容
    public func seedDefaultContent(pages: [KnowledgePage], vaultName: String? = nil) async {
        guard pages.isEmpty else { return }
        
        // 是否处于自动化 UI 测试模式，用于自愈保护
        let isTesting = ProcessInfo.processInfo.arguments.contains(StorageConstants.LaunchEnvironment.uitestingLaunchArg) || ProcessInfo.processInfo.environment[StorageConstants.LaunchEnvironment.uitestingEnvKey] == StorageConstants.OperationStatus.true
        
        // 尝试获取当前选中笔记本名称（当 vaultName 为 nil 时兜底）
        let resolvedName: String? = vaultName ?? VaultService.shared.currentVault?.name
        
        do {
            if resolvedName == L10n.Vault.defaultName || resolvedName == L10n.Vault.defaultNameZh || resolvedName == L10n.Vault.defaultNameEn || (isTesting && (vaultName == nil || vaultName?.contains(StorageConstants.TestName.vaultMarker) == true)) {
                // 默认知识管理笔记本 — 注入 AI 概念与 API 日志演示数据
                _ = try await InitialNotebookGenerator.generate(in: pageStore)
                activeLogger.addLog(action: .create, target: L10n.InitialNotebook.Log.defaultDemoData, details: StorageConstants.LogDetails.seededDefaultContent, module: StorageConstants.LogModule.maintenance)
            } else if resolvedName == L10n.Vault.researchName || resolvedName == L10n.Vault.researchNameZh || resolvedName == L10n.Vault.researchNameEn || resolvedName == L10n.InitialNotebook.Log.projectResearch || (isTesting && vaultName?.contains(StorageConstants.TestName.researchMarker) == true) {
                // 项目调研笔记本 — 注入行业分析演示数据
                _ = try await InitialNotebookGenerator.generateResearchNotebook(in: pageStore)
                activeLogger.addLog(action: .create, target: L10n.InitialNotebook.Log.researchDemoData, details: StorageConstants.LogDetails.seededResearchContent, module: StorageConstants.LogModule.maintenance)
            } else if isTesting || resolvedName != nil {
                // 兜底：不为空的笔记本都尝试注入默认数据
                _ = try await InitialNotebookGenerator.generate(in: pageStore)
                activeLogger.addLog(action: .create, target: L10n.InitialNotebook.Log.fallbackDemoData, details: StorageConstants.LogDetails.seededFallbackContent, module: StorageConstants.LogModule.maintenance)
            }
        } catch {
            activeLogger.addLog(action: .error, target: vaultName ?? L10n.InitialNotebook.Log.unknownVault, details: StorageConstants.LogDetails.seedFailedPrefix + "\(error)", module: StorageConstants.LogModule.maintenance)
        }
    }

    // MARK: - 系统重置

    /// 清除所有开发者数据 (重置系统)
    public func clearAllDeveloperData() async {
        undoService?.clear()
        try? await pageStore.resetDatabase()
        AppEventBus.shared.publish(.pagesCleared)
    }

    // MARK: - 磁盘与日志

    /// 保存关键状态至磁盘并触发备份
    public func saveToDisk(pages: [KnowledgePage]) async {
        await activeLogger.saveToDisk()
        backupService.createBackup(pages: pages)
    }

    /// 从磁盘重新加载数据
    public func loadFromDisk() async {
        await pageStore.reloadFromDisk()
        await activeLogger.loadFromDisk()
    }

    /// 清理所有日志
    public func clearLogs() async {
        await activeLogger.clearAllLogs()
    }
}

// MARK: - DependencyKey

@MainActor
public enum MaintenanceServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: MaintenanceService { ServiceContainer.shared.resolve(MaintenanceService.self) }

    @MainActor
    public static var testValue: MaintenanceService {
        ServiceContainer.shared.resolveOptional(MaintenanceService.self) ?? MaintenanceService()
    }
}

extension DependencyValues {
    @MainActor
    public var maintenanceService: MaintenanceService {
        get { self[MaintenanceServiceKey.self] }
        set { self[MaintenanceServiceKey.self] = newValue }
    }
}
