//
//  ContextReranker.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICore]
//  核心职责：RAG 检索上下文二阶段重排序与噪点剪枝引擎 (Context Reranker)。
//

import Foundation
import UFPCore
import ZhiYuDomain

public struct ContextRerankChunk: Sendable, Identifiable {
    public var id: String
    public var content: String
    public var index: Int

    public init(id: String = UUID().uuidString, content: String, index: Int) {
        self.id = id
        self.content = content
        self.index = index
    }
}

public struct RerankedResult: Sendable {
    public var chunk: ContextRerankChunk
    public var score: Float

    public init(chunk: ContextRerankChunk, score: Float) {
        self.chunk = chunk
        self.score = score
    }
}

public struct ContextReranker: Sendable {

    public init() {}

    /// 执行两阶段重排序与噪点剪枝
    public func rerank(
        query: String,
        candidates: [(chunk: ContextRerankChunk, initialScore: Float)],
        topK: Int = 5,
        minScore: Float = 0.35
    ) -> [RerankedResult] {
        let queryTokens = Set(query.lowercased().split(separator: " ").map(String.init))

        let reranked = candidates.compactMap { candidate -> RerankedResult? in
            let chunkTokens = Set(candidate.chunk.content.lowercased().split(separator: " ").map(String.init))
            let overlap = Float(queryTokens.intersection(chunkTokens).count)
            let crossScore = queryTokens.isEmpty ? 0.0 : (overlap / Float(queryTokens.count))

            let finalScore = candidate.initialScore * 0.7 + crossScore * 0.3
            guard finalScore >= minScore else { return nil }

            return RerankedResult(chunk: candidate.chunk, score: finalScore)
        }

        return Array(reranked.sorted(by: { $0.score > $1.score }).prefix(topK))
    }
}
