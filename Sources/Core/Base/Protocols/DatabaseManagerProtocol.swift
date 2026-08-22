//
//  DatabaseManagerProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 DatabaseManager 模块的抽象契约接口。
//
import Foundation
import Dependencies
import UFPCore

/// 数据库热切换与连接生命周期隔离契约。
///
/// 遵循此协议的实例能够安全地调度并挂载不同的物理数据库，并提供物理释放通道连接、闭合文件锁的生命周期管理，
/// 从而确保多笔记本隔离切换时不发生 `SQLITE_BUSY` 死锁。
@MainActor
public protocol VaultDatabaseSwitcher: Sendable {
    /// 进行多数据库实例的安全切换与 WAL 锁重置。
    ///
    /// - Parameters:
    ///   - vaultID: 切换目标笔记本的唯一识别码 UUID。
    ///   - url: 目标笔记本数据库在沙盒中的物理绝对路径 URL。
    /// - Throws: SQLite 实例化失败或专属 Schema 迁移失败的异常。
    func switchDatabase(to vaultID: UUID, at url: URL) async throws
    
    /// 彻底断开专属物理库写入池，清空文件锁。
    ///
    /// 此方法旨在同步释放专属物理库的所有活跃读取与写入句柄，强制关闭物理库的 WAL 缓存，
    /// 以允许对数据库文件进行离线备份、擦除或移动等操作。
    func releaseDatabaseConnection()

    /// 读取当前活跃 Vault 数据库的页面数量。
    func countPagesInCurrentVault() async throws -> Int

    /// 读取指定 URL 处数据库文件的页面数量。
    /// - Parameter url: 数据库文件路径
    func countPages(at url: URL) async throws -> Int
}

// MARK: - NoOp 实现

/// VaultDatabaseSwitcher 的空操作实现，用于测试环境安全降级
@MainActor
public final class NoOpVaultDatabaseSwitcher: VaultDatabaseSwitcher, @unchecked Sendable {
    public init() {}
    public func switchDatabase(to vaultID: UUID, at url: URL) async throws {}
    public func releaseDatabaseConnection() {}
    public func countPagesInCurrentVault() async throws -> Int { 0 }
    public func countPages(at url: URL) async throws -> Int { 0 }
}

// MARK: - DependencyKey 注册

/// VaultDatabaseSwitcher 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum VaultDatabaseSwitcherKey: DependencyKey {
    @MainActor
    public static var liveValue: any VaultDatabaseSwitcher {
        ServiceContainer.shared.resolve((any VaultDatabaseSwitcher).self)
    }
    @MainActor
    public static var testValue: any VaultDatabaseSwitcher {
        ServiceContainer.shared.resolveOptional((any VaultDatabaseSwitcher).self) ?? NoOpVaultDatabaseSwitcher()
    }
    @MainActor
    public static var previewValue: any VaultDatabaseSwitcher { NoOpVaultDatabaseSwitcher() }
}

extension DependencyValues {
    /// 数据库热切换器依赖
    public var vaultDatabaseSwitcher: any VaultDatabaseSwitcher {
        get { self[VaultDatabaseSwitcherKey.self] }
        set { self[VaultDatabaseSwitcherKey.self] = newValue }
    }
}
