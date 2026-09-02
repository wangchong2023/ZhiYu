//
//  AIAnalyticsService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 AIAnalytics 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies

/// AI 指标分析服务 (L1-Infra)
public final class AIAnalyticsService: Sendable {
    @Dependency(\.ragGovernanceRepository) private var governance: any RAGGovernanceRepository
    @Dependency(\.ragEvaluationService) private var evalService: RAGEvaluationService

    public init() {}

    /// 记录单次 LLM 调用指标
    public func recordUsage(model: String, response: [String: Any], latency: Int) {
        // 单测环境下禁用后台异步指标写入，以防重置 DI 容器导致的崩溃
        guard !TestModeDetector.isUnitTesting else { return }

        guard let usage = response["usage"] as? [String: Any],
              let prompt = usage["prompt_tokens"] as? Int,
              let completion = usage["completion_tokens"] as? Int else { return }

        let governance = self.governance
        Task.detached(priority: .background) {
            _ = try? await governance.logCall(model: model, promptTokens: prompt, completionTokens: completion, latencyMS: latency, status: AppConstants.Storage.defaultCallStatus)
            _ = try? await governance.logTokenUsage(model: model, promptTokens: prompt, completionTokens: completion)
        }
    }

    /// 执行 RAG 性能指标异步计算与评估（含检索源标注）
    /// - Parameter sources: 检索到的信源列表，传入时触发 Hit Rate/MRR/NDCG 数据记录
    public func recordRAGMetrics(
        query: String,
        response: String,
        context: String,
        sources: [KnowledgeSource]? = nil,
        systemPrompt: String,
        modelName: String,
        latency: Int
    ) {
        // 单测环境下禁用后台异步指标写入，以防重置 DI 容器导致的崩溃
        guard !TestModeDetector.isUnitTesting else { return }

        let governance = self.governance
        let evalService = self.evalService
        Task.detached(priority: .background) {
            let charsPerToken = max(1, PromptConstants.TokenLimits.charactersPerToken)
            let promptTokens = (systemPrompt.count + query.count) / charsPerToken
            let completionTokens = response.count / charsPerToken

            _ = try? await governance.logCall(model: modelName, promptTokens: promptTokens, completionTokens: completionTokens, latencyMS: latency, status: AppConstants.Storage.defaultCallStatus)
            _ = try? await governance.logTokenUsage(model: modelName, promptTokens: promptTokens, completionTokens: completionTokens)
            _ = await evalService.evaluate(query: query, answer: response, context: context, sources: sources)
        }
    }
}

// MARK: - DependencyKey 注册

/// AIAnalyticsService 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum AIAnalyticsServiceKey: DependencyKey {
    public static var liveValue: AIAnalyticsService {
        ServiceContainer.shared.resolve(AIAnalyticsService.self)
    }

    public static var testValue: AIAnalyticsService {
        ServiceContainer.shared.resolveOptional(AIAnalyticsService.self) ?? AIAnalyticsService()
    }
    public static var previewValue: AIAnalyticsService { testValue }
}

extension DependencyValues {
    /// AI 指标分析服务依赖
    public var aiAnalyticsService: AIAnalyticsService {
        get { self[AIAnalyticsServiceKey.self] }
        set { self[AIAnalyticsServiceKey.self] = newValue }
    }
}
