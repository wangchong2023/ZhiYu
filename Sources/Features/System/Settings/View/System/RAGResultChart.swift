//
//  RAGResultChart.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：RAG 结果统计图表 — 用户满意度进度条 / Token 成本面板 / 评估历史记录。
//

import SwiftUI

// MARK: - 👍 用户满意度面板

/// 展示用户点赞/踩满意度进度条
struct RAGSatisfactionPanel: View {
    let satisfactionRate: Double
    let satisfactionThumbsUp: Int
    let satisfactionThumbsDown: Int

    var body: some View {
        let barHeight: CGFloat = 12
        return VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: DesignSystem.small) {
                Label(L10n.Dashboard.stats.userSatisfaction, systemImage: "hand.thumbsup.fill").font(.headline).foregroundStyle(.blue)
                // info icon omitted here — handled by caller
            }

            let total = satisfactionThumbsUp + satisfactionThumbsDown
            if total > 0 {
                HStack(spacing: DesignSystem.medium) {
                    // 进度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: DesignSystem.atomic)
                                .fill(Color.appCard).frame(height: barHeight)
                            RoundedRectangle(cornerRadius: DesignSystem.atomic)
                                .fill(satisfactionColor)
                                .frame(width: geo.size.width * satisfactionRate, height: barHeight)
                        }
                    }
                    .frame(height: barHeight)

                    Text(String(format: FormatPattern.percentInt, satisfactionRate * 100) + "%")
                        .font(.title3.bold()).foregroundStyle(satisfactionColor)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(satisfactionThumbsUp) 👍  \(satisfactionThumbsDown) 👎")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(total) \(L10n.Dashboard.stats.ratingTotal)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text(L10n.Dashboard.stats.noRatings)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.vertical, DesignSystem.small).frame(maxWidth: .infinity)
            }
        }
        .appCardStyle()
    }

    private var satisfactionColor: Color {
        if satisfactionRate >= ScoreThreshold.excellent { return .green }
        if satisfactionRate >= ScoreThreshold.fair { return .orange }
        return .red
    }
}

// MARK: - 💰 资源消耗面板

