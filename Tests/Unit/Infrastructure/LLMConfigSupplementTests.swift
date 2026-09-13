//
//  LLMConfigSupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 测试层
//  核心职责：补盲 Infrastructure/LLM 配置与统计服务（LLMConfigManager、
//           InferenceParametersStore、AIAnalyticsService）的未覆盖分支与边界条件
//           （属性 getter/setter、isReady 判定、refresh handler 触发、
//           持久化编解码、排序、删除、清空、RAG 指标记录）。
//

import XCTest
import UFPCore
import Dependencies
import Combine
@testable import ZhiYu

// MARK: - LLMConfigManager 补盲测试

@MainActor
final class LLMConfigManagerSupplementTests: XCTestCase {

    private var config: LLMConfigManager!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        UserDefaults.standard.removeObject(forKey: "zhiyu_llm_config")
        config = LLMConfigManager()
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)
    }

    override func tearDown() async throws {
        config = nil
        UserDefaults.standard.removeObject(forKey: "zhiyu_llm_config")
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testAutoScanGetterSetter() {
        XCTAssertTrue(config.autoScan, "默认 autoScan 应为 true")
        config.autoScan = false
        XCTAssertFalse(config.autoScan, "设置后 autoScan 应为 false")
        config.autoScan = true
        XCTAssertTrue(config.autoScan)
    }

    func testAutoRefactorGetterSetter() {
        XCTAssertFalse(config.autoRefactor, "默认 autoRefactor 应为 false")
        config.autoRefactor = true
        XCTAssertTrue(config.autoRefactor)
        config.autoRefactor = false
        XCTAssertFalse(config.autoRefactor)
    }

    func testIsReadyTrueWhenEnabledAndApiKeySet() {
        config.isEnabled = true
        config.apiKey = "sk-test-key-123456789012345678901234567890"
        XCTAssertTrue(config.isReady, "isEnabled=true 且 apiKey 非空时 isReady 应为 true")
    }

    func testIsReadyFalseWhenDisabled() {
        config.isEnabled = false
        config.apiKey = "sk-test-key"
        XCTAssertFalse(config.isReady, "isEnabled=false 时 isReady 应为 false")
    }

    func testIsReadyFalseWhenApiKeyEmpty() {
        config.isEnabled = true
        config.apiKey = ""
        XCTAssertFalse(config.isReady, "apiKey 为空时 isReady 应为 false")
    }

    func testMultipleRefreshHandlersAllInvoked() {
        var count1 = 0
        var count2 = 0
        var count3 = 0
        config.setRefreshHandler { count1 += 1 }
        config.setRefreshHandler { count2 += 1 }
        config.setRefreshHandler { count3 += 1 }

        config.apiKey = "new-key"

        XCTAssertEqual(count1, 1, "第一个 handler 应被触发")
        XCTAssertEqual(count2, 1, "第二个 handler 应被触发")
        XCTAssertEqual(count3, 1, "第三个 handler 应被触发")
    }

    func testProviderChangeTriggersRefreshHandlers() {
        var refreshCount = 0
        config.setRefreshHandler { refreshCount += 1 }
        config.provider = .zhipu
        XCTAssertGreaterThan(refreshCount, 0, "切换 provider 应触发 refresh handler")
    }

    func testBaseURLChangeTriggersRefreshHandlers() {
        var refreshCount = 0
        config.setRefreshHandler { refreshCount += 1 }
        config.baseURL = "https://new.api.com"
        XCTAssertGreaterThan(refreshCount, 0, "修改 baseURL 应触发 refresh handler")
    }

    func testModelChangeTriggersRefreshHandlers() {
        var refreshCount = 0
        config.setRefreshHandler { refreshCount += 1 }
        config.model = "new-model"
        XCTAssertGreaterThan(refreshCount, 0, "修改 model 应触发 refresh handler")
    }

    func testIsEnabledChangeTriggersRefreshHandlers() {
        var refreshCount = 0
        config.setRefreshHandler { refreshCount += 1 }
        config.isEnabled = true
        XCTAssertGreaterThan(refreshCount, 0, "修改 isEnabled 应触发 refresh handler")
    }
}

// MARK: - InferenceParametersStore 补盲测试

@MainActor
final class InferenceParametersStoreSupplementTests: XCTestCase {

    private let userDefaultsKey = "ZhiYu.InferenceParameters"

    override func setUp() async throws {
        try await super.setUp()
        InferenceParametersStore.shared.clearAll()
    }

    override func tearDown() async throws {
        InferenceParametersStore.shared.clearAll()
        try await super.tearDown()
    }

    func testLoadCacheHandlesCorruptedJSONGracefully() {
        UserDefaults.standard.set(Data("invalid json data".utf8), forKey: userDefaultsKey)
        let store = InferenceParametersStore.shared
        let result = store.allConfigurations()
        XCTAssertTrue(result.isEmpty, "损坏的 JSON 数据应被清空，allConfigurations 返回空数组")
    }

