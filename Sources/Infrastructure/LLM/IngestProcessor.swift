//
//  IngestProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：承载知识库内容的语义摄入、实体提炼、双链自动挖掘与折叠重构。
//

import Foundation
import UFPCore
import Combine
import Dependencies

/// 大语言模型知识处理服务 (IngestProcessor)
/// 实现 LLMKnowledgeServiceProtocol，负责结构化导入、关系发现与内容整理。
@MainActor
final class IngestProcessor: LLMKnowledgeServiceProtocol {
    
    // MARK: - 依赖注入
    
    @ObservationIgnored @Dependency(\.llmConfigManager) private var configManager: LLMConfigManager
    
    // MARK: - 内部属性
    
    private let contextBuilder = LLMContextBuilder()
    
    /// 智能摄入子服务
    private var ingestService: LLMIngestService?
    
    /// 文档重构子服务
    private var refactorService: LLMRefactorService?
    
    // MARK: - 初始化
    
    init() {
        updateSubServices()
        
        configManager.setRefreshHandler { [weak self] in
            self?.updateSubServices()
        }
    }
    
    private func updateSubServices() {
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        self.ingestService = LLMIngestService(client: client, model: configManager.model, contextBuilder: contextBuilder)
        self.refactorService = LLMRefactorService(client: client, model: configManager.model)
    }

    // MARK: - LLMKnowledgeServiceProtocol 契约方法

    /// 智能语义分析、分块并提取核心实体导入到知识库
    func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        guard configManager.isReady else { throw LLMError.notConfigured }
        guard let ingestService = self.ingestService else { throw LLMError.notConfigured }
        let sanitizedText = DocumentSanitationEngine.shared.sanitize(rawContent)
        return try await ingestService.smartIngest(title: title, rawContent: sanitizedText, pages: pages)
    }

    /// 根据当前正文分析并发现可能存在双向关联的已有页面标题
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        guard configManager.isReady else { return [] }
        guard let refactorService = self.refactorService else { return [] }
        return try await refactorService.discoverPotentialLinks(content: content, existingTitles: existingTitles)
    }

    /// 将重叠的或新旧内容进行语义合并，保留最大化有效信息
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        guard configManager.isReady else { return existingContent + "\n\n" + newContent }
        guard let refactorService = self.refactorService else { return existingContent + "\n\n" + newContent }
        return try await refactorService.foldContent(existingContent: existingContent, newContent: newContent, title: title)
    }

    /// 对整个知识库的实体分布与内容进行体检，提供合理的归纳、重构与合并建议
    func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] {
        guard configManager.isReady else { return [] }
        guard let refactorService = self.refactorService else { return [] }
        return try await refactorService.analyzeForRefactoring(pages: pages)
    }
}
