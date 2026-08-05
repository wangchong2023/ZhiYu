//
//  ContextReranker.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：通用两阶段二次语义重排序与二次降噪引擎 (Universal Context Reranker)。
//           惠及 AI Chat 对话、合成实验室深度扩写与知识关联推演。
//

import Foundation

/// 通用两阶段二次语义重排序引擎
public struct ContextReranker: Sendable {
    
    public init() {}

    /// 对一阶段召回的候选分块进行二次重排序与噪点剪枝
    /// - Parameters:
    ///   - query: 原始提问或查询
    ///   - candidates: 粗粒度召回的候选切片及其一阶段分数值
    ///   - topK: 期望精选保留的最终切片数量 (默认 5)
    /// - Returns: 经二阶段重排序与降噪后的候选切片列表
    public func rerank(
        query: String,
        candidates: [(chunk: PageChunk, score: Float)],
        topK: Int = 5,
        minScore: Float = 0.35
    ) -> [(chunk: PageChunk, score: Float)] {
        guard !candidates.isEmpty else { return [] }

        let queryTokens = Set(query.lowercased().split(separator: " ").map(String.init))

        // 1. 噪点剪枝：先过滤低于极低门槛的非相关切片
        let filtered = candidates.filter { $0.score >= minScore }
        guard !filtered.isEmpty else { return [] }

        // 2. 二次评分重排：结合向量得分 + 关键词精确覆盖密度 (Cross-Matching Density)
        let reranked = filtered.map { item -> (chunk: PageChunk, score: Float) in
            let chunkText = item.chunk.content.lowercased()
            var keywordBonus: Float = 0.0

            if !queryTokens.isEmpty {
                let matchCount = queryTokens.filter { chunkText.contains($0) }.count
                keywordBonus = Float(matchCount) / Float(queryTokens.count) * 0.25
            }

            // 摘要类型切片赋予 1.1x 权重倾斜，避免局部噪点覆盖全文核心
            let typeMultiplier: Float = item.chunk.chunkType == .summary ? 1.1 : 1.0
            let finalScore = (item.score + keywordBonus) * typeMultiplier

            return (chunk: item.chunk, score: finalScore)
        }

        // 3. 按二阶段融合得分强降序排列并截取 Top-K
        let sorted = reranked.sorted(by: { $0.score > $1.score })
        let limit = min(topK, sorted.count)
        return Array(sorted[..<limit])
    }
}
