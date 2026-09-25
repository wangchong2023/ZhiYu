//
//  PerformanceServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 PerformanceService 性能监控的 record/measure/measureAsync/内存更新/摘要生成。
//

import XCTest
@testable import ZhiYu

@MainActor
final class PerformanceServiceTests: XCTestCase {

    private var service: PerformanceService!

    override func setUp() {
        super.setUp()
        service = PerformanceService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - record 耗时记录

    func testRecordDatabaseLoadUpdatesLoadDuration() {
        service.record(.databaseLoad, duration: 0.5)
        XCTAssertEqual(service.metrics.loadDuration, 0.5, accuracy: 0.01)
    }

    func testRecordDatabaseSaveUpdatesSaveDuration() {
        service.record(.databaseSave, duration: 0.3)
        XCTAssertEqual(service.metrics.saveDuration, 0.3, accuracy: 0.01)
    }

    func testRecordRagChainUpdatesRagChainDuration() {
        service.record(.ragChain, duration: 1.2)
        XCTAssertEqual(service.metrics.ragChainDuration, 1.2, accuracy: 0.01)
    }

    func testRecordSearchUpdatesSearchDuration() {
        service.record(.search, duration: 0.1)
        XCTAssertEqual(service.metrics.searchDuration, 0.1, accuracy: 0.01)
    }

    func testRecordGraphLayoutUpdatesGraphLayoutDuration() {
        service.record(.graphLayout, duration: 0.8)
        XCTAssertEqual(service.metrics.graphLayoutDuration, 0.8, accuracy: 0.01)
    }

    func testRecordLintUpdatesLintDuration() {
        service.record(.lint, duration: 0.2)
        XCTAssertEqual(service.metrics.lintDuration, 0.2, accuracy: 0.01)
    }

    func testRecordRagChainIncrementsLlmCallCount() {
        service.record(.ragChain, duration: 1.0)
        XCTAssertEqual(service.metrics.llmCallCount, 1)
        service.record(.ragChain, duration: 1.0)
        XCTAssertEqual(service.metrics.llmCallCount, 2)
    }

    func testRecordUpdatesLastUpdated() {
        let before = service.metrics.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        service.record(.search, duration: 0.1)
        XCTAssertGreaterThan(service.metrics.lastUpdated, before)
    }

    // MARK: - measure 同步测量

    func testMeasureReturnsOperationResult() {
        let result = service.measure("load") { 42 }
        XCTAssertEqual(result, 42)
    }

    func testMeasureUpdatesCorrespondingMetric() {
        _ = service.measure("save") { "done" }
        XCTAssertGreaterThanOrEqual(service.metrics.saveDuration, 0.0)
    }

    func testMeasureAiLabelIncrementsLlmCallCount() {
        _ = service.measure("ai_inference") { "result" }
        XCTAssertEqual(service.metrics.llmCallCount, 1)
    }

    func testMeasureLlmLabelIncrementsLlmCallCount() {
        _ = service.measure("llm_call") { "result" }
        XCTAssertEqual(service.metrics.llmCallCount, 1)
    }

    // MARK: - measureAsync 异步测量

    func testMeasureAsyncSuccessReturnsResultAndUpdatesMetric() async throws {
        let result = try await service.measureAsync("load") { 100 }
        XCTAssertEqual(result, 100)
        XCTAssertGreaterThanOrEqual(service.metrics.loadDuration, 0.0)
    }

    func testMeasureAsyncThrowsUpdatesFailureRateAndRethrows() async {
        struct TestError: Error {}
        do {
            _ = try await service.measureAsync("ai_call") { throw TestError() }
            XCTFail("应抛出错误")
        } catch {
            XCTAssertLessThan(service.metrics.aiSuccessRate, 1.0, "失败率应被记录")
        }
    }

    // MARK: - updateMemoryUsage

    func testUpdateMemoryUsageNoCrashAndUpdatesMetrics() {
        service.updateMemoryUsage()
        XCTAssertGreaterThanOrEqual(service.metrics.memoryUsageMB, 0.0)
    }

    // MARK: - updatePageMetrics

    func testUpdatePageMetricsCorrectlySets() {
        service.updatePageMetrics(pageCount: 10, totalWords: 5000)
        XCTAssertEqual(service.metrics.pageCount, 10)
        XCTAssertEqual(service.metrics.totalWords, 5000)
    }

    func testUpdatePageMetricsUpdatesLastUpdated() {
        let before = service.metrics.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        service.updatePageMetrics(pageCount: 1, totalWords: 1)
        XCTAssertGreaterThan(service.metrics.lastUpdated, before)
    }

    // MARK: - updateGraphMetrics

    func testUpdateGraphMetricsCorrectlySets() {
        service.updateGraphMetrics(nodes: 20, edges: 35)
        XCTAssertEqual(service.metrics.graphNodeCount, 20)
        XCTAssertEqual(service.metrics.graphEdgeCount, 35)
    }

    // MARK: - summary 摘要

    func testSummaryContainsPageInfo() {
        service.updatePageMetrics(pageCount: 5, totalWords: 1000)
        let summary = service.summary
        XCTAssertTrue(summary.contains("5"), "摘要应包含页面数")
        XCTAssertTrue(summary.contains("1000"), "摘要应包含字数")
    }

    func testSummaryContainsGraphInfo() {
        service.updateGraphMetrics(nodes: 8, edges: 12)
        let summary = service.summary
        XCTAssertTrue(summary.contains("8"), "摘要应包含节点数")
        XCTAssertTrue(summary.contains("12"), "摘要应包含边数")
    }

    func testSummaryContainsMemoryInfo() {
        service.updateMemoryUsage()
        let summary = service.summary
        XCTAssertTrue(summary.contains("MB"), "摘要应包含内存单位")
    }

    func testSummaryContainsDurationInfo() {
        service.record(.databaseSave, duration: 0.123)
        service.record(.databaseLoad, duration: 0.456)
        let summary = service.summary
        XCTAssertTrue(summary.contains("0.123"), "摘要应包含 save 耗时")
        XCTAssertTrue(summary.contains("0.456"), "摘要应包含 load 耗时")
    }

    // MARK: - MetricType

    func testMetricTypeAllCasesTraversable() {
        let types: [PerformanceService.MetricType] = [
            .databaseLoad, .databaseSave, .ragChain, .search, .graphLayout, .lint
        ]
        XCTAssertEqual(types.count, 6)
    }

    // MARK: - PerformanceMetrics

    func testPerformanceMetricsDefaultValues() {
        let metrics = PerformanceService.PerformanceMetrics()
        XCTAssertEqual(metrics.pageCount, 0)
        XCTAssertEqual(metrics.totalWords, 0)
        XCTAssertEqual(metrics.llmCallCount, 0)
        XCTAssertEqual(metrics.aiSuccessRate, 1.0)
    }

    func testPerformanceMetricsIdUnique() {
        let metrics1 = PerformanceService.PerformanceMetrics()
        let metrics2 = PerformanceService.PerformanceMetrics()
        XCTAssertNotEqual(metrics1.id, metrics2.id)
    }
}
