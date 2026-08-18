//
//  VaultRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议定义（Repository、Service、Strategy 等抽象）。
//
import Foundation
import Dependencies
import UFPCore

/// [Domain] 笔记本/知识库元数据仓储协议，实现多库隔离元数据的解耦存储。
public protocol VaultRepository: Sendable {
    /// 获取所有笔记本元数据列表 (按最后访问时间降序排列)
    func fetchAllVaults() async throws -> [Vault]
    
    /// 保存或更新单个笔记本元数据
    func saveVault(_ vault: Vault) async throws
    
    /// 更新指定笔记本的最后访问时间戳为当前时间
    func updateLastAccessed(id: UUID) async throws
    
    /// 从元数据表中物理删除指定笔记本
    func deleteVault(id: UUID) async throws

    /// 写入全局配置项（供 Widget Extension 跨进程读取）
    func saveSetting(key: String, value: String) async throws
}

// MARK: - DependencyKey 注册

/// VaultRepository 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum VaultRepositoryKey: DependencyKey {
    public static var liveValue: any VaultRepository {
        ServiceContainer.shared.resolve((any VaultRepository).self)
    }
}

extension DependencyValues {
    /// 笔记本元数据仓储依赖
    public var vaultRepository: any VaultRepository {
        get { self[VaultRepositoryKey.self] }
        set { self[VaultRepositoryKey.self] = newValue }
    }
}
