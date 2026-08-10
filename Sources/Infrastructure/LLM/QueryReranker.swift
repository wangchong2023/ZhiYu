//
//  QueryReranker.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：执行基于语义改写、查询扩展以及多路召回重排的高性能 RAG 检索管线。
//

import Foundation
import UFPCore
import Combine

/// 大语言模型检索与重排服务 (QueryReranker)
/// 实现 LLMRetrievalServiceProtocol，负责对提问重写、扩展以及二次精排。
@MainActor
final class QueryReranker: LLMRetrievalServiceProtocol {
    
    // MARK: - 依赖注入
    
    @ObservationIgnored @Inject private var configManager: LLMConfigManager
    
    // MARK: - 内部属性
    
    private let contextBuilder = LLMContextBuilder()
    
    /// 底层检索与重排服务
    private var retrievalService: LLMRetrievalService?
    
    // MARK: - 初始化
    
    init() {
        updateSubServices()
        
        configManager.setRefreshHandler { [weak self] in
            self?.updateSubServices()
        }
    }
    
    private func updateSubServices() {
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        self.retrievalService = LLMRetrievalService(client: client, model: configManager.model, contextBuilder: contextBuilder)
    }
    
    // MARK: - LLMRetrievalServiceProtocol 契约方法
    
    /// 对原始查询进行语义重写，以便更契合向量空间检索
    func rewriteQuery(_ query: String) async -> String {
        guard configManager.isEnabled, !configManager.apiKey.isEmpty, let retrievalService = self.retrievalService else { return query }
        return await retrievalService.rewriteQuery(query)
    }
    
    /// 对检索词进行多维度同义扩展，生成多个扩展查询语句提升召回率
    func expandQuery(_ query: String) async -> [String] {
        guard configManager.isEnabled, !configManager.apiKey.isEmpty, let retrievalService = self.retrievalService else { return [query] }
        return await retrievalService.expandQuery(query)
    }
    
    /// 对初次召回的知识页面候选集进行二次精排重排列
    func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] {
        guard configManager.isEnabled, !configManager.apiKey.isEmpty, let retrievalService = self.retrievalService else { return candidates }
        return try await retrievalService.rerank(query: query, candidates: candidates)
    }
    
    /// 对颗粒度更细的 PageChunk 进行重排，筛选出最优质的前 N 个 Chunks
    func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] {
        guard configManager.isEnabled, !configManager.apiKey.isEmpty, let retrievalService = self.retrievalService else { return chunks }
        return await retrievalService.rerankChunks(query: query, chunks: chunks)
    }
    
    /// 预生成当前提问的假想文档 (HyDE) 提高向量召回率
    func generateHypotheticalDocument(query: String) async -> String {
        guard configManager.isEnabled, !configManager.apiKey.isEmpty, let retrievalService = self.retrievalService else { return query }
        return await retrievalService.generateHypotheticalDocument(query: query)
    }
}
