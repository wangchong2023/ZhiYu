//
//  AppConfigTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 AppConfig 配置加载器的默认值回退、动态读取与类型安全。
//

import XCTest
@testable import ZhiYu

final class AppConfigTests: XCTestCase {

    // MARK: - 网络配置

    func testProductionURLReturnsString() {
        let url = AppConfig.productionURL
        XCTAssertFalse(url.isEmpty == false && url.contains(" "), "productionURL 应为合法 URL 或空字符串")
    }

    func testJinaReaderURLReturnsString() {
        let url = AppConfig.jinaReaderURL
        XCTAssertTrue(url.isEmpty || url.hasPrefix("http"), "jinaReaderURL 应为 URL 或空")
    }

    func testBackendBaseURLReturnsString() {
        let url = AppConfig.backendBaseURL
        XCTAssertTrue(url.isEmpty || url.hasPrefix("http"), "backendBaseURL 应为 URL 或空")
    }

    func testOllamaDefaultURLReturnsString() {
        let url = AppConfig.ollamaDefaultURL
        XCTAssertTrue(url.isEmpty || url.hasPrefix("http"), "ollamaDefaultURL 应为 URL 或空")
    }

    func testDeepseekDefaultURLReturnsString() {
        let url = AppConfig.deepseekDefaultURL
        XCTAssertTrue(url.isEmpty || url.hasPrefix("http"), "deepseekDefaultURL 应为 URL 或空")
    }

    // MARK: - 性能参数默认值

    func testSearchDebounceMSHasReasonableDefault() {
        let ms = AppConfig.searchDebounceMS
        XCTAssertGreaterThanOrEqual(ms, 0, "searchDebounceMS 应为非负整数")
        XCTAssertLessThanOrEqual(ms, 10000, "searchDebounceMS 应在合理范围内")
    }

    func testRerankTopLimitHasReasonableDefault() {
        let limit = AppConfig.rerankTopLimit
        XCTAssertGreaterThanOrEqual(limit, 1, "rerankTopLimit 应 >= 1")
    }

    func testMaxLogEntriesHasReasonableDefault() {
        let entries = AppConfig.maxLogEntries
        XCTAssertGreaterThanOrEqual(entries, 1, "maxLogEntries 应 >= 1")
    }

    // MARK: - 存储文件名

    func testLogsFileNameReturnsString() {
        let name = AppConfig.logsFileName
        XCTAssertTrue(name.isEmpty || name.hasSuffix(".json"), "logsFileName 应为 JSON 文件名或空")
    }

    func testPagesFileNameReturnsString() {
        let name = AppConfig.pagesFileName
        XCTAssertTrue(name.isEmpty || name.hasSuffix(".json"), "pagesFileName 应为 JSON 文件名或空")
    }

    func testSqliteFileNameReturnsString() {
        let name = AppConfig.sqliteFileName
        XCTAssertTrue(name.isEmpty || name.hasSuffix(".sqlite") || name.hasSuffix(".sqlite3"), "sqliteFileName 应为 SQLite 文件名或空")
    }

    // MARK: - AI 检索阈值

    func testDefaultTemperatureInReasonableRange() {
        let temp = AppConfig.AI.defaultTemperature
        XCTAssertGreaterThanOrEqual(temp, 0.0, "temperature 应 >= 0")
        XCTAssertLessThanOrEqual(temp, 2.0, "temperature 应 <= 2")
    }

    func testSimilarityThresholdInReasonableRange() {
        let threshold = AppConfig.AI.similarityThreshold
        XCTAssertGreaterThanOrEqual(threshold, 0.0, "similarityThreshold 应 >= 0")
        XCTAssertLessThanOrEqual(threshold, 1.0, "similarityThreshold 应 <= 1")
    }

    func testTopKResultsIsPositiveInteger() {
        let k = AppConfig.AI.topKResults
        XCTAssertGreaterThanOrEqual(k, 1, "topKResults 应 >= 1")
    }

    func testRerankScoreThresholdInReasonableRange() {
        let threshold = AppConfig.AI.rerankScoreThreshold
        XCTAssertGreaterThanOrEqual(threshold, 0.0, "rerankScoreThreshold 应 >= 0")
        XCTAssertLessThanOrEqual(threshold, 1.0, "rerankScoreThreshold 应 <= 1")
    }

    func testMaxContextLengthIsPositiveInteger() {
        let len = AppConfig.AI.maxContextLength
        XCTAssertGreaterThanOrEqual(len, 100, "maxContextLength 应 >= 100")
    }

    func testPreviewTextLengthIsPositiveInteger() {
        let len = AppConfig.AI.previewTextLength
        XCTAssertGreaterThanOrEqual(len, 50, "previewTextLength 应 >= 50")
    }

    func testEvaluatorModelNonEmpty() {
        let model = AppConfig.AI.evaluatorModel
        XCTAssertFalse(model.isEmpty, "evaluatorModel 不应为空")
    }

    func testDefaultModelNonEmpty() {
        let model = AppConfig.AI.defaultModel
        XCTAssertFalse(model.isEmpty, "defaultModel 不应为空")
    }

    // MARK: - RAG 评估常量

    func testEvaluationHitKIs5() {
        XCTAssertEqual(AppConfig.AI.evaluationHitK, 5)
    }

    func testEvaluationNDCGKIs10() {
        XCTAssertEqual(AppConfig.AI.evaluationNDCGK, 10)
    }

    func testEvaluationRecallKIs5() {
        XCTAssertEqual(AppConfig.AI.evaluationRecallK, 5)
    }

    // MARK: - 成本估算参数

    func testPricingPromptPer1MIs2Point5() {
        XCTAssertEqual(AppConfig.AI.pricingPromptPer1M, 2.50, accuracy: 0.01)
    }

    func testPricingCompletionPer1MIs10() {
        XCTAssertEqual(AppConfig.AI.pricingCompletionPer1M, 10.00, accuracy: 0.01)
    }

    // MARK: - UI 交互常量

    func testGraphLODZoomThresholdInReasonableRange() {
        XCTAssertGreaterThanOrEqual(AppConfig.UI.graphLODZoomThreshold, 0.0)
        XCTAssertLessThanOrEqual(AppConfig.UI.graphLODZoomThreshold, 1.0)
    }

    func testAnimationDurationIs0Point3() {
        XCTAssertEqual(AppConfig.UI.animationDuration, 0.3, accuracy: 0.01)
    }

    func testGlassOpacityInReasonableRange() {
        XCTAssertGreaterThanOrEqual(AppConfig.UI.glassOpacity, 0.0)
        XCTAssertLessThanOrEqual(AppConfig.UI.glassOpacity, 1.0)
    }

    // MARK: - 插件安全

    func testPluginTimeoutLimitIsPositive() {
        XCTAssertGreaterThan(AppConfig.pluginTimeoutLimit, 0.0)
    }

    // MARK: - 动态加载器

    func testLLMProviderURLUnknownProviderReturnsEmpty() {
        let url = AppConfig.llmProviderURL(for: "nonexistent_provider")
        XCTAssertTrue(url.isEmpty, "未知 provider 应返回空字符串")
    }

    func testCdnResourceUnknownResourceReturnsEmpty() {
        let url = AppConfig.cdnResource("nonexistent_resource")
        XCTAssertTrue(url.isEmpty, "未知 CDN 资源应返回空字符串")
    }
}
