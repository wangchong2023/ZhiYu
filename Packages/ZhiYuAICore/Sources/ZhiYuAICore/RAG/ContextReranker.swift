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
import NaturalLanguage
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
    public enum Defaults {
        public static let topK: Int = 5
        public static let minScore: Float = 0.35
        public static let initialScoreWeight: Float = 0.7
        public static let crossScoreWeight: Float = 0.3
    }

    public init() {}

    /// 执行两阶段重排序与噪点剪枝
    public func rerank(
        query: String,
        candidates: [(chunk: ContextRerankChunk, initialScore: Float)],
        topK: Int = Defaults.topK,
        minScore: Float = Defaults.minScore
    ) -> [RerankedResult] {
        guard topK > 0, minScore.isFinite else { return [] }
        let queryTokens = Self.tokenize(query)

        let reranked = candidates.compactMap { candidate -> RerankedResult? in
            guard candidate.initialScore.isFinite else { return nil }
            let chunkTokens = Self.tokenize(candidate.chunk.content)
            let overlap = Float(queryTokens.intersection(chunkTokens).count)
            let crossScore = queryTokens.isEmpty ? 0.0 : (overlap / Float(queryTokens.count))

            let finalScore = candidate.initialScore * Defaults.initialScoreWeight + crossScore * Defaults.crossScoreWeight
            guard finalScore.isFinite, finalScore >= minScore else { return nil }

            return RerankedResult(chunk: candidate.chunk, score: finalScore)
        }

        return Array(reranked.sorted(by: { $0.score > $1.score }).prefix(topK))
    }

    /// 基于 NaturalLanguage 分词器提取中英文混合词元并剥离标点空白，解决 CJK 无空格文本及标点黏连分词失效问题
    internal static func tokenize(_ text: String) -> Set<String> {
        let normalized = text.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = normalized

        var tokens = Set<String>()
        tokenizer.enumerateTokens(in: normalized.startIndex..<normalized.endIndex) { range, _ in
            let token = String(normalized[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                tokens.insert(token)
            }
            return true
        }
        return tokens
    }
}
