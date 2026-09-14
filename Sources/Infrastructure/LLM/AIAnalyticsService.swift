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
public final class AIAnalyticsService: @unchecked Sendable {
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
            await AIAnalyticsService.logCallAndTokenUsage(
                governance: governance,
                model: model,
                promptTokens: prompt,
                completionTokens: completion,
                latency: latency
            )
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

            await AIAnalyticsService.logCallAndTokenUsage(
                governance: governance,
                model: modelName,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                latency: latency
            )
            _ = await evalService.evaluate(query: query, answer: response, context: context, sources: sources)
        }
    }

    /// 异步记录 LLM 调用与 Token 用量至治理仓储（容错吞错）
    /// - Parameters:
    ///   - governance: 治理仓储
    ///   - model: 模型名
    ///   - promptTokens: 输入 token 数
    ///   - completionTokens: 输出 token 数
    ///   - latency: 调用延迟（毫秒）
    private static func logCallAndTokenUsage(
        governance: any RAGGovernanceRepository,
        model: String,
        promptTokens: Int,
        completionTokens: Int,
        latency: Int
    ) async {
        _ = try? await governance.logCall(model: model, promptTokens: promptTokens, completionTokens: completionTokens, latencyMS: latency, status: AppConstants.Storage.defaultCallStatus)
        _ = try? await governance.logTokenUsage(model: model, promptTokens: promptTokens, completionTokens: completionTokens)
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
