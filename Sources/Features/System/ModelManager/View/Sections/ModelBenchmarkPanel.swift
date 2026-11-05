//
//  ModelBenchmarkPanel.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：端侧大模型性能基准跑分沙盒交互面板 — 展示 TTFT、TPS、RAM 动态仪表盘与性能评级报告。
//

import SwiftUI
import UFPCore
import UFPDesignSystem

/// 基准跑分沙盒状态管理
@Observable
@MainActor
final class ModelBenchmarkState {
    static let shared = ModelBenchmarkState()

    var isRunning: Bool = false
    var currentResult: BenchmarkResult = BenchmarkResult()
    var selectedModelId: String = ""

    init() {}

    /// 执行多轮次跑分压测
    func startBenchmark(modelId: String) async {
        guard !isRunning else { return }
        isRunning = true
        selectedModelId = modelId

        let finalResult = await ModelBenchmarkRunner.shared.runBenchmark(
            modelId: modelId,
            rounds: FeatureConstants.Benchmark.defaultRounds
        ) { [weak self] _, progressResult in
            Task { @MainActor in
                self?.currentResult = progressResult
            }
        }

        currentResult = finalResult
        isRunning = false
    }
}

// MARK: - 基准跑分视图扩展

extension ModelLabView {

    /// 基准跑分沙盒面板
    @ViewBuilder
    var benchmarkSandboxView: some View {
        ModelBenchmarkContentView(
            labView: self,
            state: ModelBenchmarkState.shared
        )
    }
}

/// 基准跑分内容子视图
@MainActor
struct ModelBenchmarkContentView: View {
    let labView: ModelLabView
    @Bindable var state: ModelBenchmarkState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.Spacing.large) {
                // 1. 控制栏
                labView.modelAndConfigControlBar(for: .benchmark)

                // 2. 跑分仪表盘卡片
                dashboardGaugeCard

                // 3. 详细指标三联卡
                metricsGrid

                // 4. 底部开始/进行中操作栏
                actionControlSection
            }
            .padding(.vertical, DesignTokens.SystemSpacing.atomic)
        }
    }

    // MARK: - 核心仪表盘卡片

    @ViewBuilder
    private var dashboardGaugeCard: some View {
        let gaugeSize = FeatureConstants.Benchmark.gaugeDiameter
        let strokeWidth = FeatureConstants.Benchmark.gaugeStrokeWidth

        VStack(spacing: DesignTokens.Spacing.medium) {
            ZStack {
                // 环形外框槽（直径 200，保证将内部文字完整包裹，杜绝重叠）
                Circle()
                    .stroke(Color.appBorder.opacity(DesignTokens.Opacity.subtle), lineWidth: strokeWidth)
                    .frame(width: gaugeSize, height: gaugeSize)

                if state.isRunning {
                    Circle()
                        .trim(from: 0.0, to: 0.75)
                        .stroke(
                            AngularGradient(
                                colors: [Color.theme.purple, Color.theme.cyan],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: gaugeSize, height: gaugeSize)
                        .rotationEffect(.degrees(state.isRunning ? 360 : 0))
                        .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: state.isRunning)
                }

                VStack(spacing: DesignTokens.SystemSpacing.atomic) {
                    Image(systemName: DesignTokens.Icons.gaugeWithNeedle)
                        .font(.title2)
                        .foregroundStyle(Color.theme.purple)

                    Text(L10n.ModelManager.Benchmark.tpsFormat(state.currentResult.decodeTPS))
                        .font(.system(size: DesignTokens.SystemFontSize.display, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.theme.text)

                    Text(L10n.ModelManager.Benchmark.tps)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DesignTokens.Spacing.standardPadding)
            }
            .padding(.vertical, DesignTokens.Spacing.small)

            // 评级徽章
            Text(state.currentResult.grade.title)
                .font(.subheadline.bold())
                .foregroundStyle(gradeColor(for: state.currentResult.grade))
                .padding(.horizontal, DesignTokens.SystemSpacing.content)
                .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                .background(gradeColor(for: state.currentResult.grade).opacity(DesignTokens.Opacity.subtle))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.standardPadding)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .cornerRadius(DesignTokens.Spacing.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius)
                .stroke(Color.theme.purple.opacity(DesignTokens.Opacity.disabled), lineWidth: DesignTokens.SystemStroke.divider)
        )
    }

    // MARK: - 详细指标卡片网格

    @ViewBuilder
    private var metricsGrid: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            metricItemCard(
                icon: DesignTokens.Icons.clock,
                title: L10n.ModelManager.Benchmark.ttft,
                value: L10n.ModelManager.Benchmark.ttftFormat(state.currentResult.ttftMilliseconds),
                color: Color.theme.blue
            )

            metricItemCard(
                icon: DesignTokens.Icons.cpu,
                title: L10n.ModelManager.Benchmark.ram,
                value: L10n.ModelManager.Benchmark.ramFormat(state.currentResult.peakRAMDeltaMB),
                color: Color.theme.cyan
            )
        }
    }

    @ViewBuilder
    private func metricItemCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
            HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.headline.bold())
                .foregroundStyle(Color.theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.standardPadding)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .cornerRadius(DesignTokens.Spacing.mediumRadius)
    }

    // MARK: - 底部操作栏

    @ViewBuilder
    private var actionControlSection: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            if state.currentResult.completedRounds > 0 {
                Text(L10n.ModelManager.Benchmark.roundsFormat(state.currentResult.completedRounds, state.currentResult.totalRounds))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                let modelId = labView.modelManager.activeModelId
                Task {
                    await state.startBenchmark(modelId: modelId)
                }
            }) {
                HStack(spacing: DesignTokens.SystemSpacing.small) {
                    if state.isRunning {
                        ProgressView()
                            .tint(Color.theme.white)
                        Text(L10n.ModelManager.Benchmark.running)
                    } else {
                        Image(systemName: DesignTokens.Icons.playFill)
                        Text(L10n.ModelManager.Benchmark.start)
                    }
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.theme.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.SystemSpacing.medium)
                .background(Color.theme.purple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(state.isRunning)
            .opacity(state.isRunning ? DesignTokens.Opacity.disabled : DesignTokens.Opacity.solid)
        }
    }

    private func gradeColor(for grade: BenchmarkGrade) -> Color {
        switch grade {
        case .excellent: return Color.theme.green
        case .good: return Color.theme.cyan
        case .warning: return Color.theme.orange
        }
    }
}
