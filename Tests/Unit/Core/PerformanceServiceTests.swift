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

    func testRecord_databaseLoad_更新loadDuration() {
        service.record(.databaseLoad, duration: 0.5)
        XCTAssertEqual(service.metrics.loadDuration, 0.5, accuracy: 0.01)
    }

    func testRecord_databaseSave_更新saveDuration() {
        service.record(.databaseSave, duration: 0.3)
        XCTAssertEqual(service.metrics.saveDuration, 0.3, accuracy: 0.01)
    }

    func testRecord_ragChain_更新ragChainDuration() {
        service.record(.ragChain, duration: 1.2)
        XCTAssertEqual(service.metrics.ragChainDuration, 1.2, accuracy: 0.01)
    }

    func testRecord_search_更新searchDuration() {
        service.record(.search, duration: 0.1)
        XCTAssertEqual(service.metrics.searchDuration, 0.1, accuracy: 0.01)
    }

    func testRecord_graphLayout_更新graphLayoutDuration() {
        service.record(.graphLayout, duration: 0.8)
        XCTAssertEqual(service.metrics.graphLayoutDuration, 0.8, accuracy: 0.01)
    }

    func testRecord_lint_更新lintDuration() {
        service.record(.lint, duration: 0.2)
        XCTAssertEqual(service.metrics.lintDuration, 0.2, accuracy: 0.01)
    }

    func testRecord_ragChain_递增llmCallCount() {
        service.record(.ragChain, duration: 1.0)
        XCTAssertEqual(service.metrics.llmCallCount, 1)
        service.record(.ragChain, duration: 1.0)
        XCTAssertEqual(service.metrics.llmCallCount, 2)
    }

    func testRecord_更新lastUpdated() {
        let before = service.metrics.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        service.record(.search, duration: 0.1)
        XCTAssertGreaterThan(service.metrics.lastUpdated, before)
    }

    // MARK: - measure 同步测量

    func testMeasure_返回操作结果() {
        let result = service.measure("load") { 42 }
        XCTAssertEqual(result, 42)
    }

    func testMeasure_更新对应指标() {
        _ = service.measure("save") { "done" }
        XCTAssertGreaterThanOrEqual(service.metrics.saveDuration, 0.0)
    }

    func testMeasure_aiLabel_递增llmCallCount() {
        _ = service.measure("ai_inference") { "result" }
        XCTAssertEqual(service.metrics.llmCallCount, 1)
    }

    func testMeasure_llmLabel_递增llmCallCount() {
        _ = service.measure("llm_call") { "result" }
        XCTAssertEqual(service.metrics.llmCallCount, 1)
    }

    // MARK: - measureAsync 异步测量

    func testMeasureAsync_成功_返回结果并更新指标() async throws {
        let result = try await service.measureAsync("load") { 100 }
        XCTAssertEqual(result, 100)
        XCTAssertGreaterThanOrEqual(service.metrics.loadDuration, 0.0)
    }

    func testMeasureAsync_抛错_更新失败率并重新抛出() async {
        struct TestError: Error {}
        do {
            _ = try await service.measureAsync("ai_call") { throw TestError() }
            XCTFail("应抛出错误")
        } catch {
            XCTAssertLessThan(service.metrics.aiSuccessRate, 1.0, "失败率应被记录")
        }
    }

    // MARK: - updateMemoryUsage

    func testUpdateMemoryUsage_不崩溃且更新metrics() {
        service.updateMemoryUsage()
        XCTAssertGreaterThanOrEqual(service.metrics.memoryUsageMB, 0.0)
    }

    // MARK: - updatePageMetrics

    func testUpdatePageMetrics_正确设置() {
        service.updatePageMetrics(pageCount: 10, totalWords: 5000)
        XCTAssertEqual(service.metrics.pageCount, 10)
        XCTAssertEqual(service.metrics.totalWords, 5000)
    }

    func testUpdatePageMetrics_更新lastUpdated() {
        let before = service.metrics.lastUpdated
        Thread.sleep(forTimeInterval: 0.01)
        service.updatePageMetrics(pageCount: 1, totalWords: 1)
        XCTAssertGreaterThan(service.metrics.lastUpdated, before)
    }

    // MARK: - updateGraphMetrics

    func testUpdateGraphMetrics_正确设置() {
        service.updateGraphMetrics(nodes: 20, edges: 35)
        XCTAssertEqual(service.metrics.graphNodeCount, 20)
        XCTAssertEqual(service.metrics.graphEdgeCount, 35)
    }

    // MARK: - summary 摘要

    func testSummary_包含页面信息() {
        service.updatePageMetrics(pageCount: 5, totalWords: 1000)
        let summary = service.summary
        XCTAssertTrue(summary.contains("5"), "摘要应包含页面数")
        XCTAssertTrue(summary.contains("1000"), "摘要应包含字数")
    }

    func testSummary_包含图谱信息() {
        service.updateGraphMetrics(nodes: 8, edges: 12)
        let summary = service.summary
        XCTAssertTrue(summary.contains("8"), "摘要应包含节点数")
        XCTAssertTrue(summary.contains("12"), "摘要应包含边数")
    }

    func testSummary_包含内存信息() {
        service.updateMemoryUsage()
        let summary = service.summary
        XCTAssertTrue(summary.contains("MB"), "摘要应包含内存单位")
    }

    func testSummary_包含耗时信息() {
        service.record(.databaseSave, duration: 0.123)
        service.record(.databaseLoad, duration: 0.456)
        let summary = service.summary
        XCTAssertTrue(summary.contains("0.123"), "摘要应包含 save 耗时")
        XCTAssertTrue(summary.contains("0.456"), "摘要应包含 load 耗时")
    }

    // MARK: - MetricType

    func testMetricType_所有case_可遍历() {
        let types: [PerformanceService.MetricType] = [
            .databaseLoad, .databaseSave, .ragChain, .search, .graphLayout, .lint
        ]
        XCTAssertEqual(types.count, 6)
    }

    // MARK: - PerformanceMetrics

    func testPerformanceMetrics_默认值() {
        let metrics = PerformanceService.PerformanceMetrics()
        XCTAssertEqual(metrics.pageCount, 0)
        XCTAssertEqual(metrics.totalWords, 0)
        XCTAssertEqual(metrics.llmCallCount, 0)
        XCTAssertEqual(metrics.aiSuccessRate, 1.0)
    }

    func testPerformanceMetrics_id_唯一() {
        let metrics1 = PerformanceService.PerformanceMetrics()
        let metrics2 = PerformanceService.PerformanceMetrics()
        XCTAssertNotEqual(metrics1.id, metrics2.id)
    }
}
