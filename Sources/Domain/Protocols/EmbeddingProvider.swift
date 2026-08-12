//
//  EmbeddingProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：跨层协议定义，建立 L0-L3 各层间的抽象契约。
//
import Foundation
import Dependencies
import UFPCore

/// 抽象的文本嵌入向量化（Embedding）服务提供商协议。
public protocol EmbeddingProvider: Sendable {
    /// 计算并获取当前所有已缓存的页面嵌入向量
    func getAllEmbeddings() async -> [UUID: [Float]]

    /// 同步所有待更新的页面向量
    func syncEmbeddings(pages: [KnowledgePage]) async

    /// 当单个页面更新时触发向量重算
    func updateEmbedding(for page: KnowledgePage) async

    /// 批量索引页面分块（支持异步向量化与持久化）
    func indexChunks(pageID: UUID, chunks: [PageChunk]) async

    /// 为一组分块文本生成向量
    func vectorizeChunks(chunks: [String]) async -> [[Float]]

    /// 根据查询词快速计算并返回 TopK 个最相似的页面或分块 ID。
    ///
    /// - Parameters:
    ///   - query: 查询关键字或句。
    ///   - topK: 最多召回的候选数量。
    /// - Returns: 匹配命中的页面 UUID 标识和相似度得分列表。
    func search(query: String, topK: Int) async -> [(id: UUID, score: Float)]
    
    /// 多路召回搜索 (Multi-Query + RRF 融合)
    func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)]
    
    /// HyDE (Hypothetical Document Embeddings) 搜索
    func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)]
    
    /// Self-Reflection (Rerank) 搜索
    func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)]
    
    /// 综合高级检索策略
    func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)]
    
    /// 异步加载初始缓存
    func loadInitialCache() async
    
    /// 物理清空内存向量缓存并重载
    func clearCacheAndReload() async
}

// MARK: - DependencyKey 注册

/// EmbeddingProvider 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum EmbeddingProviderKey: DependencyKey {
    public static var liveValue: any EmbeddingProvider {
        ServiceContainer.shared.resolve((any EmbeddingProvider).self)
    }
}

extension DependencyValues {
    /// 嵌入向量化服务依赖
    public var embeddingProvider: any EmbeddingProvider {
        get { self[EmbeddingProviderKey.self] }
        set { self[EmbeddingProviderKey.self] = newValue }
    }
}
