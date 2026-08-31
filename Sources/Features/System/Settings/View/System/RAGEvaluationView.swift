//
//  RAGEvaluationView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：RAG 质量评估容器视图 — 组合基准测试 / 结果图表 / 配置表单三个子面板。
//

import SwiftUI
import UFPCore

// MARK: - 主视图

@MainActor
struct RAGEvaluationView: View {
    /// 使用手动可选解析替代 @Inject，避免测试环境 teardown 后 async task 回调时
    /// ServiceContainer 已被 reset() 导致 assertionFailure（SIGTRAP 崩溃）
    private var governance: (any RAGGovernanceRepository)? {
        // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
        ServiceContainer.shared.resolveOptional((any RAGGovernanceRepository).self)
    }

    // 生成质量（七维）
    @State private var avgScores = AverageRAGScores(
        faithfulness: 0, relevance: 0, precision: 0, hallucinationRate: 0,
        citationAccuracy: 0, answerCorrectness: 0, contextSufficiency: 0
    )
    // 检索 — 排名
    @State private var hitRate: Double = 0
    @State private var mrr: Double = 0
    @State private var ndcg: Double = 0
    // 检索 — 覆盖
    @State private var recall: Double = 0
    @State private var f1Score: Double = 0
    @State private var mapScore: Double = 0
    // 性能
    @State private var latency = LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0)
    // 成本
    @State private var tokenEfficiency = TokenEfficiency(totalTokens: 0, queryCount: 0, avgTokensPerQuery: 0, estimatedCostUSD: 0)
    // 满意度
    @State private var satisfactionRate: Double = 0
    @State private var satisfactionThumbsUp: Int = 0
    @State private var satisfactionThumbsDown: Int = 0
    // 历史
    @State private var recentEvaluations: [RAGEvaluation] = []
    @State private var selectedDays = FeatureConstants.RAGEvaluation.defaultSelectedDays
    @State private var isLoading = true
    @State private var activeTooltip: String?
    @State private var selectedTab: EvalTab = .retrieval

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.wide) {
                        RAGTimeRangePicker(selectedDays: $selectedDays)

                        Picker("", selection: $selectedTab) {
                            ForEach(EvalTab.allCases) { tab in
                                Text(tab.title).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, DesignSystem.small)

                        switch selectedTab {
                        case .retrieval:
                            RAGRetrievalPanel(
                                avgScores: avgScores,
                                hitRate: hitRate, mrr: mrr, ndcg: ndcg,
                                recall: recall, f1Score: f1Score, mapScore: mapScore,
                                latency: latency,
                                activeTooltip: $activeTooltip
                            )
                        case .generation:
                            RAGGenerationPanel(
                                avgScores: avgScores,
                                activeTooltip: $activeTooltip
                            )
                        case .evaluation:
                            RAGSatisfactionPanel(
                                satisfactionRate: satisfactionRate,
                                satisfactionThumbsUp: satisfactionThumbsUp,
                                satisfactionThumbsDown: satisfactionThumbsDown
                            )
                            RAGCostPanel(tokenEfficiency: tokenEfficiency)
                            if let governance {
                                RAGEvaluationHistoryPanel(
                                    recentEvaluations: recentEvaluations,
                                    governance: governance,
                                    onReload: { await loadData() }
                                )
                            }
                        }
                    }
                    .padding(DesignSystem.standardPadding)
                }
            }
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .navigationTitle(L10n.Dashboard.stats.benchmark)
        .task { await loadData() }
        .onChange(of: selectedDays) { _, _ in Task { await loadData() } }
    }

    // MARK: - 数据加载

    private func loadData() async {
        guard let governance = governance else {
            isLoading = false
            return
        }
        isLoading = true
        let hitK = AppConfig.AI.evaluationHitK
        let ndcgK = AppConfig.AI.evaluationNDCGK
        let recallK = AppConfig.AI.evaluationRecallK

        do {
            async let scores = governance.calculateAverageRAGScores(days: selectedDays)
            async let evals = governance.fetchRAGEvaluations(limit: EvalDisplay.fetchLimit)
            async let hr = governance.calculateHitRate(days: selectedDays, k: hitK)
            async let meanRR = governance.calculateMRR(days: selectedDays)
            async let n = governance.calculateNDCG(days: selectedDays, k: ndcgK)
            async let rec = governance.calculateRecall(days: selectedDays, k: recallK)
            async let f1 = governance.calculateF1Score(days: selectedDays, k: recallK)
            async let map = governance.calculateMAP(days: selectedDays)
            async let lat = governance.calculateRetrievalLatency(days: selectedDays)
            async let tokEff = governance.calculateTokenEfficiency(days: selectedDays)

            avgScores = try await scores
            let evaluationList = try await evals
            recentEvaluations = evaluationList
            hitRate = (try? await hr) ?? 0
            mrr = (try? await meanRR) ?? 0
            ndcg = (try? await n) ?? 0
            recall = (try? await rec) ?? 0
            f1Score = (try? await f1) ?? 0
            mapScore = (try? await map) ?? 0
            latency = (try? await lat) ?? LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0)
            tokenEfficiency = (try? await tokEff) ?? TokenEfficiency(totalTokens: 0, queryCount: 0, avgTokensPerQuery: 0, estimatedCostUSD: 0)

            // 满意度统计
            let rated = evaluationList.filter { $0.userRating != nil }
            satisfactionThumbsUp = rated.filter { $0.userRating == UserRating.thumbsUp }.count
            satisfactionThumbsDown = rated.filter { $0.userRating == UserRating.thumbsDown }.count
            let total = satisfactionThumbsUp + satisfactionThumbsDown
            satisfactionRate = total > 0 ? Double(satisfactionThumbsUp) / Double(total) : 0
        } catch {
            Logger.shared.error("[RAG] Evaluation load failed", error: error)
        }
        isLoading = false
    }
}
