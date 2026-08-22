//
//  RAGEvaluationService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：实现 RAGEvaluation 模块的核心业务逻辑服务。
//
import Foundation
import CryptoKit
import Dependencies
import UFPCore

/// RAG 质量评估报告模型
struct EvaluationReport: Identifiable {
    let id = UUID()
    let query: String
    let answer: String
    let faithfulness: Double       // 忠实度 (0-1)
    let relevance: Double          // 相关度 (0-1)
    let precision: Double          // 上下文精确度 (0-1)
    let hallucinationRate: Double  // 幻觉率 (0-1)，越低越好
    let citationAccuracy: Double   // 引用准确度 (0-1)，越高越好
    let status: String             // "Pass" | "Warning" | "Fail"
}

/// [L2] 领域服务：RAG 质量评估中心
final class RAGEvaluationService {
    private let llmService: any LLMServiceProtocol
    private let governanceStore: any RAGGovernanceRepository

    init(llmService: any LLMServiceProtocol, governanceStore: any RAGGovernanceRepository) {
        self.llmService = llmService
        self.governanceStore = governanceStore
    }

    /// 执行单次回答评估（含可选的检索源标注）
    /// - Parameters:
    ///   - query: 原始问题
    ///   - answer: AI 生成的回答
    ///   - context: 检索到的上下文片段（合并后）
    ///   - sources: 检索源列表（传入时触发检索快照记录 + 相关性标注）
    func evaluate(query: String, answer: String, context: String, sources: [KnowledgeSource]? = nil) async -> EvaluationReport {
        let prompt: String
        if let sources, !sources.isEmpty {
            prompt = Self.buildJudgePromptWithSources(context: context, query: query, answer: answer, sources: sources)
        } else {
            prompt = L10n.AI.Eval.judgePrompt(context, query, answer)
        }
        let systemPrompt = L10n.AI.Eval.systemPrompt

        do {
            let response = try await llmService.generate(prompt: prompt, systemPrompt: systemPrompt)
            if let report = await processEvaluationResponse(response, query: query, answer: answer, sources: sources) {
                return report
            }
        } catch {
            Logger.shared.error("Evaluation failed", error: error)
        }

        return EvaluationReport(
            query: query, answer: answer,
            faithfulness: 0, relevance: 0, precision: 0,
            hallucinationRate: 0, citationAccuracy: 0,
            status: L10n.AI.Eval.Status.error
        )
    }

    // MARK: - 检索质量记录

    /// 记录检索快照与 LLM 标注的相关性数据
    private func recordRetrievalQuality(
        evalID: Int64,
        query: String,
        sources: [KnowledgeSource],
        relevanceScoresJSON: [Int]?
    ) async {
        let queryHash = Self.sha256(query)

        // 1. 保存检索快照（Top-N 排序结果）
        let snapshots: [RetrievalSnapshot] = sources.enumerated().map { idx, src in
            RetrievalSnapshot(
                evaluationID: evalID,
                rank: idx + 1,
                sourceID: src.id.uuidString,
                pageTitle: src.title,
                snippet: String(src.snippet.prefix(RAGEvalConstants.snapshotSnippetPrefix)),
                score: src.score
            )
        }
        try? await governanceStore.saveRetrievalSnapshots(snapshots)

        // 2. 保存相关性标注（优先使用 LLM 返回的分数，回退到基于 score 的弱标注）
        let judgments: [RelevanceJudgment] = sources.enumerated().map { idx, src in
            let level: Int
            if let scores = relevanceScoresJSON, idx < scores.count {
                level = max(0, min(2, scores[idx]))
            } else {
                // 回退：基于相似度分数的启发式标注
                if src.score >= RAGEvalConstants.HeuristicRelevance.highThreshold { level = 2 } else if src.score >= RAGEvalConstants.HeuristicRelevance.mediumThreshold { level = 1 } else { level = 0 }
            }
            return RelevanceJudgment(
                queryHash: queryHash,
                query: query,
                sourceID: src.id.uuidString,
                relevanceLevel: level,
                judgeSource: relevanceScoresJSON != nil ? "llm-auto" : "heuristic",
                evaluationID: evalID
            )
        }
        try? await governanceStore.saveRelevanceJudgments(judgments)
    }

    // MARK: - 辅助

