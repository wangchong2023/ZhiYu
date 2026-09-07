//
//  LiveActivityDeepTests.swift
//  ZhiYuTests
//
//  合并自 5 个碎片化测试文件：LiveActivityAndDynamicIslandDeepTests.swift, LiveActivityAndTaskProgressDeepAuditTests.swift, LiveActivityAndWidgetInteractiveTests.swift, LiveActivityDeepTests.swift, PlatformLiveActivityAndWidgetsDeepTests.swift
//

import ActivityKit
import Dependencies
import SwiftUI
import UFPCore
import WidgetKit
import XCTest

@testable import ZhiYu

@MainActor
final class LiveActivityDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testAIProcessingAttributesDataFlow() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let attr = AIProcessingAttributes(
            taskName: "AI Synthesis Lab",
            startTime: Date()
        )
        XCTAssertEqual(attr.taskName, "AI Synthesis Lab")

        var state = AIProcessingAttributes.ContentState(
            progress: 0.45,
            status: "Clustering Semantic Chunks...",
            kind: .synthesis,
            sourceCount: 5,
            currentFileName: "NeuralArch.pdf",
            estimatedSecondsRemaining: 12
        )
        XCTAssertEqual(state.progress, 0.45)
        XCTAssertEqual(state.sourceCount, 5)

        state.kind = .ingestOCR
        state.progress = 0.85
        XCTAssertEqual(state.kind, .ingestOCR)

        state.kind = .voiceNote
        state.progress = 1.0
        XCTAssertEqual(state.kind, .voiceNote)
        #endif
    }

    func testAITaskProgress_SerializationAndProgressClamping() throws {
        let metadata = AITaskMetadata(taskName: "AI 知识合成", startTime: Date())
        let state = AITaskProgressState(progress: 0.75, status: "正在生成思维导图...")

        let encoder = JSONEncoder()
        let metaData = try encoder.encode(metadata)
        let stateData = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decodedMeta = try decoder.decode(AITaskMetadata.self, from: metaData)
        let decodedState = try decoder.decode(AITaskProgressState.self, from: stateData)

        XCTAssertEqual(decodedMeta.taskName, "AI 知识合成")
        XCTAssertEqual(decodedState.progress, 0.75)
        XCTAssertEqual(decodedState.status, "正在生成思维导图...")
    }

    func testLiveActivityProgressCalculator_clampProgress_handlesNormalAndExtremeInputs() {
        // 正常进度
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(1.0), 1.0, accuracy: 0.001)

        // 越界进度
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(-0.2), 0.0, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(1.8), 1.0, accuracy: 0.001)

        // 验证缺陷 #176 修复：极端/NaN/无穷大异常保护
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(Double.nan), 0.0, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(Double.infinity), 0.0, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampProgress(-Double.infinity), 0.0, accuracy: 0.001)
    }

    func testLiveActivityProgressCalculator_formatPercentage_preventsCrashAndOutputsInt() {
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(0.65), "65%")
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(0.0), "0%")
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(1.0), "100%")

        // 验证缺陷 #176 修复：Double.nan 转 Int 绝不崩溃
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(Double.nan), "0%")
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(Double.infinity), "0%")
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(-Double.infinity), "0%")
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(-10.0), "0%")
        XCTAssertEqual(LiveActivityProgressCalculator.formatPercentage(999.0), "100%")
    }

    func testLiveActivityProgressCalculator_formatRemainingSeconds_returnsOptionalString() {
        XCTAssertEqual(LiveActivityProgressCalculator.formatRemainingSeconds(45), "45s")
        XCTAssertEqual(LiveActivityProgressCalculator.formatRemainingSeconds(1), "1s")

        // 非正数倒计时优雅返回 nil
        XCTAssertNil(LiveActivityProgressCalculator.formatRemainingSeconds(0))
        XCTAssertNil(LiveActivityProgressCalculator.formatRemainingSeconds(-10))
    }

    func testLiveActivityProgressCalculator_clampOpacity_handlesExtremeInputs() {
        let fallback = PlatformConstants.WidgetWatch.distributionFallbackOpacity

        // 空值保底
        XCTAssertEqual(LiveActivityProgressCalculator.clampOpacity(nil, fallback: fallback), fallback, accuracy: 0.001)

        // 正常透明度
        XCTAssertEqual(LiveActivityProgressCalculator.clampOpacity(0.8, fallback: fallback), 0.8, accuracy: 0.001)

        // 异常与越界
        XCTAssertEqual(LiveActivityProgressCalculator.clampOpacity(Double.nan, fallback: fallback), fallback, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampOpacity(Double.infinity, fallback: fallback), fallback, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampOpacity(-0.5, fallback: fallback), 0.0, accuracy: 0.001)
        XCTAssertEqual(LiveActivityProgressCalculator.clampOpacity(1.5, fallback: fallback), 1.0, accuracy: 0.001)
    }

    func testLiveActivityView_widgetConfigurationBuild() {
        let widget = LiveActivityView()
        XCTAssertNotNil(widget.body, "LiveActivityView 必须成功构建 WidgetConfiguration")
    }

    func testDailyInsightWidgetView_mountsWithCustomAndDefaultContent() {
        let defaultWidget = DailyInsightWidgetView()
        let defaultController = UIHostingController(rootView: defaultWidget)
        defaultController.loadViewIfNeeded()
        XCTAssertNotNil(defaultController.view, "默认 DailyInsightWidgetView 必须正常渲染")

        let customWidget = DailyInsightWidgetView(
            title: "Karpathy LLM OS",
            content: "Memory hierarchy, context caching and agentic synthesis."
        )
        let customController = UIHostingController(rootView: customWidget)
        customController.loadViewIfNeeded()
        XCTAssertNotNil(customController.view, "自定义 DailyInsightWidgetView 必须正常渲染")
    }

    func testKnowledgeDistributionWidgetView_mountsWithNormalAndCorruptedDistribution() {
        // 正常分布数据
        let normalWidget = KnowledgeDistributionWidgetView(
            pageCount: 42,
            distribution: ["Concept": 0.6, "Source": 0.4]
        )
        let normalController = UIHostingController(rootView: normalWidget)
        normalController.loadViewIfNeeded()
        XCTAssertNotNil(normalController.view, "正常知识分布小组件应正常渲染")

        // 损坏数据（防范缺陷 #176）
        let corruptWidget = KnowledgeDistributionWidgetView(
            pageCount: 0,
            distribution: ["Corrupt": Double.nan, "Extreme": 99.0, "Negative": -1.0]
        )
        let corruptController = UIHostingController(rootView: corruptWidget)
        corruptController.loadViewIfNeeded()
        XCTAssertNotNil(corruptController.view, "异常/NaN 分布数据下小组件必须安全渲染")
    }

    func testQuickCaptureWidgetView_mountsSuccessfully() {
        let widget = QuickCaptureWidgetView()
        let controller = UIHostingController(rootView: widget)
        controller.loadViewIfNeeded()
        XCTAssertNotNil(controller.view, "QuickCaptureWidgetView 必须平稳渲染各快捷操作入口")
    }

    func testWatchDailyInsightView_mountsWithCustomInsights() {
        let customQuotes = [
            "LLM as CPU, Context Window as RAM.",
            "Retrieval Augmented Generation as disk cache."
        ]
        let watchView = WatchDailyInsightView(insights: customQuotes)
        let controller = UIHostingController(rootView: watchView)
        controller.loadViewIfNeeded()
        XCTAssertNotNil(controller.view, "WatchDailyInsightView 必须平稳渲染轮播页面")
    }

    func testAIProcessingAttributes_lifecycleProgression() {
        let now = Date()
        let attr = AIProcessingAttributes(taskName: "RAG Ingest", startTime: now)
        XCTAssertEqual(attr.taskName, "RAG Ingest")

        var state = AIProcessingAttributes.ContentState(
            progress: 0.1,
            status: "Starting",
            kind: .synthesis,
            sourceCount: 2,
            currentFileName: "doc.txt",
            estimatedSecondsRemaining: 60
        )
        XCTAssertEqual(state.progress, 0.1, accuracy: 0.001)

        // 状态推移
        state.progress = 0.95
        state.status = "Finalizing"
        state.estimatedSecondsRemaining = 2
        XCTAssertEqual(state.progress, 0.95, accuracy: 0.001)
        XCTAssertEqual(state.status, "Finalizing")
        XCTAssertEqual(state.estimatedSecondsRemaining, 2)
    }

    func testLiveActivityProgressCalculator_fuzz100RandomProgressValues_neverCrashes() {
        let extremeValues: [Double] = [
            -Double.greatestFiniteMagnitude,
            Double.greatestFiniteMagnitude,
            -1e10, 1e10, -0.00001, 0.00001,
            Double.nan, Double.infinity, -Double.infinity,
            -0.0, 0.0, 1.0, 0.9999999
        ]

        for val in extremeValues {
            let clamped = LiveActivityProgressCalculator.clampProgress(val)
            XCTAssertGreaterThanOrEqual(clamped, 0.0)
            XCTAssertLessThanOrEqual(clamped, 1.0)

            let pct = LiveActivityProgressCalculator.formatPercentage(val)
            XCTAssertFalse(pct.contains("nan"))
            XCTAssertFalse(pct.contains("inf"))
            XCTAssertTrue(pct.hasSuffix("%"))
        }

        for _ in 0..<100 {
            let randomProgress = Double.random(in: -100.0...100.0)
            let clamped = LiveActivityProgressCalculator.clampProgress(randomProgress)
            XCTAssertGreaterThanOrEqual(clamped, 0.0)
            XCTAssertLessThanOrEqual(clamped, 1.0)

            let pct = LiveActivityProgressCalculator.formatPercentage(randomProgress)
            XCTAssertFalse(pct.contains("nan"))
            XCTAssertTrue(pct.hasSuffix("%"))
        }
    }

    func testLiveActivityProgressCalculator_fuzz100RandomOpacityValues_neverCrashes() {
        let fallback = PlatformConstants.WidgetWatch.distributionFallbackOpacity

        for _ in 0..<100 {
            let randomOpacity = Double.random(in: -50.0...50.0)
            let clamped = LiveActivityProgressCalculator.clampOpacity(randomOpacity, fallback: fallback)
            XCTAssertGreaterThanOrEqual(clamped, 0.0)
            XCTAssertLessThanOrEqual(clamped, 1.0)
        }
    }

    func testActivityKind_AllCases() {
        let kinds: [ActivityKind] = [.synthesis, .ingestOCR, .voiceNote]
        for kind in kinds {
            XCTAssertFalse(kind.rawValue.isEmpty)
        }
    }

    func testAIProcessingAttributes_InitAndState() {
        let fixedDate = Date(timeIntervalSince1970: 1750000000)
        let attributes = AIProcessingAttributes(taskName: "《Karpathy LLM OS》知识摄取", startTime: fixedDate)
        XCTAssertEqual(attributes.taskName, "《Karpathy LLM OS》知识摄取")

        let state = AIProcessingAttributes.ContentState(
            progress: 0.75,
            status: "正在生成双链图谱与向量索引",
            kind: .synthesis,
            estimatedSecondsRemaining: 12
        )
        XCTAssertEqual(state.progress, 0.75)
        XCTAssertEqual(state.status, "正在生成双链图谱与向量索引")
        XCTAssertEqual(state.kind, .synthesis)
        XCTAssertEqual(state.estimatedSecondsRemaining, 12)
    }

    func testAIProcessingAttributes_InitializationAndState() {
        let startTime = Date()
        let attributes = AIProcessingAttributes(taskName: "知识合成与炼化", startTime: startTime)
        XCTAssertEqual(attributes.taskName, "知识合成与炼化")
        XCTAssertEqual(attributes.startTime, startTime)

        var state = AIProcessingAttributes.ContentState(
            progress: 0.25,
            status: "提取文本分块中",
            kind: .synthesis,
            sourceCount: 5,
            currentFileName: "RAG架构指南.md",
            estimatedSecondsRemaining: 45
        )

        XCTAssertEqual(state.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(state.status, "提取文本分块中")
        XCTAssertEqual(state.kind, .synthesis)
        XCTAssertEqual(state.sourceCount, 5)
        XCTAssertEqual(state.currentFileName, "RAG架构指南.md")
        XCTAssertEqual(state.estimatedSecondsRemaining, 45)

        // 状态机流转到下一阶段
        state.progress = 0.85
        state.status = "生成脑图与摘要"
        state.kind = .ingestOCR
        state.estimatedSecondsRemaining = 5

        XCTAssertEqual(state.progress, 0.85, accuracy: 0.001)
        XCTAssertEqual(state.status, "生成脑图与摘要")
        XCTAssertEqual(state.kind, .ingestOCR)
    }

    func testAIProcessingAttributes_CodableAndHashing() throws {
        let state = AIProcessingAttributes.ContentState(
            progress: 0.5,
            status: "处理中",
            kind: .voiceNote,
            sourceCount: 2,
            currentFileName: "会议录音.m4a",
            estimatedSecondsRemaining: 12
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AIProcessingAttributes.ContentState.self, from: data)

        XCTAssertEqual(decoded.progress, state.progress)
        XCTAssertEqual(decoded.status, state.status)
        XCTAssertEqual(decoded.kind, state.kind)
        XCTAssertEqual(decoded.sourceCount, state.sourceCount)
        XCTAssertEqual(decoded.currentFileName, state.currentFileName)
        XCTAssertEqual(decoded.estimatedSecondsRemaining, state.estimatedSecondsRemaining)
    }

    func testActivityService_LifecycleExecution() async {
        let service = ActivityService.shared
        let taskId = UUID()

        // 启动任务（即使在模拟器或无授权环境下，也应防御性优雅处理不崩溃）
        service.startActivity(id: taskId, name: "单元测试AI任务", target: "Vault_A")

        service.startActivity(
            id: taskId,
            name: "多参数AI任务",
            target: "Vault_B",
            kind: .synthesis,
            sourceCount: 3,
            currentFileName: "文档A.md",
            estimatedSecondsRemaining: 30
        )

        // 更新状态
        await service.updateProgress(
            id: taskId,
            progress: 0.75,
            message: "正在生成关键结论",
            sourceCount: 3,
            currentFileName: "文档B.md",
            estimatedSecondsRemaining: 10
        )

        // 结束活动
        await service.endActivity(id: taskId)

        // 幂等多次结束不应崩溃
        await service.endActivity(id: taskId)
        await service.endActivity(id: UUID())
        XCTAssertNotNil(service, "ActivityService 单例在生命周期操作后应保持有效")
    }
    func testiOSWatchSyncService_LifecycleAndMessaging() {
        let service = iOSWatchSyncService()
        XCTAssertNotNil(service)

        // 测试发送文本
        service.sendContent("同步测试知识卡片")

        // 测试请求每日简报
        service.requestDailyBriefing()

        // 测试处理简报响应
        service.handleBriefingResponse("今天有 3 篇待复习笔记。")

        // 测试发布的属性初始态
        XCTAssertFalse(service.isBriefingLoading)
    }

    func testDummyActivityService_NoOpCoverage() async {
        let dummy = DummyActivityService()
        let id = UUID()
        dummy.startActivity(id: id, name: "Test", target: "Target")
        dummy.startActivity(
            id: id,
            name: "Test",
            target: "Target",
            kind: .synthesis,
            sourceCount: 1,
            currentFileName: "A.md",
            estimatedSecondsRemaining: 5
        )
        await dummy.updateProgress(id: id, progress: 0.5, message: "Progress")
        await dummy.updateProgress(
            id: id,
            progress: 0.8,
            message: "Progress",
            sourceCount: 2,
            currentFileName: "B.md",
            estimatedSecondsRemaining: 2
        )
        await dummy.endActivity(id: id)
        XCTAssertNotNil(dummy, "Dummy 服务应安全完成空操作")
    }

}
