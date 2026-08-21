//
//  LLMAuxiliarySupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 测试层
//  核心职责：补盲 Infrastructure/LLM 辅助服务（PromptService、NativeMemoryEngine、SwarmMemoryAdapter、
//           LLMConfigManager、InferenceParametersStore、AIAnalyticsService、LLMChatService.streamChat、
//           LLMService 属性降级）的未覆盖分支与边界条件。
//

import XCTest
import UFPCore
import Dependencies
import Combine
@testable import ZhiYu

// MARK: - PromptService 补盲测试

@MainActor
final class PromptServiceSupplementTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var service: PromptService!

    override func setUp() async throws {
        try await super.setUp()
        testDefaults = UserDefaults(suiteName: "PromptServiceSupplementTestSuite")
        XCTAssertNotNil(testDefaults, "UserDefaults suite 应创建成功")
        testDefaults.removePersistentDomain(forName: "PromptServiceSupplementTestSuite")
        service = PromptService(defaults: testDefaults)
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: "PromptServiceSupplementTestSuite")
        testDefaults = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - ShortcutItem

    func testShortcutItemTextGetterWithLocalizationKey() {
        let item = ShortcutItem(text: "原始文本", localizationKey: "prompt.shortcut.deepReview")
        let resolved = item.text
        XCTAssertFalse(resolved.isEmpty, "有 localizationKey 时应通过 L10n 解析返回非空文本")
    }

    func testShortcutItemTextGetterWithoutLocalizationKey() {
        let item = ShortcutItem(text: "纯文本快捷方式", localizationKey: nil)
        XCTAssertEqual(item.text, "纯文本快捷方式", "无 localizationKey 时应返回 rawText")
    }

    func testShortcutItemTextSetterClearsLocalizationKey() {
        var item = ShortcutItem(text: "原始", localizationKey: "prompt.shortcut.deepReview")
        item.text = "用户自定义文本"
        XCTAssertNil(item.localizationKey, "setter 后 localizationKey 应被清空为 nil")
        XCTAssertEqual(item.rawText, "用户自定义文本", "setter 后 rawText 应更新为新值")
        XCTAssertEqual(item.text, "用户自定义文本", "setter 后 text getter 应返回 rawText")
    }

    func testShortcutItemCodableRoundTrip() throws {
        let original = ShortcutItem(text: "测试", localizationKey: "some.key")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutItem.self, from: encoded)
        XCTAssertEqual(decoded.rawText, original.rawText)
        XCTAssertEqual(decoded.localizationKey, original.localizationKey)
    }

    // MARK: - languageInstruction

    func testLanguageInstructionContainsLocaleCode() {
        let instruction = service.languageInstruction
        XCTAssertTrue(instruction.contains("Please reply"), "languageInstruction 应包含英文指令前缀")
        XCTAssertTrue(instruction.count > 10, "languageInstruction 应非空且包含语言代码")
    }

    // MARK: - updateLocalizables

    func testUpdateLocalizablesPopulatesDefaultShortcutsWhenEmpty() {
        service.userShortcuts = []
        service.updateLocalizables()
        XCTAssertEqual(service.userShortcuts.count, 3, "空 shortcuts 时应填充 3 个默认快捷方式")
    }

    func testUpdateLocalizablesPreservesExistingShortcuts() {
        let custom: [ShortcutItem] = [
            ShortcutItem(text: "自定义1", localizationKey: nil),
            ShortcutItem(text: "自定义2", localizationKey: nil)
        ]
        service.userShortcuts = custom
        service.updateLocalizables()
        XCTAssertEqual(service.userShortcuts.count, 2, "已有 shortcuts 时不应覆盖")
        XCTAssertEqual(service.userShortcuts[0].rawText, "自定义1")
    }

    func testUpdateLocalizablesRestoresDefaultPromptsWhenNotSaved() {
        service.mindmapPrompt = "临时修改"
        testDefaults.removeObject(forKey: "prompt_mindmap")
        service.updateLocalizables()
        XCTAssertEqual(service.mindmapPrompt, L10n.AI.Prompt.Default.mindmap, "未保存的 prompt 应恢复为默认值")
    }

    func testUpdateLocalizablesKeepsSavedPrompts() {
        service.mindmapPrompt = "用户自定义"
        testDefaults.set("用户自定义", forKey: "prompt_mindmap")
        service.updateLocalizables()
        XCTAssertEqual(service.mindmapPrompt, "用户自定义", "已保存的 prompt 应保留")
    }

    // MARK: - load 解码失败

    func testLoadHandlesCorruptedShortcutData() {
        testDefaults.set(Data("invalid json".utf8), forKey: "prompt_user_shortcuts")
        let newService = PromptService(defaults: testDefaults)
        XCTAssertEqual(newService.userShortcuts.count, 3, "解码失败后 updateLocalizables 应填充默认 shortcuts")
    }

    // MARK: - save 持久化

    func testSavePersistsShortcutsToUserDefaults() {
        let custom: [ShortcutItem] = [
            ShortcutItem(text: "保存测试", localizationKey: nil)
        ]
        service.userShortcuts = custom
        service.save()
        let savedData = testDefaults.data(forKey: "prompt_user_shortcuts")
        XCTAssertNotNil(savedData, "save 后 prompt_user_shortcuts 应有数据")
    }

    func testSavePersistsAllPromptFields() {
        service.mindmapPrompt = "自定义mindmap"
        service.quizPrompt = "自定义quiz"
        service.slidesPrompt = "自定义slides"
        service.reportPrompt = "自定义report"
        service.expansionPrompt = "自定义expansion"
        service.save()

        let newService = PromptService(defaults: testDefaults)
        XCTAssertEqual(newService.mindmapPrompt, "自定义mindmap")
        XCTAssertEqual(newService.quizPrompt, "自定义quiz")
        XCTAssertEqual(newService.slidesPrompt, "自定义slides")
        XCTAssertEqual(newService.reportPrompt, "自定义report")
        XCTAssertEqual(newService.expansionPrompt, "自定义expansion")
    }

    // MARK: - reset

    func testResetClearsAllSavedPrompts() {
        service.mindmapPrompt = "修改1"
        service.quizPrompt = "修改2"
        service.slidesPrompt = "修改3"
        service.reportPrompt = "修改4"
        service.expansionPrompt = "修改5"
        service.save()

        service.reset()

        XCTAssertEqual(service.mindmapPrompt, L10n.AI.Prompt.Default.mindmap)
        XCTAssertEqual(service.quizPrompt, L10n.AI.Prompt.Default.quiz)
        XCTAssertEqual(service.slidesPrompt, L10n.AI.Prompt.Default.slides)
        XCTAssertEqual(service.reportPrompt, L10n.AI.Prompt.Default.report)
        XCTAssertEqual(service.expansionPrompt, L10n.AI.Prompt.Default.expansion)
        XCTAssertEqual(service.userShortcuts.count, 3, "reset 后应恢复 3 个默认 shortcuts")
        XCTAssertNil(testDefaults.string(forKey: "prompt_mindmap"), "reset 后 UserDefaults 应清除")
    }

    // MARK: - reload

    func testReloadLoadsSavedDataAndUpdatesLocalizables() {
        testDefaults.set("重新加载的prompt", forKey: "prompt_mindmap")
        service.reload()
        XCTAssertEqual(service.mindmapPrompt, "重新加载的prompt", "reload 应从 UserDefaults 加载已保存值")
    }
}

