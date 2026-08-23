//
//  RAGBenchmarkPanel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：RAG 基准测试面板 — 检索质量卡片 / 生成质量环形图 / 延迟指标 / 评估记录详情。
//

import SwiftUI

// MARK: - 评分颜色阈值

enum ScoreThreshold {
    static let excellent: Double = 0.8
    static let fair: Double = 0.6
    static let invertedExcellent: Double = 0.2
    static let invertedFair: Double = 0.4
}

enum LatencyThreshold {
    static let low: Int = 500
    static let medium: Int = 2000
}

enum CostThreshold {
    static let low: Double = 0.50
}

// MARK: - 显示参数

enum EvalDisplay {
    static let queryPreviewChars: Int = 50
    static let fetchLimit: Int = 50
    static let displayLimit: Int = 20
    static let hallucinationPenaltyWeight: Double = 0.3
    /// 综合评分中正向指标的数量（faithfulness + relevance + precision + citation + correctness + contextSufficiency）
    static let positiveMetricCount: Double = 6.0
}

// MARK: - 用户评分常量

enum UserRating {
    static let thumbsDown = 1
    static let thumbsUp = 2
}

enum EvalTab: Int, CaseIterable, Identifiable {
    case retrieval
    case generation
    case evaluation

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .retrieval: return L10n.Dashboard.stats.tabRetrieval
        case .generation: return L10n.Dashboard.stats.tabGeneration
        case .evaluation: return L10n.Dashboard.stats.tabSatisfactionAndEval
        }
    }
}

// MARK: - SF Symbol 图标名

enum RatingIcon {
    static let thumbsUp = "hand.thumbsup.fill"
    static let thumbsDown = "hand.thumbsdown.fill"
}

enum RingStyle {
    static let size: CGFloat = 64
    static let lineWidth: CGFloat = 5
    static let backgroundOpacity: Double = 0.15
    static let rotationDegrees: Double = -90
}

enum CardVisual {
    static let metricBgOpacity: Double = 0.06
    static let tokenBgOpacity: Double = 0.04
    static let percentAuxOpacity: Double = 0.70
}

enum TagVisual {
    static let horizontalPadding: CGFloat = 4
    static let verticalPadding: CGFloat = 1
    static let cornerRadius: CGFloat = 3
}

enum TooltipVisual {
    static let iconHitTarget: CGFloat = 24
}

// MARK: - 标签缩写

enum MetricTag {
    static let faithfulness = "F"
    static let relevance = "R"
    static let hallucination = "H"
    static let citation = "C"
    static let correctness = "A"
    static let contextSufficiency = "S"
}

enum FontSize {
    static let metricValue: CGFloat = 22
    static let tokenValue: CGFloat = 18
    static let ringPercent: CGFloat = 14
    static let tag: CGFloat = 10
    static let detail: CGFloat = 9
    static let ringPercentSign: CGFloat = 8
}

enum FormatPattern {
    static let percentInt = "%.0f"
    static let score2 = "%.2f"
    static let score1 = "%.1f"
    static let costUSD = "$%.4f"
    static let tokenAvg = "%.0f"
}

enum MetricTitle {
    static func hitRate(_ k: Int) -> String { "Hit@\(k)" }
    static func ndcg(_ k: Int) -> String { "NDCG@\(k)" }
}

// MARK: - 🔍 检索阶段面板

/// 检索质量基准面板：排名指标 + 覆盖率 + 保真度 + 延迟
struct RAGRetrievalPanel: View {
    let avgScores: AverageRAGScores
    let hitRate: Double
    let mrr: Double
    let ndcg: Double
    let recall: Double
    let f1Score: Double
    let mapScore: Double
    let latency: LatencyPercentiles
    @Binding var activeTooltip: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            infoSectionHeader(id: "retrievalPhase", title: L10n.Dashboard.stats.retrievalQuality,
                              icon: "magnifyingglass.circle.fill", color: .teal, tip: L10n.Dashboard.stats.tipRetrievalPhase)

            subSectionLabel(L10n.Dashboard.stats.rankingQuality, icon: "list.number")
            HStack(spacing: DesignSystem.medium) {
                retrievalMetricCard(id: "hitRate", title: MetricTitle.hitRate(AppConfig.AI.evaluationHitK),
                                    score: hitRate, detail: L10n.Dashboard.stats.hitRateDesc, tip: L10n.Dashboard.stats.tipHitRate)
                retrievalMetricCard(id: "mrr", title: L10n.Dashboard.stats.mrrTitle,
                                    score: mrr, detail: L10n.Dashboard.stats.mrrDesc, tip: L10n.Dashboard.stats.tipMRR)
                retrievalMetricCard(id: "ndcg", title: MetricTitle.ndcg(AppConfig.AI.evaluationNDCGK),
                                    score: ndcg, detail: L10n.Dashboard.stats.ndcgDesc, tip: L10n.Dashboard.stats.tipNDCG)
            }

