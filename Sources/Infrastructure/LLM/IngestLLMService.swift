//
//  IngestLLMService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 IngestLLM 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore

/// 知识库摄入与重构基础设施服务
/// 遵循并实现 `LLMKnowledgeServiceProtocol` 契约，支持响应式参数配置。
@MainActor
public final class IngestLLMService: NSObject, LLMKnowledgeServiceProtocol, @unchecked Sendable {
    /// 配置管理器，热重载 API 参数
    @ObservationIgnored @Inject private var configManager: LLMConfigManager
    
    /// 初始化摄入服务
    public override init() {
        super.init()
    }
    
    /// 创建底层的 LLMIngestService 实例
    private func getIngestService() -> LLMIngestService? {
        guard configManager.isEnabled, !configManager.apiKey.isEmpty else { return nil }
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        return LLMIngestService(client: client, model: configManager.model, contextBuilder: LLMContextBuilder())
    }
    
    /// 创建底层的 LLMRefactorService 实例
    private func getRefactorService() -> LLMRefactorService? {
        guard configManager.isEnabled, !configManager.apiKey.isEmpty else { return nil }
        let client = LLMClient(baseURL: configManager.baseURL, apiKey: configManager.apiKey)
        return LLMRefactorService(client: client, model: configManager.model)
    }
    
    /// 智能数据提炼与分块导入
    ///
    /// - Parameters:
    ///   - title: 输入文档的建议标题
    ///   - rawContent: 输入文档的原始长文本
    ///   - pages: 知识库已有上下文
    /// - Returns: 包含提炼链接、标签等的结构化结果
    /// - Throws: 未配置或推理失败异常
    public func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        guard let service = getIngestService() else {
            throw LLMError.notConfigured
        }
        return try await service.smartIngest(title: title, rawContent: rawContent, pages: pages)
    }
    
    /// 智能链接推荐：分析文档发现潜在的双向链接项
    ///
    /// - Parameters:
    ///   - content: 待扫描页面正文
    ///   - existingTitles: 已有标题候选池
    /// - Returns: 推荐生成关联的链接标题列表
    /// - Throws: 推理失败异常
    public func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        guard let service = getRefactorService() else { return [] }
        return try await service.discoverPotentialLinks(content: content, existingTitles: existingTitles)
    }
    
    /// 知识融合：增量重构两个存在重合内容的文档
    ///
    /// - Parameters:
    ///   - existingContent: 页面现有正文
    ///   - newContent: 追加新正文
    ///   - title: 页面标题
    /// - Returns: 重构后的 Markdown 文本
    /// - Throws: 推理失败异常
    public func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        guard let service = getRefactorService() else {
            return existingContent + "\n\n" + newContent
        }
        return try await service.foldContent(existingContent: existingContent, newContent: newContent, title: title)
    }
    
    /// 架构诊断：遍历分析笔记本所有页面并产出合并重构建议
    ///
    /// - Parameter pages: 笔记本中的页面列表
    /// - Returns: 重构建议列表
    /// - Throws: 推理失败异常
    public func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] {
        guard let service = getRefactorService() else { return [] }
        return try await service.analyzeForRefactoring(pages: pages)
    }
}
