//
//  VaultService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Vault 模块中枢协调器 — 持有核心状态、DI 依赖与路径计算，将生命周期/同步/数据操作委托至专用扩展文件。
//
import Foundation
import UFPCore
import Observation
import Dependencies

/// 知识笔记本/笔记本中枢服务（VaultService）。
/// 业务功能层中负责维护多笔记本租户（Multi-Vault）生命周期的大脑门面。
@Observable
@MainActor
public final class VaultService: VaultServiceProtocol {

    // MARK: - 依赖注入

    /// 注入笔记本元数据持久化仓储协议（vaultRepository），使用可选计算属性安全解析以规避单元测试单例污染崩溃。
    /// inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    @ObservationIgnored
    var vaultRepository: (any VaultRepository)? {
        ServiceContainer.shared.resolveOptional((any VaultRepository).self)
    }

    /// 注入数据库切换契约（databaseSwitcher），使用可选计算属性安全解析以规避单元测试单例污染崩溃。
    /// inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
    @ObservationIgnored
    var databaseSwitcher: (any VaultDatabaseSwitcher)? {
        ServiceContainer.shared.resolveOptional((any VaultDatabaseSwitcher).self)
    }

    /// 键值存储抽象，替代 UserDefaults.standard 访问。Factory 风格：标注可选由 @Dependency 自动降级。
    @ObservationIgnored @Dependency(\.keyStore) var keyStore: (any KeyStoreProtocol)?

    // MARK: - 状态发布属性

    /// 当前已注册挂载的全部笔记本列表。
    public var vaults: [Vault] = []

    /// 当前选中的活跃笔记本唯一标识符 UUID。
    public var selectedVaultID: UUID?

    /// 当前选中的活跃笔记本实体对象。
    public var currentVault: Vault? {
        vaults.first { $0.id == selectedVaultID }
    }

    // MARK: - 单例与初始化

    /// 全局唯一的线程安全单例实例。
    public static let shared = VaultService()

    /// 私有化单例构造方法，防止外部直接实例化。
    private init() {
        // 加载条件：非单元测试环境或 UI 测试环境
        // 单元测试时跳过加载，由测试用例自行注入数据
        if !TestModeDetector.isUnitTesting || TestModeDetector.isUITesting {
            loadVaults()
        }
    }

    // MARK: - 物理路径计算辅助

    /// 获取特定笔记本沙盒内的专属物理数据库文件路径。
    /// 物理路径结构规范：`Application Support/ZhiYu/Vaults/{Vault_UUID}/vault.sqlite3`
    func getVaultDatabaseURL(for vaultID: UUID) -> URL {
        // swiftlint:disable:next force_unwrapping
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent(AppConstants.Storage.vaultsDirectoryName)
            .appendingPathComponent(vaultID.uuidString)
            .appendingPathComponent(AppConstants.Storage.vaultDatabaseName)
    }

    // MARK: - 内部持久化辅助

    /// 将笔记本元数据变更原子写回全局配置表中。
    /// - Note: 异步执行，错误通过日志记录而非抛出（调用方无法 await）。
    func saveVaultToDatabase(_ vault: Vault) {
        Task {
            guard let vaultRepository = vaultRepository else {
                Logger.shared.warning(" [VaultService] saveVaultToDatabase 被跳过，因为 vaultRepository 未在 DI 注册")
                return
            }
            do {
                try await vaultRepository.saveVault(vault)
            } catch {
                Logger.shared.error(" [VaultService] saveVaultToDatabase 失败：\(error)")
            }
        }
    }
}