    /// 对查询文本执行 SHA-256 哈希，生成查询指纹用于关联去重。
    private static func sha256(_ text: String) -> String {
        let hash = CryptoKit.SHA256.hash(data: Data(text.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 构建含逐源相关性评判的 Prompt
    private static func buildJudgePromptWithSources(
        context: String,
        query: String,
        answer: String,
        sources: [KnowledgeSource]
    ) -> String {
        var sourceList = ""
        for (idx, src) in sources.prefix(RAGEvalConstants.JudgePrompt.maxSources).enumerated() {
            sourceList += "[\(idx)] \(src.title): \(String(src.snippet.prefix(RAGEvalConstants.JudgePrompt.sourceSnippetPrefix)))\n"
        }

        let displayCount = min(RAGEvalConstants.JudgePrompt.maxSources, sources.count)
        let truncatedContext = String(context.prefix(RAGEvalConstants.JudgePrompt.contextPrefix))
        return L10n.AI.Prompt.ragJudgePrompt(
            sourceList: sourceList,
            sourceCount: sources.count,
            displayCount: displayCount,
            context: truncatedContext,
            query: query,
            answer: answer
        )
    }

    /// 处理 LLM 评估 JSON 响应，解析六维评分并持久化到治理数据库。
    /// 流程：JSON 解析 → 评分提取 → 状态判定 → 持久化评估记录 → 检索快照标注。
    /// - Parameters:
    ///   - response: LLM 返回的 JSON 响应文本
    ///   - query: 原始查询
    ///   - answer: 生成的回答
    ///   - sources: 检索文档源列表（传入时触发检索质量记录）
    /// - Returns: 构造好的 EvaluationReport，解析失败返回 nil
    private func processEvaluationResponse(
        _ response: String,
        query: String,
        answer: String,
        sources: [KnowledgeSource]?
    ) async -> EvaluationReport? {
        // Step 1: JSON 解析 — 尝试从 LLM 响应中提取评分字段
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Step 2: 提取六维评分，缺失字段默认 0.0
        let faithfulnessScore = (json[EvaluationMetric.faithfulness.rawValue] as? Double) ?? 0.0
        let relevanceScore = (json[EvaluationMetric.relevance.rawValue] as? Double) ?? 0.0
        let precisionScore = (json[EvaluationMetric.precision.rawValue] as? Double) ?? 0.0
        let hallucinationRate = (json[EvaluationMetric.hallucinationRate.rawValue] as? Double) ?? 0.0
        let citationAccuracy = (json[EvaluationMetric.citationAccuracy.rawValue] as? Double) ?? 0.0

        // Step 3: 基于忠实度的三级状态判定
        let status: String
        if faithfulnessScore < RAGEvalConstants.FaithfulnessStatus.failThreshold {
            status = L10n.AI.Eval.Status.fail
        } else if faithfulnessScore < RAGEvalConstants.FaithfulnessStatus.warningThreshold {
            status = L10n.AI.Eval.Status.warning
        } else {
            status = L10n.AI.Eval.Status.pass
        }

        // Step 4: 持久化评估记录到治理数据库
        let eval = RAGEvaluation(
            query: query,
            answer: answer,
            faithfulness: faithfulnessScore,
            relevance: relevanceScore,
            precision: precisionScore,
            hallucinationRate: hallucinationRate,
            citationAccuracy: citationAccuracy,
            evaluatorModel: AppConfig.AI.evaluatorModel
        )
        try? await governanceStore.saveRAGEvaluation(eval)
        
        // Step 5: 查询最新评估记录获取自增 ID
        let savedEvals = (try? await governanceStore.fetchRAGEvaluations(limit: 1)) ?? []
        let savedEvalID = savedEvals.first.flatMap { $0.id }

        // Step 6: 检索快照 + 相关性标注（仅当有 sources 且有有效评估 ID 时）
        if let sources, let evalID = savedEvalID {
            await recordRetrievalQuality(
                evalID: evalID,
                query: query,
                sources: sources,
                relevanceScoresJSON: json["relevance_scores"] as? [Int]
            )
        }

        return EvaluationReport(
            query: query,
            answer: answer,
            faithfulness: faithfulnessScore,
            relevance: relevanceScore,
            precision: precisionScore,
            hallucinationRate: hallucinationRate,
            citationAccuracy: citationAccuracy,
            status: status
        )
    }
}

// MARK: - DependencyKey 注册

/// RAGEvaluationService 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum RAGEvaluationServiceKey: DependencyKey {
    static var liveValue: RAGEvaluationService {
        ServiceContainer.shared.resolve(RAGEvaluationService.self)
    }
    @MainActor
    static var testValue: RAGEvaluationService {
        ServiceContainer.shared.resolveOptional(RAGEvaluationService.self)
            ?? RAGEvaluationService(llmService: NoOpLLMService(), governanceStore: NoOpRAGGovernanceRepository())
    }
}

extension DependencyValues {
    /// RAG 评估服务依赖
    var ragEvaluationService: RAGEvaluationService {
        get { self[RAGEvaluationServiceKey.self] }
        set { self[RAGEvaluationServiceKey.self] = newValue }
    }
}
