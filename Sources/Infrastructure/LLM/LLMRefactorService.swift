//
//  LLMRefactorService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 LLMRefactor 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore

/// LLM 知识重构服务
/// 负责扫描知识库内容，通过语义分析建立双向链接并建议页面合并或拆分。
public final class LLMRefactorService: Sendable {
    private let client: any LLMClientProtocol
    private let model: String

    init(client: any LLMClientProtocol, model: String) {
        self.client = client
        self.model = model
    }

    // MARK: - 链接发现 (Link Discovery)

    /// 扫描文本以发现潜在的内部链接建议
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        let prompt = """
        \(PromptService.shared.potentialLinksPrompt)

        
        \(existingTitles.joined(separator: ", "))

        
        \"\"\"
        \(content)
        \"\"\"
        """

        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [[LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]],
            LLMConstants.APIKey.temperature: 0.1,
            LLMConstants.APIKey.maxTokens: 500
        ]

        let response = try await client.sendRequest(body: body)
        let responseContent = LLMUtils.extractContent(from: response) ?? ""
        return LLMUtils.parseJSONArray(responseContent)
    }

    // MARK: - 智能折叠 (Smart Folding)

    /// 增量折叠：将新资料合并至现有页面，避免重复
    func foldContent(existingContent: String, newContent: String, title _: String) async throws -> String {
        let prompt = """
        \(PromptService.shared.foldingPrompt)

        
        \(existingContent)

        
        \(newContent)
        """

        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [[LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]],
            LLMConstants.APIKey.temperature: 0.2,
            LLMConstants.APIKey.maxTokens: 2000
        ]

        let response = try await client.sendRequest(body: body)
        let folded = LLMUtils.extractContent(from: response) ?? ""
        return folded.isEmpty ? (existingContent + "\n\n" + newContent) : folded
    }

    // MARK: - 架构重构建议

    /// 分析一组页面以获取重构建议（合并、拆分、重命名）
    func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestion] {
        let pageData = pages.map { "\($0.title): \($0.content.prefix(LLMConstants.LogPreview.refactorPageContentLength))..." }.joined(separator: "\n---\n")

        let prompt = """
        \(PromptService.shared.refactorPrompt)

        
        \(pageData)
        """

        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [[LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]],
            LLMConstants.APIKey.temperature: AppConfig.AI.defaultTemperature,
            LLMConstants.APIKey.maxTokens: 1000
        ]

        let response = try await client.sendRequest(body: body)
        let responseContent = LLMUtils.extractContent(from: response) ?? ""
        return LLMUtils.parseRefactorSuggestions(responseContent)
    }
}

// MARK: - 辅助模型

/// 重构建议模型 (对齐 DTO)
public typealias RefactorSuggestion = RefactorSuggestionDTO
