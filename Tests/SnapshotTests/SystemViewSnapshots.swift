//
//  SystemViewSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：Features/System View 快照测试，验证视觉一致性
//

import XCTest
import UFPCore
import SwiftUI
import SnapshotTesting
import Combine
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class SystemViewSnapshots: XCTestCase {

    /// 保存原始语言模式，在 tearDown 中恢复
    private var originalLanguageMode: LanguageMode?

    /// 依据环境变量判断快照录制策略，用于支持 CI/CD 脚本自动更新基准图片
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func tearDown() async throws {
        if let original = originalLanguageMode {
            Localized.languageMode = original
        }
        try await super.tearDown()
    }

    /// 统一配置 Mock 测试环境并控制快照录制模式
    private func setupMockEnvironment() {
        setupFullMockEnvironment()

        // 强制中文环境，确保快照文本一致性，避免语言环境漂移导致快照不匹配
        if originalLanguageMode == nil {
            originalLanguageMode = Localized.languageMode
        }
        Localized.languageMode = .chinese

        // 清理聊天历史，防止其他测试（如 UI 测试）的残留数据污染快照测试
        ChatService.shared.clearHistory()

        // 重置提示词服务到默认状态，防止设置修改污染快照
        @Dependency(\.promptService) var promptService: PromptService
        promptService.reset()
    }

    // MARK: - 1. RAGBenchmarkPanel（RAGRetrievalPanel / RAGGenerationPanel）

    /// 测试 RAGRetrievalPanel 默认数据状态的视觉一致性
    func testRAGRetrievalPanelDefault() {
        setupMockEnvironment()

        var activeTooltip: String?
        let avgScores = AverageRAGScores(
            faithfulness: 0.85,
            relevance: 0.78,
            precision: 0.82,
            hallucinationRate: 0.12,
            citationAccuracy: 0.90,
            answerCorrectness: 0.88,
            contextSufficiency: 0.75
        )
        let latency = LatencyPercentiles(p50: 320, p95: 880, p99: 1500, sampleCount: 128)

        let view = RAGRetrievalPanel(
            avgScores: avgScores,
            hitRate: 0.72,
            mrr: 0.65,
            ndcg: 0.81,
            recall: 0.68,
            f1Score: 0.70,
            mapScore: 0.63,
            latency: latency,
            activeTooltip: Binding(get: { activeTooltip }, set: { activeTooltip = $0 })
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 RAGRetrievalPanel 极端值（0/100）与 nil tooltip 状态
    func testRAGRetrievalPanelExtremeValues() {
        setupMockEnvironment()

        var activeTooltip: String?
        let avgScores = AverageRAGScores(
            faithfulness: 0.0,
            relevance: 0.0,
            precision: 0.0,
            hallucinationRate: 1.0,
            citationAccuracy: 0.0,
            answerCorrectness: 0.0,
            contextSufficiency: 0.0
        )
        let latency = LatencyPercentiles(p50: 0, p95: 0, p99: 0, sampleCount: 0)

        let view = RAGRetrievalPanel(
            avgScores: avgScores,
            hitRate: 0.0,
            mrr: 0.0,
            ndcg: 0.0,
            recall: 0.0,
            f1Score: 0.0,
            mapScore: 0.0,
            latency: latency,
            activeTooltip: Binding(get: { activeTooltip }, set: { _ in })
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 RAGGenerationPanel 默认数据状态的视觉一致性
    func testRAGGenerationPanelDefault() {
        setupMockEnvironment()

        var activeTooltip: String?
        let avgScores = AverageRAGScores(
            faithfulness: 0.92,
            relevance: 0.88,
            precision: 0.85,
            hallucinationRate: 0.08,
            citationAccuracy: 0.90,
            answerCorrectness: 0.87,
            contextSufficiency: 0.80
        )

        let view = RAGGenerationPanel(
            avgScores: avgScores,
            activeTooltip: Binding(get: { activeTooltip }, set: { activeTooltip = $0 })
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 RAGGenerationPanel 极端值（满分/零分）状态
    func testRAGGenerationPanelExtremeValues() {
        setupMockEnvironment()

        var activeTooltip: String?
        let avgScores = AverageRAGScores(
            faithfulness: 1.0,
            relevance: 1.0,
            precision: 1.0,
            hallucinationRate: 0.0,
            citationAccuracy: 1.0,
            answerCorrectness: 1.0,
            contextSufficiency: 1.0
        )

        let view = RAGGenerationPanel(
            avgScores: avgScores,
            activeTooltip: Binding(get: { activeTooltip }, set: { _ in })
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. SystemStatsChartView（ChartView）

    /// 测试 ChartView 空数组 + requests 类型的视觉一致性
    func testChartViewEmptyRequests() {
        setupMockEnvironment()

        let view = ChartView(stats: [], type: .requests)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.chartHeight + 60)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.chartHeight + 60)))
    }

    /// 测试 ChartView 非空数组 + requests 类型的视觉一致性
    func testChartViewWithDataRequests() {
        setupMockEnvironment()

        let stats = Self.makeDailyAIUsageSamples()
        let view = ChartView(stats: stats, type: .requests)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.chartHeight + 60)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.relaxedPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.chartHeight + 60)))
    }

    /// 测试 ChartView 非空数组 + tokens 类型的视觉一致性
    func testChartViewWithDataTokens() {
        setupMockEnvironment()

        let stats = Self.makeDailyAIUsageSamples()
        let view = ChartView(stats: stats, type: .tokens)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.chartHeight + 60)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.relaxedPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.chartHeight + 60)))
    }

    /// 构造本月每日 AI 使用统计样本数据（固定基准日期杜绝月份跨越导致快照漂移）
    private static func makeDailyAIUsageSamples() -> [DailyAIUsage] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let fixedDate = Date(timeIntervalSince1970: 1750000000) // 确定性固定日期
        let components = calendar.dateComponents([.year, .month], from: fixedDate)
        guard let startOfMonth = calendar.date(from: components) else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone
        return (0..<15).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfMonth) else { return nil }
            return DailyAIUsage(
                date: date,
                dateString: formatter.string(from: date),
                tokens: 1200 + offset * 350,
                requests: 20 + offset * 5
            )
        }
    }

    // MARK: - 3. ServerConfigView

    /// 测试 ServerConfigView 默认空状态的视觉一致性
    func testServerConfigViewDefault() {
        setupMockEnvironment()

        let view = ServerConfigView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 4. LocalPluginDetailView

    /// 测试 LocalPluginDetailView 默认 manifest 状态的视觉一致性
    func testLocalPluginDetailViewDefault() {
        setupMockEnvironment()

        let manifest = PluginManifest(
            id: "com.zhiyu.plugin.local.toc-generator",
            version: "1.2.0",
            author: "ZhiYu Team",
            permissions: ["readContent", "writeContent", "network"],
            allowedDomains: ["example.com"],
            names: ["en": "TOC Generator", "zh-Hans": "目录生成器"],
            descriptions: ["en": "Auto-generate table of contents.", "zh-Hans": "自动生成目录结构。"],
            readmeFiles: nil,
            iconFile: nil,
            category: "utility",
            codeSignature: nil
        )

        let view = NavigationStack {
            LocalPluginDetailView(manifest: manifest)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 LocalPluginDetailView 极简 manifest（无权限）状态的视觉一致性
    func testLocalPluginDetailViewMinimalManifest() {
        setupMockEnvironment()

        let manifest = PluginManifest(
            id: "com.zhiyu.plugin.local.word-counter",
            version: "0.9.1",
            author: "Anonymous",
            permissions: [],
            allowedDomains: nil,
            names: ["en": "Word Counter", "zh-Hans": "字数统计"],
            descriptions: ["en": "Count words.", "zh-Hans": "统计字数。"],
            readmeFiles: nil,
            iconFile: nil,
            category: nil,
            codeSignature: nil
        )

        let view = NavigationStack {
            LocalPluginDetailView(manifest: manifest)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 5. PluginStatsSection

    /// 测试 PluginStatsSection 默认空状态（无插件资源使用）的视觉一致性
    func testPluginStatsSectionEmpty() {
        setupMockEnvironment()

        let view = PluginStatsSection()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 6. RawStorageListView

    /// 测试 RawStorageListView 空状态（无原始页面）的视觉一致性
    func testRawStorageListViewEmpty() {
        setupMockEnvironment()

        let view = NavigationStack {
            RawStorageListView()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 RawStorageListView 有数据状态的视觉一致性
    func testRawStorageListViewWithData() {
        setupMockEnvironment()

        // 通过 KnowledgeStore 注入原始页面数据
        let store = KnowledgeStore()
        store.pages = Self.makeRawPageSamples()

        let view = NavigationStack {
            RawStorageListView()
        }
        .snapshotEnvironment()
        .environment(store) // snapshot_env_exempt: 覆盖默认空 KnowledgeStore 以注入 pages 测试数据
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 构造原始页面样本数据（含 sourceURL，触发 RawStorageListView 渲染分支）
    private static func makeRawPageSamples() -> [KnowledgePage] {
        return [
            KnowledgePage(
                title: "量子纠缠研究笔记",
                pageType: .concept,
                content: "量子纠缠是量子力学中的一种现象...",
                tags: ["物理", "量子"],
                sourceURL: "https://example.com/quantum.pdf",
                fileSize: 204800,
                sourceType: "pdf"
            ),
            KnowledgePage(
                title: "语音备忘录 - 项目思路",
                pageType: .concept,
                content: "录音转写内容...",
                tags: ["语音"],
                sourceURL: "file://localhost/voice.m4a",
                fileSize: 102400,
                sourceType: "m4a"
            ),
            KnowledgePage(
                title: "OCR 扫描文档",
                pageType: .concept,
                content: "扫描识别文本...",
                tags: ["OCR"],
                sourceURL: "file://localhost/scan.png",
                fileSize: 512000,
                sourceType: "png"
            )
        ]
    }

    // MARK: - 7. PerformanceDashboardView

    /// 测试 PerformanceDashboardView 默认状态的视觉一致性
    func testPerformanceDashboardViewDefault() {
        setupMockEnvironment()

        let service = PerformanceService()
        let view = PerformanceDashboardView(service: service)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 PerformanceDashboardView 带指标数据的视觉一致性
    func testPerformanceDashboardViewWithMetrics() {
        setupMockEnvironment()

        let service = PerformanceService()
        // 预填充性能指标数据，覆盖更多渲染分支
        service.metrics.memoryUsageMB = 128.5
        service.metrics.pageCount = 42
        service.metrics.totalWords = 15680
        service.metrics.graphNodeCount = 42
        service.metrics.graphEdgeCount = 88
        service.metrics.llmCallCount = 256
        service.metrics.aiSuccessRate = 0.95
        service.metrics.saveDuration = 0.245
        service.metrics.loadDuration = 0.182
        service.metrics.lintDuration = 0.093
        service.metrics.graphLayoutDuration = 0.521
        service.metrics.searchDuration = 0.067
        service.metrics.ragChainDuration = 1.234

        let view = PerformanceDashboardView(service: service)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 8. InferenceParametersView

    /// 测试 InferenceParametersView 默认状态的视觉一致性
    func testInferenceParametersViewDefault() {
        setupMockEnvironment()

        let view = InferenceParametersView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 InferenceParametersView 在 NavigationStack 中的视觉一致性
    func testInferenceParametersViewInNavigation() {
        setupMockEnvironment()

        let view = NavigationStack {
            InferenceParametersView()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }
}