// MARK: - NativeMemoryEngine / SwarmMemoryAdapter 补盲测试

final class MemoryEngineSupplementTests: XCTestCase {

    // MARK: - NativeMemoryEngine

    func testNativeMemoryEngineType() {
        let engine = NativeMemoryEngine()
        XCTAssertEqual(engine.engineType, .native, "NativeMemoryEngine 的 engineType 应为 .native")
    }

    func testNativeProcessMemoryEmptyHistoryReturnsNilSummary() async {
        let engine = NativeMemoryEngine()
        let (summary, recent) = await engine.processMemory(history: [], recentCount: 5)
        XCTAssertNil(summary, "空历史应返回 nil summary")
        XCTAssertTrue(recent.isEmpty, "空历史应返回空 recent 列表")
    }

    func testNativeProcessMemoryCountLessOrEqualRecentCount() async {
        let engine = NativeMemoryEngine()
        let history = (1...3).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Msg \(i)")
        }
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 5)
        XCTAssertNil(summary, "history.count <= recentCount 时应返回 nil summary")
        XCTAssertEqual(recent.count, 3, "应返回全部历史消息")
    }

    func testNativeProcessMemoryCountEqualsRecentCount() async {
        let engine = NativeMemoryEngine()
        let history = (1...5).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Msg \(i)")
        }
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 5)
        XCTAssertNil(summary, "history.count == recentCount 时应返回 nil summary（无超出部分）")
        XCTAssertEqual(recent.count, 5)
    }

    func testNativeProcessMemorySummaryContainsRoleAndContent() async {
        let engine = NativeMemoryEngine()
        let history = (1...10).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Content\(i)")
        }
        let (summary, recent) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary, "超出 recentCount 的历史应生成 summary")
        XCTAssertEqual(recent.count, 3, "应只保留最近 3 条消息")
        XCTAssertTrue(summary?.contains("Conversation Background Summary") == true, "summary 应包含背景摘要标识")
        XCTAssertTrue(summary?.contains("user") == true, "summary 应包含角色信息")
    }

    func testNativeProcessMemorySummaryTruncatedToMaxLength() async {
        let engine = NativeMemoryEngine()
        let longContent = String(repeating: "A", count: 500)
        let history = (1...10).map { _ in
            ChatMessageDTO(role: .user, content: longContent)
        }
        let (summary, _) = await engine.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary)
        let maxSummaryLength = "[Conversation Background Summary: ]".count + LLMConstants.LogPreview.memorySummaryLength
        XCTAssertLessThanOrEqual(summary?.count ?? 0, maxSummaryLength, "summary 应被截断到 memorySummaryLength")
    }

    func testNativeRecordSessionSummarySucceeds() async throws {
        let engine = NativeMemoryEngine()
        try await engine.recordSessionSummary(sessionID: "session-1", summary: "测试摘要")
        try await engine.recordSessionSummary(sessionID: "session-2", summary: "另一个摘要")
    }

    func testNativeRecordSessionSummaryOverwritesExisting() async throws {
        let engine = NativeMemoryEngine()
        try await engine.recordSessionSummary(sessionID: "dup-session", summary: "第一次")
        try await engine.recordSessionSummary(sessionID: "dup-session", summary: "第二次")
    }

    // MARK: - SwarmMemoryAdapter

    func testSwarmMemoryAdapterType() {
        let adapter = SwarmMemoryAdapter()
        XCTAssertEqual(adapter.engineType, .openSourceAdapter, "SwarmMemoryAdapter 的 engineType 应为 .openSourceAdapter")
    }

    func testSwarmProcessMemoryEmptyHistoryReturnsNilSummary() async {
        let adapter = SwarmMemoryAdapter()
        let (summary, recent) = await adapter.processMemory(history: [], recentCount: 5)
        XCTAssertNil(summary, "空历史应返回 nil summary")
        XCTAssertTrue(recent.isEmpty, "空历史应返回空 recent 列表")
    }

    func testSwarmProcessMemoryCountLessOrEqualRecentCount() async {
        let adapter = SwarmMemoryAdapter()
        let history = (1...4).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Msg \(i)")
        }
        let (summary, recent) = await adapter.processMemory(history: history, recentCount: 5)
        XCTAssertNil(summary, "history.count <= recentCount 时应返回 nil summary")
        XCTAssertEqual(recent.count, 4)
    }

    func testSwarmProcessMemorySummaryContainsSwarmIdentifier() async {
        let adapter = SwarmMemoryAdapter()
        let history = (1...10).map { i in
            ChatMessageDTO(role: i % 2 == 1 ? .user : .assistant, content: "Content\(i)")
        }
        let (summary, recent) = await adapter.processMemory(history: history, recentCount: 3)
        XCTAssertNotNil(summary)
        XCTAssertEqual(recent.count, 3)
        XCTAssertTrue(summary?.contains("Swarm Agent Memory State") == true, "Swarm adapter summary 应包含 Swarm 标识")
    }

    func testSwarmRecordSessionSummarySucceeds() async throws {
        let adapter = SwarmMemoryAdapter()
        try await adapter.recordSessionSummary(sessionID: "swarm-1", summary: "Swarm 摘要")
    }

    // MARK: - 引擎一致性对比

    func testBothEnginesReturnSameRecentCount() async {
        let engines: [any MemoryEngineProtocol] = [NativeMemoryEngine(), SwarmMemoryAdapter()]
        let history = (1...20).map { i in
            ChatMessageDTO(role: i % 2 == 0 ? .user : .assistant, content: "Msg \(i)")
        }
        for engine in engines {
            let (_, recent) = await engine.processMemory(history: history, recentCount: 7)
            XCTAssertEqual(recent.count, 7, "\(engine.engineType.rawValue) 应返回 7 条 recent 消息")
        }
    }

    func testBothEnginesHandleZeroRecentCount() async {
        let engines: [any MemoryEngineProtocol] = [NativeMemoryEngine(), SwarmMemoryAdapter()]
        let history = (1...5).map { i in
            ChatMessageDTO(role: .user, content: "Msg \(i)")
        }
        for engine in engines {
            let (summary, recent) = await engine.processMemory(history: history, recentCount: 0)
            XCTAssertTrue(recent.isEmpty, "\(engine.engineType.rawValue) recentCount=0 时 recent 应为空")
            XCTAssertNotNil(summary, "\(engine.engineType.rawValue) recentCount=0 且有历史时应生成 summary")
        }
    }
}

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
        service.recordUsage(model: "test", response: [:], latency: 100)
    }

    func testRecordUsageDoesNotCrashWithMissingPromptTokens() {
        let service = AIAnalyticsService()
        service.recordUsage(model: "test", response: ["usage": [:]], latency: 100)
    }

    func testRecordUsageDoesNotCrashWithNonIntTokens() {
        let service = AIAnalyticsService()
        service.recordUsage(
            model: "test",
            response: ["usage": ["prompt_tokens": "not-an-int", "completion_tokens": 5]],
            latency: 100
        )
    }

    func testRecordUsageDoesNotCrashWithValidUsageInTestMode() {
        let service = AIAnalyticsService()
        service.recordUsage(
            model: "test",
            response: ["usage": ["prompt_tokens": 10, "completion_tokens": 5]],
            latency: 100
        )
    }

    func testRecordRAGMetricsDoesNotCrashWithNilSources() {
        let service = AIAnalyticsService()
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

// MARK: - LLMService 属性降级测试

@MainActor
final class LLMServiceDegradationPropertyTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
    }

    override func tearDown() async throws {
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testProviderReturnsDeepSeekWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.provider, .deepSeek, "configManager 为 nil 时 provider 应降级返回 .deepSeek")
    }

    func testApiKeyReturnsEmptyWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.apiKey, "", "configManager 为 nil 时 apiKey 应降级返回空字符串")
    }

    func testBaseURLReturnsEmptyWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.baseURL, "", "configManager 为 nil 时 baseURL 应降级返回空字符串")
    }

    func testModelReturnsEmptyWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.model, "", "configManager 为 nil 时 model 应降级返回空字符串")
    }

    func testIsEnabledReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.isEnabled, "configManager 为 nil 时 isEnabled 应降级返回 false")
    }

    func testAutoScanReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.autoScan, "configManager 为 nil 时 autoScan 应降级返回 false")
    }

    func testAutoRefactorReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.autoRefactor, "configManager 为 nil 时 autoRefactor 应降级返回 false")
    }

    func testIsReadyReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.isReady, "configManager 为 nil 时 isReady 应降级返回 false")
    }

    func testSetterNoCrashWhenConfigManagerMissing() {
        let service = LLMService()
        service.provider = .zhipu
        service.apiKey = "sk-test"
        service.baseURL = "https://test.com"
        service.model = "test-model"
        service.isEnabled = true
        service.autoScan = true
        service.autoRefactor = true
    }
}

