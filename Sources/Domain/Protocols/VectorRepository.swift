//
//  VectorRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议定义（Repository、Service、Strategy 等抽象）。
//
import Foundation

/// [Domain] 向量与分块仓储协议
public protocol VectorRepository: Sendable {
    // MARK: - 语义分块 (Chunks)
    
    /// 保存页面的分块数据
    func saveChunks(_ chunks: [PageChunk], for pageID: UUID) async throws
    
    /// 获取特定页面的所有分块
    func fetchChunks(for pageID: UUID) async throws -> [PageChunk]
    
    /// 获取知识库中所有具备向量嵌入的分块 (用于冷启动缓存)
    func fetchAllChunksWithEmbeddings() async throws -> [PageChunk]
    
    /// 删除特定页面的所有分块
    func deleteChunks(for pageID: UUID) async throws
    
    /// 清理孤立分块 (即其所属页面已删除的分块)
    func cleanupOrphanedChunks() async throws -> Int

    // MARK: - 页面级向量 (Embeddings)
    
    /// 保存页面级向量嵌入
    func saveEmbedding(id: UUID, vector: [Float], modelName: String) async throws
    
    /// 获取知识库中所有页面的向量嵌入 (用于冷启动缓存)
    func fetchAllEmbeddings() async throws -> [UUID: [Float]]
}

// MARK: - DependencyKey 注册

import Dependencies
import UFPCore

/// VectorRepository 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum VectorRepositoryKey: DependencyKey {
    public static var liveValue: any VectorRepository {
        ServiceContainer.shared.resolve((any VectorRepository).self)
    }
}

extension DependencyValues {
    /// 向量仓储依赖
    public var vectorRepository: any VectorRepository {
        get { self[VectorRepositoryKey.self] }
        set { self[VectorRepositoryKey.self] = newValue }
    }
}
