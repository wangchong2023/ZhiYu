//
//  LLMIngestService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 LLMIngest 模块的核心业务逻辑服务。
//
import Foundation

/// LLM 智能摄入服务
/// 负责对新摄入的原始文本进行语义分析，并提取结构化知识元数据。
final class LLMIngestService: Sendable {
    private let client: any LLMClientProtocol
    private let model: String
    private let contextBuilder: LLMContextBuilder

    init(client: any LLMClientProtocol, model: String, contextBuilder: LLMContextBuilder) {
        self.client = client
        self.model = model
        self.contextBuilder = contextBuilder
    }

    // MARK: - 智能摄入 (Smart Ingest)

    /// 对原始内容进行智能编译，提取摘要、标签、关联建议等
    func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        let prompt = contextBuilder.buildIngestPrompt(title: title, rawContent: rawContent, pages: pages)
        let body: [String: Any] = [
            LLMConstants.APIKey.model: model,
            LLMConstants.APIKey.messages: [[LLMConstants.APIKey.role: LLMConstants.Role.user, LLMConstants.APIKey.content: prompt]],
            LLMConstants.APIKey.temperature: 0.4
        ]

        let response = try await client.sendRequest(body: body)
        let content = LLMUtils.extractContent(from: response) ?? ""
        if var result = LLMUtils.parseSmartIngest(content) {
            // 如果返回的 JSON 中 title 为空，则使用传入的默认标题
            if result.title == nil || result.title?.isEmpty == true {
                result = SmartIngestResultDTO(
                    title: title,
                    compiledContent: result.compiledContent,
                    suggestedTags: result.suggestedTags,
                    suggestedType: result.suggestedType,
                    relatedTitles: result.relatedTitles,
                    summary: result.summary
                )
            }
            return result
        }
        throw LLMError.invalidResponse
    }
}