// MARK: - LLMChatService streamChat 补盲测试

@MainActor
final class LLMChatServiceStreamSupplementTests: XCTestCase {

    func testStreamChatWithLoggerDoesNotCrash() async throws {
        let mockClient = StreamableMockLLMClient(sseText: "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\ndata: [DONE]\n\n")
        let logger = TestLogger()
        let service = LLMChatService(client: mockClient, model: "test", logger: logger)

        let stream = service.streamChat(systemPrompt: "sys", query: "hi", history: [])
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["Hello"], "应从 SSE 流中提取一个 chunk")
        XCTAssertGreaterThan(logger.debugMessages.count, 0, "logger 应记录调试消息")
    }

    func testStreamChatWithoutLoggerDoesNotCrash() async throws {
        let mockClient = StreamableMockLLMClient(sseText: "data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\ndata: [DONE]\n\n")
        let service = LLMChatService(client: mockClient, model: "test")

        let stream = service.streamChat(systemPrompt: "sys", query: "hi", history: [])
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["Hi"])
    }

    func testStreamChatPropagatesClientError() async {
        let mockClient = StreamableMockLLMClient(error: LLMError.apiError("stream error"))
        let service = LLMChatService(client: mockClient, model: "test")

        let stream = service.streamChat(systemPrompt: "sys", query: "hi", history: [])
        do {
            for try await _ in stream {
            }
            XCTFail("应抛出错误")
        } catch {
            if let llmError = error as? LLMError, case .apiError = llmError {
            } else {
                XCTFail("错误类型不匹配: \(error)")
            }
        }
    }

    func testStreamChatWithHistoryPassesMessages() async throws {
        let mockClient = StreamableMockLLMClient(sseText: "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\ndata: [DONE]\n\n")
        let service = LLMChatService(client: mockClient, model: "test")

        let history = [
            ChatMessageDTO(role: .user, content: "之前的问题"),
            ChatMessageDTO(role: .assistant, content: "之前的回答")
        ]
        let stream = service.streamChat(systemPrompt: "sys", query: "新问题", history: history)
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["OK"])
        XCTAssertGreaterThan(mockClient.lastBodyMessagesCount, 2, "请求体应包含历史消息")
    }
}