    func testSaveAndLoadMultipleConfigurations() {
        let config1 = InferenceParametersConfig(
            modelId: "model-a", presetName: "creative",
            temperature: 1.5, topP: 0.9, topK: 50, maxTokens: 2048
        )
        let config2 = InferenceParametersConfig(
            modelId: "model-b", presetName: "precise",
            temperature: 0.3, topP: 0.95, topK: 20, maxTokens: 1024
        )
        InferenceParametersStore.shared.saveParameters(config1)
        InferenceParametersStore.shared.saveParameters(config2)

        let loaded1 = InferenceParametersStore.shared.loadParameters(for: "model-a")
        let loaded2 = InferenceParametersStore.shared.loadParameters(for: "model-b")

        XCTAssertEqual(loaded1?.presetName, "creative")
        XCTAssertEqual(loaded1?.temperature, 1.5)
        XCTAssertEqual(loaded2?.presetName, "precise")
        XCTAssertEqual(loaded2?.maxTokens, 1024)
    }

    func testAllConfigurationsSortedByUpdatedAtDescending() {
        let earlyDate = Date(timeIntervalSince1970: 1000)
        let lateDate = Date(timeIntervalSince1970: 2000)

        let earlyConfig = InferenceParametersConfig(
            modelId: "early", presetName: "balanced",
            temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1000, updatedAt: earlyDate
        )
        let lateConfig = InferenceParametersConfig(
            modelId: "late", presetName: "balanced",
            temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1000, updatedAt: lateDate
        )

        InferenceParametersStore.shared.saveParameters(earlyConfig)
        InferenceParametersStore.shared.saveParameters(lateConfig)

        let all = InferenceParametersStore.shared.allConfigurations()
        XCTAssertEqual(all.first?.modelId, "late", "最新更新的配置应排在第一位")
        XCTAssertEqual(all.last?.modelId, "early")
    }

    func testDeleteParametersRemovesSpecificModel() {
        let config = InferenceParametersConfig(
            modelId: "to-delete", presetName: "custom",
            temperature: 0.5, topP: 0.8, topK: 30, maxTokens: 500
        )
        InferenceParametersStore.shared.saveParameters(config)
        XCTAssertNotNil(InferenceParametersStore.shared.loadParameters(for: "to-delete"))

        InferenceParametersStore.shared.deleteParameters(for: "to-delete")
        XCTAssertNil(InferenceParametersStore.shared.loadParameters(for: "to-delete"))
    }

    func testClearAllRemovesEverything() {
        let config = InferenceParametersConfig(
            modelId: "clear-test", presetName: "balanced",
            temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1000
        )
        InferenceParametersStore.shared.saveParameters(config)
        XCTAssertFalse(InferenceParametersStore.shared.allConfigurations().isEmpty)

        InferenceParametersStore.shared.clearAll()
        XCTAssertTrue(InferenceParametersStore.shared.allConfigurations().isEmpty)
        XCTAssertNil(UserDefaults.standard.data(forKey: userDefaultsKey))
    }
}

// MARK: - AIAnalyticsService 补盲测试

@MainActor
final class AIAnalyticsServiceSupplementTests: XCTestCase {

    func testRecordUsageDoesNotCrashWithMissingUsageField() {
        let service = AIAnalyticsService()
        XCTAssertTrue(TestModeDetector.isUnitTesting, "单测环境防护开启")
        service.recordUsage(model: "test", response: [:], latency: 100)
    }

    func testRecordUsageDoesNotCrashWithMissingPromptTokens() {
        let service = AIAnalyticsService()
        XCTAssertTrue(TestModeDetector.isUnitTesting)
        service.recordUsage(model: "test", response: ["usage": [:]], latency: 100)
    }

    func testRecordUsageDoesNotCrashWithNonIntTokens() {
        let service = AIAnalyticsService()
        XCTAssertTrue(TestModeDetector.isUnitTesting)
        service.recordUsage(
            model: "test",
            response: ["usage": ["prompt_tokens": "not-an-int", "completion_tokens": 5]],
            latency: 100
        )
    }

    func testRecordUsageDoesNotCrashWithValidUsageInTestMode() {
        let service = AIAnalyticsService()
        XCTAssertTrue(TestModeDetector.isUnitTesting)
        service.recordUsage(
            model: "test",
            response: ["usage": ["prompt_tokens": 10, "completion_tokens": 5]],
            latency: 100
        )
    }

    func testRecordRAGMetricsDoesNotCrashWithNilSources() {
        let service = AIAnalyticsService()
        XCTAssertTrue(TestModeDetector.isUnitTesting)
        service.recordRAGMetrics(
            query: "测试查询",
            response: "测试响应",
            context: "测试上下文",
            sources: nil,
            systemPrompt: "系统提示",
            modelName: "test-model",
            latency: 50
        )
    }

    func testRecordRAGMetricsDoesNotCrashWithEmptySources() {
        let service = AIAnalyticsService()
        XCTAssertTrue(TestModeDetector.isUnitTesting)
        service.recordRAGMetrics(
            query: "测试查询",
            response: "测试响应",
            context: "测试上下文",
            sources: [],
            systemPrompt: "系统提示",
            modelName: "test-model",
            latency: 50
        )
    }

    func testRecordRAGMetricsDoesNotCrashWithNonEmptySources() {
        let service = AIAnalyticsService()
        let source = KnowledgeSource(
            pageID: UUID(),
            title: "测试来源",
            snippet: "引用片段",
            score: 0.9
        )
        XCTAssertTrue(TestModeDetector.isUnitTesting)
        service.recordRAGMetrics(
            query: "测试查询",
            response: "测试响应",
            context: "测试上下文",
            sources: [source],
            systemPrompt: "系统提示",
            modelName: "test-model",
            latency: 50
        )
    }
}