            subSectionLabel(L10n.Dashboard.stats.coverage, icon: "chart.pie.fill")
            HStack(spacing: DesignSystem.medium) {
                retrievalMetricCard(id: "recall", title: L10n.Dashboard.stats.recallAtK,
                                    score: recall, detail: L10n.Dashboard.stats.recallDesc, tip: L10n.Dashboard.stats.tipRecall)
                retrievalMetricCard(id: "f1", title: L10n.Dashboard.stats.f1AtK,
                                    score: f1Score, detail: L10n.Dashboard.stats.f1Desc, tip: L10n.Dashboard.stats.tipF1)
                retrievalMetricCard(id: "map", title: L10n.Dashboard.stats.mapTitle,
                                    score: mapScore, detail: L10n.Dashboard.stats.mapDesc, tip: L10n.Dashboard.stats.tipMAP)
            }

            subSectionLabel(L10n.Dashboard.stats.contextFidelity, icon: "scope")
            HStack(spacing: DesignSystem.medium) {
                scoreCardMedium(id: "precision", title: L10n.Dashboard.stats.precision,
                                score: avgScores.precision, tip: L10n.Dashboard.stats.tipPrecision)
                scoreCardMedium(id: "citation", title: L10n.Dashboard.stats.citationAccuracy,
                                score: avgScores.citationAccuracy, tip: L10n.Dashboard.stats.tipCitation)
                Color.clear.frame(maxWidth: .infinity)
            }

