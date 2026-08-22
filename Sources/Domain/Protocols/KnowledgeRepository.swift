//
//  KnowledgeRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议定义（Repository、Service、Strategy 等抽象）。
//
import Foundation
import Combine
import Dependencies
import UFPCore

/// [Domain] 知识库仓库协议
/// 负责处理所有与 KnowledgePage 相关的持久化操作。
public protocol KnowledgeRepository: Sendable {

    /// 拉取All
    func fetchAll() async throws -> [KnowledgePage]

    /// 拉取
    /// - Parameter id: id
    func fetch(id: UUID) async throws -> KnowledgePage?

    /// 保存
    /// - Parameter page: page
    func save(_ page: KnowledgePage) async throws

    /// 删除
    /// - Parameter id: id
    func delete(id: UUID) async throws

    /// 搜索
    /// - Parameter query: query
    func search(query: String) async throws -> [KnowledgePage]

    /// 拉取Backlinks
    func fetchBacklinks(for id: UUID) async throws -> [UUID]

    /// 重命名Tag
    /// - Parameter old: old
    func renameTag(old: String, to new: String) async throws

    /// 删除Tag
    /// - Parameter tag: tag
    func deleteTag(_ tag: String) async throws

    /// 计数
    func count() async throws -> Int
}

// MARK: - DependencyKey 注册

/// KnowledgePageRepository 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum KnowledgePageRepositoryKey: DependencyKey {
    public static var liveValue: KnowledgePageRepository {
        ServiceContainer.shared.resolve(KnowledgePageRepository.self)
    }
    public static var testValue: KnowledgePageRepository {
        if let existing = ServiceContainer.shared.resolveOptional(KnowledgePageRepository.self) {
            return existing
        }
        // 测试环境降级：Infrastructure 层负责注册，未注册时返回 NoOpKnowledgeRepository 包装
        // 注意：KnowledgePageRepository 是具体类，此处通过 resolveOptional 保证测试已注册时优先返回
        return ServiceContainer.shared.resolve(KnowledgePageRepository.self)
    }
}

extension DependencyValues {
    /// 知识页仓储依赖
    var knowledgePageRepository: KnowledgePageRepository {
        get { self[KnowledgePageRepositoryKey.self] }
        set { self[KnowledgePageRepositoryKey.self] = newValue }
    }
}

// MARK: - KnowledgeRepository DependencyKey 注册

/// KnowledgeRepository 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum KnowledgeRepositoryKey: DependencyKey {
    public static var liveValue: any KnowledgeRepository {
        ServiceContainer.shared.resolve((any KnowledgeRepository).self)
    }

    public static var testValue: any KnowledgeRepository {
        ServiceContainer.shared.resolveOptional((any KnowledgeRepository).self) ?? NoOpKnowledgeRepository()
    }
}

/// 无操作知识库仓储（测试/预览占位，DI 未就绪时降级）
public final class NoOpKnowledgeRepository: KnowledgeRepository, Sendable {
    public init() {}
    public func fetchAll() async throws -> [KnowledgePage] { [] }
    public func fetch(id: UUID) async throws -> KnowledgePage? { nil }
    public func save(_ page: KnowledgePage) async throws {}
    public func delete(id: UUID) async throws {}
    public func search(query: String) async throws -> [KnowledgePage] { [] }
    public func fetchBacklinks(for id: UUID) async throws -> [UUID] { [] }
    public func renameTag(old: String, to new: String) async throws {}
    public func deleteTag(_ tag: String) async throws {}
    public func count() async throws -> Int { 0 }
}

extension DependencyValues {
    /// 知识库仓储依赖
    public var knowledgeRepository: any KnowledgeRepository {
        get { self[KnowledgeRepositoryKey.self] }
        set { self[KnowledgeRepositoryKey.self] = newValue }
    }
}
