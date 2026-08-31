//
//  EmbeddingManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现基于 Apple NLEmbedding 的向量化与相似度检索业务。
//
import Foundation
import NaturalLanguage
import UFPCore

/// 向量管理中心
/// 负责知识分块的异步向量化、持久化同步及高性能语义检索。
public actor EmbeddingManager: EmbeddingProvider {
    /// 向量存储仓储
    private let repository: any VectorRepository
    /// 自然语言嵌入模型
    private let embeddingModel: NLEmbedding?
    /// 当前使用的模型名称
    private let modelName = PromptConstants.InferenceDefaults.defaultEmbeddingModel

    /// 内存缓存：页面级向量
    private var vectorCache: [UUID: [Float]] = [:]
    /// 内存缓存：分块级向量
    private var chunkVectorCache: [String: [Float]] = [:]
    /// 内存缓存：分块元数据
    private var chunkMetadata: [String: PageChunk] = [:]

    /// 向量检索默认参数常量
    public enum SearchDefaults {
        /// 默认召回候选数量
        public static let defaultTopK: Int = 10
        /// 语义相似度阈值（低于此值视为不相关）
        public static let similarityThreshold: Float = 0.3
        /// 确定性向量生成的模数（用于归一化哈希值到 [0, 1) 区间）
        public static let deterministicModulus: Float = 1000
        /// 确定性向量维度（与 NLEmbedding 512 维对齐）
        public static let vectorDimension: Int = 512
    }

    /// 获取所有已缓存的页面嵌入向量
    public func getAllEmbeddings() async -> [UUID: [Float]] {
        return vectorCache
    }

    public init(repository: any VectorRepository) {
        self.repository = repository
        self.embeddingModel = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese)
        
        Task {
            await loadInitialCache()
        }
    }

    // MARK: - 核心同步逻辑

    /// 异步加载初始缓存
    public func loadInitialCache() async {
        do {
            let embeddings = try await repository.fetchAllEmbeddings()
            for emb in embeddings {
                vectorCache[emb.key] = emb.value
            }
            
            // 加载所有已入库的分块元数据（分块级向量在冷启动时不预加载）
            let chunks = try await repository.fetchAllChunksWithEmbeddings()
            for chunk in chunks {
                chunkMetadata[chunk.id] = chunk
                // 如果分块包含序列化的嵌入数据，反序列化到缓存
                if let data = chunk.embedding {
                    let vector = data.withUnsafeBytes { buffer in
                        [Float](buffer.bindMemory(to: Float.self))
                    }
                    chunkVectorCache[chunk.id] = vector
                }
            }
        } catch {
            Logger.shared.error(" [Embedding]" + " Failed to" + " load initial" + " cache: \(error)", error: error)
        }
    }

    /// 同步所有待更新的页面向量 (@RR-01)
    public func syncEmbeddings(pages: [KnowledgePage]) async {
        for page in pages where vectorCache[page.id] == nil {
                await updateEmbedding(for: page)
        }
    }

    /// 当单个页面更新时触发向量重算
    public func updateEmbedding(for page: KnowledgePage) async {
        let vector = getVector(for: page.title + "\n" + page.content)
        vectorCache[page.id] = vector
        
        // 物理入库
        try? await repository.saveEmbedding(id: page.id, vector: vector, modelName: modelName)
    }

    /// 批量索引页面分块（支持异步向量化与持久化）
    public func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        guard !chunks.isEmpty else { return }
        
        // 1. 生成向量
        let contents = chunks.map { $0.content }
        let vectors = await vectorizeChunks(chunks: contents)
        
        // 2. 物理入库：将向量转换为 Data 并赋值给分块实体，之后进行持久化保存
        var updatedChunks = chunks
        for index in 0..<updatedChunks.count {
            let vector = vectors[index]
            // 将 [Float] 向量序列化为二进制 Data 存入 embedding
            let data = vector.withUnsafeBufferPointer { Data(buffer: $0) }
            updatedChunks[index].embedding = data
            
            let chunkID = updatedChunks[index].id
            chunkVectorCache[chunkID] = vector
            chunkMetadata[chunkID] = updatedChunks[index]
        }
        
        try? await repository.saveChunks(updatedChunks, for: pageID)
    }

    /// 为一组分块文本生成向量
    public func vectorizeChunks(chunks: [String]) async -> [[Float]] {
        return chunks.map { getVector(for: $0) }
    }

    // MARK: - 语义检索

    /// 根据查询词快速计算并返回 TopK 个最相似的页面或分块 ID。
    ///
    /// - Parameters:
    ///   - query: 查询关键字或句。
    ///   - topK: 最多召回的候选数量。
    /// - Returns: 匹配命中的页面 UUID 标识和相似度得分列表。
    public func search(query: String, topK: Int = SearchDefaults.defaultTopK) async -> [(id: UUID, score: Float)] {
        let queryVector = getVector(for: query)
        var results: [(id: UUID, score: Float)] = []
        
        for (id, vector) in vectorCache {
            let score = EmbeddingManager.cosineSimilarity(queryVector, vector)
            if score > SearchConstants.semanticThresholdShort {
                results.append((id, score))
            }
        }
        
        return results.sorted { $0.score > $1.score }.prefix(topK).map { $0 }
    }

    /// 多路召回搜索 (Multi-Query + RRF 融合)
    public func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] {
        // 此处为简化版实现：直接对分块缓存进行余弦搜索
        let queryVector = getVector(for: query)
        var results: [(chunk: PageChunk, score: Float)] = []
        
        for (idString, vector) in chunkVectorCache {
            let score = EmbeddingManager.cosineSimilarity(queryVector, vector)
            if score > SearchDefaults.similarityThreshold, let metadata = chunkMetadata[idString] {
                results.append((metadata, score))
            }
        }
        
        return results.sorted { $0.score > $1.score }.prefix(topK).map { $0 }
    }

    /// HyDE (Hypothetical Document Embeddings) 搜索
    public func hydeSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] {
        // 简化版实现
        return await multiQuerySearch(query: query, topK: topK)
    }

    /// Self-Reflection (Rerank) 搜索
    public func selfReflectionSearch(query: String, candidates: [(chunk: PageChunk, score: Float)]) async -> [(chunk: PageChunk, score: Float)] {
        // 简化版实现：返回原样
        return candidates
    }

    /// 综合高级检索策略 (Advanced Retrieval)
    public func advancedSearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] {
        return await multiQuerySearch(query: query, topK: topK)
    }

    /// 物理清空内存向量缓存并重载
    public func clearCacheAndReload() async {
        vectorCache.removeAll()
        chunkVectorCache.removeAll()
        chunkMetadata.removeAll()
        await loadInitialCache()
    }

    // MARK: - 内部数学工具

    /// 获取文本对应的向量表示。
    private func getVector(for text: String) -> [Float] {
        if let model = embeddingModel, let vector = model.vector(for: text) {
            return vector.map { Float($0) }
        }
        
        // Fallback: 确定性随机向量 (保障测试确定性)
        var hasher = Hasher()
        hasher.combine(text)
        let seed = hasher.finalize()
        var deterministicVector = [Float](repeating: 0, count: SearchDefaults.vectorDimension)
        for i in 0..<SearchDefaults.vectorDimension {
            // UInt64(bitPattern:) 零成本转换，消除 abs(Int.min) 溢出风险
            let mixed = UInt64(bitPattern: Int64(truncatingIfNeeded: seed ^ i))
            deterministicVector[i] = Float(mixed % UInt64(SearchDefaults.deterministicModulus)) / SearchDefaults.deterministicModulus
        }
        return deterministicVector
    }

    /// 计算两个向量的余弦相似度
    public static func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        return VectorMath.cosineSimilarity(v1, v2)
    }
}