            subSectionLabel(L10n.Dashboard.stats.responseLatency, icon: "stopwatch")
            latencyGrid
        }
        .appCardStyle()
    }

    private var latencyGrid: some View {
        VStack(spacing: DesignSystem.small) {
            HStack(spacing: DesignSystem.medium) {
                latencyCard(id: "latencyP50", label: L10n.Dashboard.stats.latencyP50, value: latency.p50)
                latencyCard(id: "latencyP95", label: L10n.Dashboard.stats.latencyP95, value: latency.p95)
                latencyCard(id: "latencyP99", label: L10n.Dashboard.stats.latencyP99, value: latency.p99)
            }
            HStack {
                Spacer()
                Text("\(latency.sampleCount) \(L10n.Dashboard.stats.latencySampleCount)")
                    .font(.caption2).foregroundStyle(.tertiary)
                infoIcon(id: "latency", tip: L10n.Dashboard.stats.tipLatency)
            }
        }
    }

    // MARK: - 通用子视图

    private func infoSectionHeader(id: String, title: String, icon: String, color: Color, tip: String) -> some View {
        HStack(spacing: DesignSystem.small) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
            infoIcon(id: id, tip: tip)
        }
    }

    private func subSectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    // MARK: - Tooltip

    func infoIcon(id: String, tip: String) -> some View {
        let binding = Binding(
            get: { activeTooltip == id },
            set: { activeTooltip = $0 ? id : nil }
        )
        return Button(action: {
            HapticFeedback.shared.trigger(.selection)
            activeTooltip = (activeTooltip == id) ? nil : id
        }) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle((activeTooltip == id) ? .appAccent : .appSecondary.opacity(DesignSystem.Opacity.soft))
                .frame(width: TooltipVisual.iconHitTarget, height: TooltipVisual.iconHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: binding, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
            Text(tip)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
                .padding(.horizontal, DesignSystem.medium)
                .padding(.vertical, DesignSystem.small)
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - 环形百分比卡片

    func scoreCard(id: String, title: String, score: Double, icon _: String,
                   inverted: Bool = false, tip: String) -> some View {
        let color = inverted ? invertedScoreColor(score) : scoreColor(score)
        return VStack(spacing: DesignSystem.tightPadding) {
            ZStack {
                Circle().stroke(color.opacity(RingStyle.backgroundOpacity), lineWidth: RingStyle.lineWidth)
                    .frame(width: RingStyle.size, height: RingStyle.size)
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: RingStyle.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(RingStyle.rotationDegrees))
                    .frame(width: RingStyle.size, height: RingStyle.size)
                    .animation(.easeInOut(duration: 0.8), value: score)
                VStack(spacing: 0) {
                    Text(String(format: FormatPattern.percentInt, score * 100))
                        .font(.system(size: FontSize.ringPercent, weight: .bold, design: .rounded)).foregroundStyle(color)
                    Text("%").font(.system(size: FontSize.ringPercentSign, weight: .medium))
                        .foregroundStyle(color.opacity(CardVisual.percentAuxOpacity))
                }
            }
            HStack(spacing: SystemSpacing.atomic) {
                Text(title).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2)
                infoIcon(id: id, tip: tip)
            }
            Text(String(format: FormatPattern.score2, score)).font(.caption2.monospaced()).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 无环形图的中型评分卡片（用于检索保真区）
    func scoreCardMedium(id: String, title: String, score: Double, tip: String) -> some View {
        let color = scoreColor(score)
        return VStack(spacing: DesignSystem.tightPadding) {
            HStack(spacing: SystemSpacing.atomic) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                infoIcon(id: id, tip: tip)
            }
            Text(String(format: FormatPattern.score2, score))
                .font(.system(size: FontSize.metricValue, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, DesignSystem.small)
        .background(color.opacity(CardVisual.metricBgOpacity))
        .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
    }

    // MARK: - 检索指标卡片

    private func retrievalMetricCard(id: String, title: String, score: Double, detail: String, tip: String) -> some View {
        let color = scoreColor(score)
        return VStack(spacing: DesignSystem.tightPadding) {
            HStack(spacing: SystemSpacing.atomic) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                infoIcon(id: id, tip: tip)
            }
            Text(String(format: FormatPattern.score2, score))
                .font(.system(size: FontSize.metricValue, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(detail).font(.system(size: FontSize.detail)).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, DesignSystem.small)
        .background(color.opacity(CardVisual.metricBgOpacity))
        .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
    }

    private func latencyCard(id: String, label: String, value: Int) -> some View {
        let color = latencyColor(value)
        return VStack(spacing: DesignSystem.tightPadding) {
            HStack(spacing: SystemSpacing.atomic) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                infoIcon(id: id, tip: L10n.Dashboard.stats.tipLatency)
            }
            HStack(alignment: .bottom, spacing: SystemSpacing.atomic) {
                Text("\(value)").font(.system(size: FontSize.metricValue, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(L10n.Dashboard.stats.latencyUnitMS).font(.system(size: FontSize.tag, weight: .medium)).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, DesignSystem.small)
        .background(color.opacity(CardVisual.metricBgOpacity)).clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
    }

    // MARK: - 评分与颜色

    func scoreColor(_ s: Double) -> Color {
        if s >= ScoreThreshold.excellent { return .green }
        if s >= ScoreThreshold.fair { return .orange }
        return .red
    }

    func invertedScoreColor(_ s: Double) -> Color {
        if s <= ScoreThreshold.invertedExcellent { return .green }
        if s <= ScoreThreshold.invertedFair { return .orange }
        return .red
    }

    func latencyColor(_ ms: Int) -> Color {
        if ms < LatencyThreshold.low { return .green }
        if ms < LatencyThreshold.medium { return .orange }
        return .red
    }
}

// MARK: - ✍️ 生成阶段面板

/// 生成质量面板：faithfulness / relevance / hallucination / correctness / contextSufficiency 环形评分卡
struct RAGGenerationPanel: View {
    let avgScores: AverageRAGScores
    @Binding var activeTooltip: String?

    var body: some View {
        let benchmark = RAGRetrievalPanel(
            avgScores: avgScores,
            hitRate: 0, mrr: 0, ndcg: 0, recall: 0, f1Score: 0, mapScore: 0,
            latency: LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0),
            activeTooltip: $activeTooltip
        )
        return VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: DesignSystem.small) {
                Label(L10n.Dashboard.stats.generationQuality, systemImage: "text.bubble.fill").font(.headline).foregroundStyle(.appAccent)
                benchmark.infoIcon(id: "generationPhase", tip: L10n.Dashboard.stats.tipGenerationPhase)
            }
            VStack(spacing: DesignSystem.small) {
                HStack(spacing: DesignSystem.medium) {
                    benchmark.scoreCard(id: "faithfulness", title: L10n.Dashboard.stats.faithfulness,
                              score: avgScores.faithfulness, icon: "checkmark.shield", tip: L10n.Dashboard.stats.tipFaithfulness)
                    benchmark.scoreCard(id: "relevance", title: L10n.Dashboard.stats.relevance,
                              score: avgScores.relevance, icon: "target", tip: L10n.Dashboard.stats.tipRelevance)
                    benchmark.scoreCard(id: "hallucination", title: L10n.Dashboard.stats.hallucinationRate,
                              score: avgScores.hallucinationRate, icon: "exclamationmark.bubble",
                              inverted: true, tip: L10n.Dashboard.stats.tipHallucination)
                }
                HStack(spacing: DesignSystem.medium) {
                    benchmark.scoreCard(id: "correctness", title: L10n.Dashboard.stats.answerCorrectness,
                              score: avgScores.answerCorrectness, icon: "checkmark.seal", tip: L10n.Dashboard.stats.tipCorrectness)
                    benchmark.scoreCard(id: "contextSufficiency", title: L10n.Dashboard.stats.contextSufficiency,
                              score: avgScores.contextSufficiency, icon: "books.vertical.fill", tip: L10n.Dashboard.stats.tipContextSufficiency)
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
        .appCardStyle()
    }
}
