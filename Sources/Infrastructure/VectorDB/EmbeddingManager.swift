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
import ZhiYuDomain
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
    /// 缓存代次计数器（每次 clearCache 递增，防止切库前挂起的旧异步加载/索引回写污染新 Vault 缓存）
    private var cacheGeneration: UInt64 = 0

    /// 跨进程绝对确定性 FNV-1a 64-bit 哈希常量（替代进程级随机种子的 Swift.Hasher）
    private enum DeterministicHashConstants {
        static let fnvOffsetBasis: UInt64 = 14_695_981_039_346_656_037
        static let fnvPrime: UInt64 = 1_099_511_628_211
    }

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
        startVaultIsolationObservers()
    }

    /// 订阅 Vault 切换与底层数据库热切换通知，保证多笔记本向量缓存严格物理隔离，杜绝跨 Vault 数据泄露
    private nonisolated func startVaultIsolationObservers() {
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .vaultWillSwitch) {
                guard let self else { break }
                await self.clearCache()
            }
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .databaseDidSwitch) {
                guard let self else { break }
                await self.clearCacheAndReload()
            }
        }
    }

    // MARK: - 核心同步逻辑

    /// 异步加载初始缓存（带代次守卫，防止 Vault 切换后旧库查询结果回写污染新库缓存）
    public func loadInitialCache() async {
        let capturedGeneration = cacheGeneration
        do {
            let embeddings = try await repository.fetchAllEmbeddings()
            guard cacheGeneration == capturedGeneration else { return }
            for emb in embeddings {
                vectorCache[emb.key] = emb.value
            }
            
            // 加载所有已入库的分块元数据（分块级向量在冷启动时不预加载）
            let chunks = try await repository.fetchAllChunksWithEmbeddings()
            guard cacheGeneration == capturedGeneration else { return }
            for chunk in chunks {
                chunkMetadata[chunk.id] = chunk
                // 如果分块包含序列化的嵌入数据，安全反序列化到缓存（防止非对齐/截断/NaN 字节污染）
                if let data = chunk.embedding, let vector = Self.decodeFloatVector(from: data) {
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

    /// 批量索引页面分块（先清理同页旧分块缓存防止幽灵命中，再异步向量化与持久化）
    public func indexChunks(pageID: UUID, chunks: [PageChunk]) async {
        // 清理该页面在内存中的历史旧分块，避免缩减分块数量后残留幽灵分块
        let staleChunkIDs = chunkMetadata.compactMap { entry in
            entry.value.pageID == pageID ? entry.key : nil
        }
        for staleID in staleChunkIDs {
            chunkVectorCache.removeValue(forKey: staleID)
            chunkMetadata.removeValue(forKey: staleID)
        }

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
        guard topK > 0, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let queryVector = getVector(for: query)
        var fallbackQueryVector: [Float]?
        var results: [(id: UUID, score: Float)] = []
        
        for (id, vector) in vectorCache {
            let effectiveQuery = resolveQueryVector(primary: queryVector, fallbackCache: &fallbackQueryVector, query: query, targetDimension: vector.count)
            let score = EmbeddingManager.cosineSimilarity(effectiveQuery, vector)
            if score > SearchConstants.semanticThresholdShort {
                results.append((id, score))
            }
        }
        
        return results.sorted { $0.score > $1.score }.prefix(topK).map { $0 }
    }

    /// 多路召回搜索 (Multi-Query + RRF 融合)
    public func multiQuerySearch(query: String, topK: Int) async -> [(chunk: PageChunk, score: Float)] {
        // 此处为简化版实现：直接对分块缓存进行余弦搜索
        return searchChunkCache(query: query, topK: topK, threshold: SearchDefaults.similarityThreshold)
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

    /// 在分块向量缓存中执行余弦相似度搜索，返回 TopK 结果
    /// - Parameters:
    ///   - query: 查询文本
    ///   - topK: 返回的最大候选数量
    ///   - threshold: 相似度阈值，低于此值的结果被过滤
    /// - Returns: 命中的分块元数据与相似度得分列表
    private func searchChunkCache(
        query: String,
        topK: Int,
        threshold: Float
    ) -> [(chunk: PageChunk, score: Float)] {
        guard topK > 0, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let queryVector = getVector(for: query)
        var fallbackQueryVector: [Float]?
        var results: [(chunk: PageChunk, score: Float)] = []

        for (idString, vector) in chunkVectorCache {
            let effectiveQuery = resolveQueryVector(primary: queryVector, fallbackCache: &fallbackQueryVector, query: query, targetDimension: vector.count)
            let score = EmbeddingManager.cosineSimilarity(effectiveQuery, vector)
            if score > threshold, let metadata = chunkMetadata[idString] {
                results.append((metadata, score))
            }
        }

        return results.sorted { $0.score > $1.score }.prefix(topK).map { $0 }
    }

    /// 当历史落盘向量为 512 维 Fallback 向量而当前 NLEmbedding 为 640 维时，懒加载同维 Fallback 查询向量，避免维度失配导致检索归零
    private func resolveQueryVector(
        primary: [Float],
        fallbackCache: inout [Float]?,
        query: String,
        targetDimension: Int
    ) -> [Float] {
        guard primary.count != targetDimension, targetDimension == SearchDefaults.vectorDimension else {
            return primary
        }
        if let cached = fallbackCache {
            return cached
        }
        let generated = Self.deterministicFallbackVector(for: query)
        fallbackCache = generated
        return generated
    }

    /// 物理清空内存向量缓存（供 Vault 切换/退出时立即隔离旧笔记本数据，并递增代次阻断旧异步回写）
    public func clearCache() {
        cacheGeneration &+= 1
        vectorCache.removeAll()
        chunkVectorCache.removeAll()
        chunkMetadata.removeAll()
    }

    /// 物理清空内存向量缓存并重载
    public func clearCacheAndReload() async {
        clearCache()
        await loadInitialCache()
    }

    // MARK: - 内部数学工具

    /// 跨进程确定性 Fallback 向量生成（使用 FNV-1a 64-bit 哈希，彻底消除 Swift.Hasher 随机种子跨重启失效）
    internal static func deterministicFallbackVector(for text: String) -> [Float] {
        var seed = DeterministicHashConstants.fnvOffsetBasis
        for byte in text.utf8 {
            seed ^= UInt64(byte)
            seed = seed &* DeterministicHashConstants.fnvPrime
        }
        let modulus = UInt64(SearchDefaults.deterministicModulus)
        var deterministicVector = [Float](repeating: 0, count: SearchDefaults.vectorDimension)
        for index in 0..<SearchDefaults.vectorDimension {
            let mixed = (seed ^ UInt64(index)) &* DeterministicHashConstants.fnvPrime
            deterministicVector[index] = Float(mixed % modulus) / SearchDefaults.deterministicModulus
        }
        return deterministicVector
    }

    /// 获取文本对应的向量表示。
    private func getVector(for text: String) -> [Float] {
        if let model = embeddingModel, let vector = model.vector(for: text) {
            return vector.map { Float($0) }
        }
        return Self.deterministicFallbackVector(for: text)
    }

    /// 安全反序列化二进制向量，避免非对齐/截断字节触发崩溃，并拦截含 NaN/Infinity 的损坏向量
    internal static func decodeFloatVector(from data: Data) -> [Float]? {
        let stride = MemoryLayout<Float>.stride
        guard !data.isEmpty, data.count % stride == 0 else { return nil }
        var vector = [Float](repeating: 0, count: data.count / stride)
        _ = vector.withUnsafeMutableBytes { destination in
            data.copyBytes(to: destination)
        }
        guard vector.allSatisfy(\.isFinite) else { return nil }
        return vector
    }

    /// 计算两个向量的余弦相似度
    public static func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        return VectorMath.cosineSimilarity(v1, v2)
    }
}