/// Token 效率与预估成本面板
struct RAGCostPanel: View {
    let tokenEfficiency: TokenEfficiency

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: DesignSystem.small) {
                Label(L10n.Dashboard.stats.tokenEfficiency, systemImage: "dollarsign.circle").font(.headline).foregroundStyle(.green)
            }
            HStack(spacing: DesignSystem.medium) {
                tokenMetricCard(id: "totalTokens", title: L10n.Dashboard.stats.totalTokens,
                                value: tokenEfficiency.totalTokens.formatted(.number.notation(.compactName)))
                tokenMetricCard(id: "queryCount", title: L10n.Dashboard.stats.queryCount,
                                value: String(tokenEfficiency.queryCount))
                tokenMetricCard(id: "avgTokens", title: L10n.Dashboard.stats.avgTokensPerQuery,
                                value: String(format: FormatPattern.tokenAvg, tokenEfficiency.avgTokensPerQuery))
            }
            HStack {
                Text(L10n.Dashboard.stats.estimatedCost).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: FormatPattern.costUSD, tokenEfficiency.estimatedCostUSD))
                    .font(.system(size: FontSize.tokenValue, weight: .bold, design: .monospaced))
                    .foregroundStyle(tokenEfficiency.estimatedCostUSD < CostThreshold.low ? .green : .orange)
            }
            .padding(.horizontal, DesignSystem.small)
        }
        .appCardStyle()
    }

    private func tokenMetricCard(id _: String, title: String, value: String) -> some View {
        VStack(spacing: DesignSystem.tightPadding) {
            Text(value).font(.system(size: FontSize.tokenValue, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            HStack(spacing: SystemSpacing.atomic) {
                Text(title).font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, DesignSystem.small)
        .background(Color.theme.green.opacity(CardVisual.tokenBgOpacity)).clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
    }
}

// MARK: - 📋 评估记录面板

/// 评估历史记录面板（含 👍👎 交互评分按钮）
struct RAGEvaluationHistoryPanel: View {
    let recentEvaluations: [RAGEvaluation]
    let governance: any RAGGovernanceRepository
    let onReload: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Label(L10n.Dashboard.stats.recentEvaluations, systemImage: "list.bullet.clipboard").font(.headline).foregroundStyle(.orange)
            if recentEvaluations.isEmpty {
                Text(L10n.Dashboard.stats.noEvaluations)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.vertical, DesignSystem.large).frame(maxWidth: .infinity)
            } else {
                ForEach(recentEvaluations.prefix(EvalDisplay.displayLimit), id: \.id) { eval in
                    evaluationRow(eval)
                    if eval.id != recentEvaluations.prefix(EvalDisplay.displayLimit).last?.id { Divider() }
                }
            }
        }
        .appCardStyle()
    }

    // MARK: - 评估记录行

    private func evaluationRow(_ eval: RAGEvaluation) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            HStack {
                Text(eval.query.prefix(EvalDisplay.queryPreviewChars)
                     + (eval.query.count > EvalDisplay.queryPreviewChars ? "…" : ""))
                    .font(.subheadline.bold()).lineLimit(1)
                Spacer()
                scoreBadge(overallScore(eval))
                // 👍👎 按钮
                ratingButton(eval: eval, rating: UserRating.thumbsUp, icon: RatingIcon.thumbsUp, isActive: eval.userRating == UserRating.thumbsUp)
                ratingButton(eval: eval, rating: UserRating.thumbsDown, icon: RatingIcon.thumbsDown, isActive: eval.userRating == UserRating.thumbsDown)
            }
            HStack(spacing: DesignSystem.small) {
                tagLabel(MetricTag.faithfulness, value: eval.faithfulness)
                tagLabel(MetricTag.relevance, value: eval.relevance)
                tagLabel(MetricTag.hallucination, value: eval.hallucinationRate, inverted: true)
            }
            HStack(spacing: DesignSystem.small) {
                tagLabel(MetricTag.correctness, value: eval.answerCorrectness)
                tagLabel(MetricTag.citation, value: eval.citationAccuracy)
                tagLabel(MetricTag.contextSufficiency, value: eval.contextSufficiency)
            }
            Text(eval.evaluatorModel).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, DesignSystem.tiny)
    }

    private func ratingButton(eval: RAGEvaluation, rating: Int, icon: String, isActive: Bool) -> some View {
        Button {
            guard let evalID = eval.id else { return }
            Task {
                try? await governance.updateUserRating(evaluationID: evalID, rating: rating)
                await onReload()
            }
        } label: {
            Image(systemName: icon)
                .font(.caption).foregroundStyle(isActive ? .blue : .appSecondary.opacity(DesignSystem.Opacity.disabled))
        }
        .buttonStyle(.plain)
    }

    private func scoreBadge(_ score: Double) -> some View {
        Text(String(format: FormatPattern.score1, score * 100))
            .font(.caption.bold()).foregroundStyle(scoreColor(score))
            .padding(.horizontal, DesignSystem.small).padding(.vertical, DesignSystem.atomic)
            .background(scoreColor(score).opacity(DesignSystem.Opacity.subtle)).clipShape(Capsule())
    }

    private func tagLabel(_ prefix: String, value: Double, inverted: Bool = false) -> some View {
        let color = inverted ? invertedScoreColor(value) : scoreColor(value)
        return Text("\(prefix):\(String(format: FormatPattern.score2, value))")
            .font(.system(size: FontSize.tag, weight: .medium, design: .monospaced)).foregroundStyle(color)
            .padding(.horizontal, TagVisual.horizontalPadding).padding(.vertical, TagVisual.verticalPadding)
            .background(color.opacity(DesignSystem.Opacity.light)).clipShape(RoundedRectangle(cornerRadius: TagVisual.cornerRadius))
    }

    // MARK: - 评分与颜色

    private func overallScore(_ eval: RAGEvaluation) -> Double {
        let positiveMean = (eval.faithfulness + eval.relevance + eval.precision
                            + eval.citationAccuracy + eval.answerCorrectness
                            + eval.contextSufficiency) / EvalDisplay.positiveMetricCount
        let penalty = eval.hallucinationRate * EvalDisplay.hallucinationPenaltyWeight
        return max(0, positiveMean - penalty)
    }

    private func scoreColor(_ s: Double) -> Color {
        if s >= ScoreThreshold.excellent { return .green }
        if s >= ScoreThreshold.fair { return .orange }
        return .red
    }

    private func invertedScoreColor(_ s: Double) -> Color {
        if s <= ScoreThreshold.invertedExcellent { return .green }
        if s <= ScoreThreshold.invertedFair { return .orange }
        return .red
    }
}
