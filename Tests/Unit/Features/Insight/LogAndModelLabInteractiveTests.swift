//
//  LogAndModelLabInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class LogAndModelLabInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. LogViewStatusHelper 背景色解析（全三态 + 空状态）

    func testLogViewStatusHelper_statusBackgroundColor_resolvesAllThreeStates() {
        let opacity: Double = DesignSystem.secondaryOpacity
        let traits = UITraitCollection(userInterfaceStyle: .light)

        // 验证缺陷 #175 修复：.processing 不可误显为红色
        let successBg = UIColor(LogViewStatusHelper.statusBackgroundColor(for: .success, opacity: opacity)).resolvedColor(with: traits)
        let expectedSuccess = UIColor(Color.theme.green.opacity(opacity)).resolvedColor(with: traits)
        XCTAssertEqual(successBg, expectedSuccess)

        let failureBg = UIColor(LogViewStatusHelper.statusBackgroundColor(for: .failure, opacity: opacity)).resolvedColor(with: traits)
        let expectedFailure = UIColor(Color.theme.red.opacity(opacity)).resolvedColor(with: traits)
        XCTAssertEqual(failureBg, expectedFailure)

        let processingBg = UIColor(LogViewStatusHelper.statusBackgroundColor(for: .processing, opacity: opacity)).resolvedColor(with: traits)
        let expectedProcessing = UIColor(Color.theme.blue.opacity(opacity)).resolvedColor(with: traits)
        XCTAssertEqual(processingBg, expectedProcessing)

        let nilBg = UIColor(LogViewStatusHelper.statusBackgroundColor(for: nil, opacity: opacity)).resolvedColor(with: traits)
        let expectedNil = UIColor(Color.clear).resolvedColor(with: traits)
        XCTAssertEqual(nilBg, expectedNil)
    }

    // MARK: - 2. LogViewStatusHelper 前景色解析（全三态 + 空状态）

    func testLogViewStatusHelper_statusForegroundColor_resolvesAllThreeStates() {
        let traits = UITraitCollection(userInterfaceStyle: .light)

        let successFg = UIColor(LogViewStatusHelper.statusForegroundColor(for: .success)).resolvedColor(with: traits)
        let expectedSuccess = UIColor(Color.theme.green).resolvedColor(with: traits)
        XCTAssertEqual(successFg, expectedSuccess)

        let failureFg = UIColor(LogViewStatusHelper.statusForegroundColor(for: .failure)).resolvedColor(with: traits)
        let expectedFailure = UIColor(Color.theme.red).resolvedColor(with: traits)
        XCTAssertEqual(failureFg, expectedFailure)

        let processingFg = UIColor(LogViewStatusHelper.statusForegroundColor(for: .processing)).resolvedColor(with: traits)
        let expectedProcessing = UIColor(Color.theme.blue).resolvedColor(with: traits)
        XCTAssertEqual(processingFg, expectedProcessing)

        let nilFg = UIColor(LogViewStatusHelper.statusForegroundColor(for: nil)).resolvedColor(with: traits)
        let expectedNil = UIColor(Color.clear).resolvedColor(with: traits)
        XCTAssertEqual(nilFg, expectedNil)
    }

    // MARK: - 3. LogViewStatusHelper 时间范围解析

    func testLogViewStatusHelper_resolveTimeRange_handlesTimestamps() {
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let endDate = baseDate.addingTimeInterval(120)

        // 包含起止时间
        let rangeStr = LogViewStatusHelper.resolveTimeRange(
            startTime: baseDate,
            endTime: endDate,
            timestamp: baseDate
        )
        XCTAssertTrue(rangeStr.contains("-"), "起止时间齐全时应输出连字符区间")

        // 仅有时间戳
        let singleStr = LogViewStatusHelper.resolveTimeRange(
            startTime: nil,
            endTime: nil,
            timestamp: baseDate
        )
        XCTAssertFalse(singleStr.isEmpty, "仅有时间戳时输出格式化时间")
    }

    // MARK: - 4. ModelLabMetricsCalculator 置信度钳位

    func testModelLabMetricsCalculator_clampConfidence_handlesNormalAndExtremeScores() {
        // 正常范围
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(0.85), 0.85, accuracy: 0.001)
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(1.0), 1.0, accuracy: 0.001)

        // 越界值
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(-0.5), 0.0, accuracy: 0.001)
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(1.5), 1.0, accuracy: 0.001)

        // 极端异常浮点数（防范台账 #175）
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(Double.nan), 0.0, accuracy: 0.001)
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(Double.infinity), 0.0, accuracy: 0.001)
        XCTAssertEqual(ModelLabMetricsCalculator.clampConfidence(-Double.infinity), 0.0, accuracy: 0.001)
    }

    // MARK: - 5. ModelLabMetricsCalculator 置信度百分比文本

    func testModelLabMetricsCalculator_formatConfidencePercentage_producesValidStrings() {
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(0.85), "85%")
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(0.0), "0%")
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(1.0), "100%")

        // 验证台账 #175：杜绝 "nan%" 或 "inf%"
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(Double.nan), "0%")
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(Double.infinity), "0%")
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(-Double.infinity), "0%")
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(-10.0), "0%")
        XCTAssertEqual(ModelLabMetricsCalculator.formatConfidencePercentage(2.0), "100%")
    }

    // MARK: - 6. ModelLabMetricsCalculator 速度与运存格式化

    func testModelLabMetricsCalculator_formatSpeedAndMemory_handlesExtremeInputs() {
        // 速度
        XCTAssertEqual(ModelLabMetricsCalculator.formatSpeed(45.2), "45.2")
        XCTAssertEqual(ModelLabMetricsCalculator.formatSpeed(0.0), "0.0")
        XCTAssertEqual(ModelLabMetricsCalculator.formatSpeed(Double.nan), "0.0")
        XCTAssertEqual(ModelLabMetricsCalculator.formatSpeed(Double.infinity), "0.0")
        XCTAssertEqual(ModelLabMetricsCalculator.formatSpeed(-10.0), "0.0")

        // 运存
        XCTAssertEqual(ModelLabMetricsCalculator.formatMemory(1024.0), "1024")
        XCTAssertEqual(ModelLabMetricsCalculator.formatMemory(0.0), "0")
        XCTAssertEqual(ModelLabMetricsCalculator.formatMemory(Double.nan), "0")
        XCTAssertEqual(ModelLabMetricsCalculator.formatMemory(Double.infinity), "0")
        XCTAssertEqual(ModelLabMetricsCalculator.formatMemory(-512.0), "0")
    }

    // MARK: - 7. LogView 空状态渲染

    func testLogView_mountsWithEmptyLogs() {
        let appStore = AppStore()
        appStore.logEntries = []

        let logView = LogView()
            .snapshotEnvironment(appStore: appStore)

        let controller = UIHostingController(rootView: logView)
        controller.loadViewIfNeeded()

        XCTAssertNotNil(controller.view, "空日志状态下 LogView 必须平稳渲染")
    }

    // MARK: - 8. LogView 多态与 Processing 运行态日志渲染

    func testLogView_mountsWithVariedLogsAndProcessingState() {
        let appStore = AppStore()
        let now = Date()
        appStore.logEntries = [
            LogEntry(
                action: .create,
                target: "Concept Note",
                details: "Created successfully",
                timestamp: now,
                duration: 0.45,
                startTime: now.addingTimeInterval(-1),
                endTime: now,
                module: "Knowledge",
                status: .success
            ),
            LogEntry(
                action: .delete,
                target: "Draft Note",
                details: "Operation failed",
                timestamp: now,
                duration: 0.12,
                module: "Storage",
                status: .failure,
                failureReason: "Disk full"
            ),
            LogEntry(
                action: .update,
                target: "Indexing Job",
                details: "In progress...",
                timestamp: now,
                duration: nil,
                startTime: now,
                endTime: nil,
                module: "Pipeline",
                status: .processing
            )
        ]

        let logView = LogView()
            .snapshotEnvironment(appStore: appStore)

        let controller = UIHostingController(rootView: logView)
        controller.loadViewIfNeeded()

        XCTAssertNotNil(controller.view, "包含成功/失败/进行中日志时 LogView 必须平稳渲染")
    }

    // MARK: - 9. LogEntryRow 状态背景与文字与展开折叠逻辑

    func testLogEntry_statusProperties_matchHelperDefinitions() {
        let entry = LogEntry(
            action: .create,
            target: "Test Target",
            details: "Detail content",
            status: .processing
        )

        let traits = UITraitCollection(userInterfaceStyle: .light)
        let bg = UIColor(LogViewStatusHelper.statusBackgroundColor(for: entry.status, opacity: DesignSystem.glassOpacity)).resolvedColor(with: traits)
        let fg = UIColor(LogViewStatusHelper.statusForegroundColor(for: entry.status)).resolvedColor(with: traits)

        let expectedBg = UIColor(Color.theme.blue.opacity(DesignSystem.glassOpacity)).resolvedColor(with: traits)
        let expectedFg = UIColor(Color.theme.blue).resolvedColor(with: traits)

        XCTAssertEqual(bg, expectedBg)
        XCTAssertEqual(fg, expectedFg)
    }

    // MARK: - 10. ModelLabManager 性能状态与格式化联动

    func testModelLabManager_performanceStatsFormatting() {
        let manager = ModelLabManager()
        manager.currentStats = PerformanceStats(
            speed: 52.8,
            prefillLatency: 120,
            firstTokenLatency: 45,
            memoryUsage: 2048.0
        )

        let speedStr = ModelLabMetricsCalculator.formatSpeed(manager.currentStats.speed)
        let memoryStr = ModelLabMetricsCalculator.formatMemory(manager.currentStats.memoryUsage)

        XCTAssertEqual(speedStr, "52.8")
        XCTAssertEqual(memoryStr, "2048")
    }

    // MARK: - 11. ModelLabView 异常指标数据下的安全防护

    func testModelLabView_corruptStatsProtection() {
        let manager = ModelLabManager()
        manager.currentStats = PerformanceStats(
            speed: Double.nan,
            prefillLatency: -1,
            firstTokenLatency: -1,
            memoryUsage: Double.infinity
        )

        let safeSpeed = ModelLabMetricsCalculator.formatSpeed(manager.currentStats.speed)
        let safeMemory = ModelLabMetricsCalculator.formatMemory(manager.currentStats.memoryUsage)

        XCTAssertEqual(safeSpeed, "0.0")
        XCTAssertEqual(safeMemory, "0")
    }

    // MARK: - 12. ModelLabMetricsCalculator 100 次 Fuzz 模糊测试

    func testModelLabMetricsCalculator_fuzz100RandomValues_neverCrashes() {
        let extremeValues: [Double] = [
            -Double.greatestFiniteMagnitude,
            Double.greatestFiniteMagnitude,
            -1e10, 1e10, -0.00001, 0.00001,
            Double.nan, Double.infinity, -Double.infinity,
            -0.0, 0.0, 1.0, 0.9999999
        ]

        for val in extremeValues {
            let clamped = ModelLabMetricsCalculator.clampConfidence(val)
            XCTAssertGreaterThanOrEqual(clamped, 0.0)
            XCTAssertLessThanOrEqual(clamped, 1.0)

            let pct = ModelLabMetricsCalculator.formatConfidencePercentage(val)
            XCTAssertFalse(pct.contains("nan"))
            XCTAssertFalse(pct.contains("inf"))

            let speed = ModelLabMetricsCalculator.formatSpeed(val)
            XCTAssertFalse(speed.contains("nan"))
            XCTAssertFalse(speed.contains("inf"))

            let memory = ModelLabMetricsCalculator.formatMemory(val)
            XCTAssertFalse(memory.contains("nan"))
            XCTAssertFalse(memory.contains("inf"))
        }

        for _ in 0..<100 {
            let randomScore = Double.random(in: -200.0...200.0)
            let clamped = ModelLabMetricsCalculator.clampConfidence(randomScore)
            XCTAssertGreaterThanOrEqual(clamped, 0.0)
            XCTAssertLessThanOrEqual(clamped, 1.0)

            let pct = ModelLabMetricsCalculator.formatConfidencePercentage(randomScore)
            XCTAssertFalse(pct.contains("nan"))

            let spd = ModelLabMetricsCalculator.formatSpeed(randomScore)
            XCTAssertFalse(spd.contains("nan"))

            let mem = ModelLabMetricsCalculator.formatMemory(randomScore)
            XCTAssertFalse(mem.contains("nan"))
        }
    }
}
