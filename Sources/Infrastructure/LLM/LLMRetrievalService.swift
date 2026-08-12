//
//  LLMRetrievalService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 LLMRetrieval 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies

/// LLM 检索增强服务
/// 负责对原始查询进行优化，并对初步召回的结果执行语义精排。
final class LLMRetrievalService: Sendable {
    private let client: any LLMClientProtocol
    private let model: String
    private let contextBuilder: LLMContextBuilder
    @ObservationIgnored private let promptService: PromptService

    init(client: any LLMClientProtocol, model: String, contextBuilder: LLMContextBuilder, promptService: PromptService? = nil) {
        self.client = client
        self.model = model
        self.contextBuilder = contextBuilder
        self.promptService = promptService ?? PromptService(defaults: .standard)
    }

    // MARK: - 查询优化 (Query Optimization)

    /// 将原始自然语言问题改写为更适合检索的格式
    func rewriteQuery(_ query: String) async -> String {
        let prompt = contextBuilder.buildRewritePrompt(query: query)
        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [[LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]],
            LLMConstants.APIKey.temperature: 0.3
        ]
        
        do {
            let response = try await client.sendRequest(body: body)
            let content = LLMUtils.extractContent(from: response)
            return (content.flatMap { $0.isEmpty ? nil : $0 }) ?? query
        } catch {
            return query
        }
    }

    /// 对查询进行意图扩展，生成多个变体以提升召回率
    func expandQuery(_ query: String) async -> [String] {
        let prompt = "\(promptService.queryExpansionPrompt)\n\nOriginal Query: \(query)"
        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [
                [LLMConstants.APIKey.role: LLMConstants.Role.system, LLMConstants.APIKey.content: "Return JSON array of strings only."],
                [LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]
            ],
            LLMConstants.APIKey.temperature: 0.5
        ]
        
        do {
            let response = try await client.sendRequest(body: body)
            let content = LLMUtils.extractContent(from: response) ?? ""
            let variations = LLMUtils.parseJSONArray(content)
            return variations.isEmpty ? [query] : variations
        } catch {
            return [query]
        }
    }

    // MARK: - 重排 (Rerank)

    /// 对候选页面列表执行语义重排
    func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] {
        guard !candidates.isEmpty else { return candidates }

        let titles = candidates.map { "\($0.title) (ID: \($0.id))" }.joined(separator: "\n")
        let prompt = promptService.rerankPrompt + "\n\nQuery: \(query)\n\nCandidates:\n\(titles)"
        
        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [[LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]],
            LLMConstants.APIKey.temperature: 0.2
        ]

        let response = try await client.sendRequest(body: body)
        let content = LLMUtils.extractContent(from: response) ?? ""
        let rankedIDs = LLMUtils.parseJSONArray(content)

        // 根据 LLM 返回的优先级顺序重新排序
        var result = candidates
        result.sort { a, b in
            let idxA = rankedIDs.firstIndex(of: a.id.uuidString) ?? 999
            let idxB = rankedIDs.firstIndex(of: b.id.uuidString) ?? 999
            return idxA < idxB
        }
        return result
    }

    /// 对文本分块执行 Rerank
    func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] {
        guard !chunks.isEmpty else { return chunks }

        let candidates = chunks.prefix(LLMConstants.Rerank.candidateCount)
        let context = candidates.enumerated().map { "[\($0)] \($1.content)" }.joined(separator: "\n\n")

        let prompt = L10n.AI.Prompt.rerankUserPrompt(query: query, context: context)

        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [
                [LLMConstants.APIKey.role: LLMConstants.Role.system, LLMConstants.APIKey.content: L10n.AI.Prompt.rerankSystem],
                [LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]
            ],
            LLMConstants.APIKey.temperature: 0.1
        ]

        do {
            let response = try await client.sendRequest(body: body)
            let content = LLMUtils.extractContent(from: response) ?? ""
            let rankedIndices = LLMUtils.parseJSONArray(content).compactMap { Int($0) }

            var result: [PageChunk] = []
            for index in rankedIndices where index < candidates.count {
                result.append(candidates[index])
            }

            // 补全未被排序选中的块
            let resultIDs = Set(result.map { $0.id })
            for chunk in chunks where !resultIDs.contains(chunk.id) {
                result.append(chunk)
            }

            return result
        } catch {
            return chunks
        }
    }

    // MARK: - 辅助文档生成

    /// 生成假设性回答文档 (HyDE 策略)
    /// - Parameter query: 原始查询文本
    /// - Returns: AI 生成的假设性答案，若失败则退化返回原始查询
    func generateHypotheticalDocument(query: String) async -> String {
        let prompt = L10n.AI.Prompt.hydeUserPrompt(query: query)
        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [
                [LLMConstants.APIKey.role: LLMConstants.Role.system, LLMConstants.APIKey.content: L10n.AI.Prompt.hydeSystem],
                [LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]
            ],
            LLMConstants.APIKey.temperature: 0.7
        ]
        
        do {
            let response = try await client.sendRequest(body: body)
            let content = LLMUtils.extractContent(from: response)
            return (content.flatMap { $0.isEmpty ? nil : $0 }) ?? query
        } catch {
            return query
        }
    }
}