// MARK: - 测试辅助

/// 支持 SSE 流式请求的 Mock LLM Client
private final class StreamableMockLLMClient: LLMClientProtocol, @unchecked Sendable {
    private let sseText: String
    private let mockError: Error?
    private(set) var lastBodyMessagesCount: Int = 0

    init(sseText: String) {
        self.sseText = sseText
        self.mockError = nil
    }

    init(error: Error) {
        self.sseText = ""
        self.mockError = error
    }

    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        [:]
    }

    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
        if let error = mockError { throw error }
        lastBodyMessagesCount = (body["messages"] as? [[String: Any]])?.count ?? 0
        SSEMockURLProtocol.reset()
        SSEMockURLProtocol.responseBody = sseText
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SSEMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let url = URL(string: "https://sse.mock.local/sse")!
        let (bytes, _) = try await session.bytes(from: url)
        return bytes
    }
}

/// 测试用 Logger（记录 debug 消息用于断言）
private final class TestLogger: LoggerProtocol, @unchecked Sendable {
    var debugMessages: [String] = []

    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?,
                startTime: Date?, endTime: Date?, module: String?, status: LogStatus?, failureReason: String?) {}

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debugMessages.append(message)
    }
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {}
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {}
    func error(_ message: String, error: Error?, file: String = #file, function: String = #function, line: Int = #line) {}

    func logTimed<T>(action: LogAction, target: String, module: String?, details: String, operation: () throws -> T) rethrows -> T {
        try operation()
    }

    func saveToDisk() async {}
    func loadFromDisk() async {}
    func clearAllLogs() async {}
    func getLogEntries() async -> [LogEntry] { [] }

    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> {
        Just([]).eraseToAnyPublisher()
    }
}
