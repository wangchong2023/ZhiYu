//
//  ModelLabExtraDataAndStateDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：ModelLabManager 深度测试 — setupExtraData 各 case 填充 traceSteps/confidenceItems、
//            初始状态验证、TraceStep/ConfidenceItem/AttachmentOption/PerformanceStats 结构。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class ModelLabExtraDataAndStateDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var manager: ModelLabManager!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()
        let emptyLLM = EmptyResponseLLMService()
        ServiceContainer.shared.register(emptyLLM as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        ServiceContainer.shared.register(emptyLLM as LLMService, for: LLMService.self)
        let emptyChat = EmptyResponseChatService()
        ServiceContainer.shared.register(emptyChat as any LLMChatServiceProtocol, for: (any LLMChatServiceProtocol).self)
        manager = ModelLabManager()
    }

    override func tearDown() async throws {
        resetPersistentTestState()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - 辅助工厂

    /// 构造测试用 LLMManifest（2B 参数，支持 chat 任务）
    private func makeManifest(
        parameterCount: String = "2B",
        supportedTasks: [String] = ["chat"],
        modelId: String = "test-2b"
    ) -> LLMManifest {
        LLMManifest(
            modelId: modelId,
            displayName: "Test-2B",
            vendor: "TestVendor",
            fileSizeInBytes: 1_000_000,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/model.bin",
            sha256Checksum: "abc123",
            parameterCount: parameterCount,
            supportedTasks: supportedTasks,
            description: "测试模型",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1024)
        )
    }

    // MARK: - setupExtraData 各 case 填充

    /// 验证 askImage 用例填充 confidenceItems（3 项）。
    func testSetupExtraDataAskImageFillsConfidenceItems() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        XCTAssertEqual(manager.confidenceItems.count, 3, "askImage 应填充 3 个 confidenceItems")
    }

    /// 验证 askImage 用例填充 extraPanelTitle 非空。
    func testSetupExtraDataAskImageFillsExtraPanelTitle() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        XCTAssertFalse(manager.extraPanelTitle.isEmpty, "askImage 的 extraPanelTitle 不应为空")
    }

    /// 验证 audioScribe 用例填充 traceSteps（2 项）。
    func testSetupExtraDataAudioScribeFillsTraceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 2, "audioScribe 应填充 2 个 traceSteps")
    }

    /// 验证 audioScribe 用例填充 extraPanelTitle 非空。
    func testSetupExtraDataAudioScribeFillsExtraPanelTitle() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        XCTAssertFalse(manager.extraPanelTitle.isEmpty)
    }

    /// 验证 tinyGarden 用例填充 traceSteps（3 项）。
    func testSetupExtraDataTinyGardenFillsTraceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .tinyGarden, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 3, "tinyGarden 应填充 3 个 traceSteps")
    }

    /// 验证 mobileActions 用例填充 traceSteps（3 项）。
    func testSetupExtraDataMobileActionsFillsTraceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .mobileActions, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 3, "mobileActions 应填充 3 个 traceSteps")
    }

    /// 验证 agentSkills 用例填充 traceSteps（3 项）。
    func testSetupExtraDataAgentSkillsFillsTraceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .agentSkills, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 3, "agentSkills 应填充 3 个 traceSteps")
    }

    /// 验证 aiChat 用例不填充 traceSteps 和 confidenceItems（default 分支）。
    func testSetupExtraDataAiChatDoesNotFillTraceStepsAndConfidenceItems() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "")
        XCTAssertTrue(manager.traceSteps.isEmpty, "aiChat 不应填充 traceSteps")
        XCTAssertTrue(manager.confidenceItems.isEmpty, "aiChat 不应填充 confidenceItems")
    }

    /// 验证 promptLab 用例不填充 traceSteps 和 confidenceItems（default 分支）。
    func testSetupExtraDataPromptLabDoesNotFillTraceStepsAndConfidenceItems() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .promptLab, model: manifest, prompt: "")
        XCTAssertTrue(manager.traceSteps.isEmpty)
        XCTAssertTrue(manager.confidenceItems.isEmpty)
    }

    /// 验证 askImage 的 confidenceItems 分数在 0~1 范围内。
    func testSetupExtraDataAskImageConfidenceItemsScoreValid() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        for item in manager.confidenceItems {
            XCTAssertGreaterThanOrEqual(item.score, 0.0, "分数应 >= 0")
            XCTAssertLessThanOrEqual(item.score, 1.0, "分数应 <= 1")
        }
    }

    /// 验证 askImage 的 confidenceItems name 非空。
    func testSetupExtraDataAskImageConfidenceItemsNameNonEmpty() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        for item in manager.confidenceItems {
            XCTAssertFalse(item.name.isEmpty, "confidenceItem name 不应为空")
        }
    }

    /// 验证 audioScribe 的 traceSteps title 非空。
    func testSetupExtraDataAudioScribeTraceStepsTitleNonEmpty() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        for step in manager.traceSteps {
            XCTAssertFalse(step.title.isEmpty, "traceStep title 不应为空")
        }
    }

    /// 验证 audioScribe 的 traceSteps desc 非空。
    func testSetupExtraDataAudioScribeTraceStepsDescNonEmpty() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        for step in manager.traceSteps {
            XCTAssertFalse(step.desc.isEmpty, "traceStep desc 不应为空")
        }
    }

    // MARK: - 初始状态

    /// 验证新实例的 selectedUseCase 为 nil。
    func testInitialStateSelectedUseCaseIsNil() {
        XCTAssertNil(manager.selectedUseCase)
    }

    /// 验证新实例的 generatedText 为空。
    func testInitialStateGeneratedTextIsEmpty() {
        XCTAssertEqual(manager.generatedText, "")
    }

    /// 验证新实例的 isGenerating 为 false。
    func testInitialStateIsGeneratingIsFalse() {
        XCTAssertFalse(manager.isGenerating)
    }

    /// 验证新实例的 currentStats 全为 0。
    func testInitialStateCurrentStatsAllZero() {
        XCTAssertEqual(manager.currentStats.speed, 0.0)
        XCTAssertEqual(manager.currentStats.prefillLatency, 0)
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 0)
        XCTAssertEqual(manager.currentStats.memoryUsage, 0.0)
    }

    /// 验证新实例的 traceSteps 为空。
    func testInitialStateTraceStepsIsEmpty() {
        XCTAssertTrue(manager.traceSteps.isEmpty)
    }

    /// 验证新实例的 confidenceItems 为空。
    func testInitialStateConfidenceItemsIsEmpty() {
        XCTAssertTrue(manager.confidenceItems.isEmpty)
    }

    /// 验证新实例的 extraPanelTitle 为空。
    func testInitialStateExtraPanelTitleIsEmpty() {
        XCTAssertEqual(manager.extraPanelTitle, "")
    }

    // MARK: - TraceStep / ConfidenceItem / AttachmentOption 结构

    /// 验证 TraceStep 的 id 等于 title。
    func testTraceStepIdEqualsTitle() {
        let step = TraceStep(title: "标题", desc: "描述", icon: "icon", colorName: "blue")
        XCTAssertEqual(step.id, "标题")
    }

    /// 验证 ConfidenceItem 的 id 等于 name。
    func testConfidenceItemIdEqualsName() {
        let item = ConfidenceItem(name: "物体", score: 0.9, colorName: "cyan")
        XCTAssertEqual(item.id, "物体")
    }

    /// 验证 AttachmentOption 的 id 等于 title。
    func testAttachmentOptionIdEqualsTitle() {
        let option = AttachmentOption(title: "选项", icon: "icon", successMessage: "成功")
        XCTAssertEqual(option.id, "选项")
    }

    /// 验证 PerformanceStats 可相等比较。
    func testPerformanceStats_Equatable() {
        let stats1 = PerformanceStats(speed: 10.0, prefillLatency: 100, firstTokenLatency: 200, memoryUsage: 500.0)
        let stats2 = PerformanceStats(speed: 10.0, prefillLatency: 100, firstTokenLatency: 200, memoryUsage: 500.0)
        XCTAssertEqual(stats1, stats2)
    }

    /// 验证 PerformanceStats 不等时比较。
    func testPerformanceStatsNotEqualWhenValuesDiffer() {
        let stats1 = PerformanceStats(speed: 10.0, prefillLatency: 100, firstTokenLatency: 200, memoryUsage: 500.0)
        let stats2 = PerformanceStats(speed: 20.0, prefillLatency: 100, firstTokenLatency: 200, memoryUsage: 500.0)
        XCTAssertNotEqual(stats1, stats2)
    }
}
