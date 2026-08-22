//
//  ModelLabManagerDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：ModelLabManager 深度补盲测试 — 覆盖 UseCaseType 7 case 的元数据映射、
//            paramTips/attachmentOptions 分支、isModelCompatible 过滤、runSimulation 状态管理
//            与各 case 模拟响应、stopSimulation 中断、重复调用保护、4B 模型指标差异、
//            setupExtraData 各 case 的 traceSteps/confidenceItems/extraPanelTitle 填充。
//

import XCTest
import UFPCore
@testable import ZhiYu

// MARK: - 空响应 LLM Mock（强制 runSimulation 走 getMockResponse 离线路径）

/// 返回空字符串的 LLM Mock，使 runSimulation 中 realLLMResponse 为 nil，触发 getMockResponse 离线模拟。
@MainActor
final class EmptyResponseLLMService: LLMService, @unchecked Sendable {
    override func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        return ""
    }
    override func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: "")
    }
    override func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

/// 返回空字符串的 LLMChatService Mock，使 LLMService.shared.generate 经 chatRunner 委托后返回空。
@MainActor
final class EmptyResponseChatService: LLMChatServiceProtocol, @unchecked Sendable {
    var isEnabled: Bool = true
    var provider: LLMProvider = .custom
    var apiKey: String = ""
    var baseURL: String = ""
    var model: String = ""
    var autoScan: Bool = false
    var autoRefactor: Bool = false
    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: "")
    }
    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        return ""
    }
}

// MARK: - ModelLabManager 深度测试

@MainActor
final class ModelLabManagerDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var manager: ModelLabManager!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()
        // 覆盖 LLMService 和 LLMChatServiceProtocol 注册为空响应 Mock，
        // 确保 runSimulation 中 LLMService.shared.generate 经 chatRunner 委托后返回空，
        // 触发 getMockResponse 离线模拟路径。
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

    // MARK: - UseCaseType 元数据映射

    /// 验证 UseCaseType 共 7 个 case，与 CaseIterable 一致。
    func testUseCaseType_共7个Case() {
        XCTAssertEqual(UseCaseType.allCases.count, 7, "UseCaseType 应有 7 个 case")
    }

    /// 验证 askImage 的 title 非空且来自 L10n。
    func testUseCaseType_askImage的title非空() {
        XCTAssertFalse(UseCaseType.askImage.title.isEmpty)
    }

    /// 验证 audioScribe 的 title 非空。
    func testUseCaseType_audioScribe的title非空() {
        XCTAssertFalse(UseCaseType.audioScribe.title.isEmpty)
    }

    /// 验证 aiChat 的 title 非空。
    func testUseCaseType_aiChat的title非空() {
        XCTAssertFalse(UseCaseType.aiChat.title.isEmpty)
    }

    /// 验证 agentSkills 的 title 非空。
    func testUseCaseType_agentSkills的title非空() {
        XCTAssertFalse(UseCaseType.agentSkills.title.isEmpty)
    }

    /// 验证 promptLab 的 title 非空。
    func testUseCaseType_promptLab的title非空() {
        XCTAssertFalse(UseCaseType.promptLab.title.isEmpty)
    }

    /// 验证 tinyGarden 的 title 非空。
    func testUseCaseType_tinyGarden的title非空() {
        XCTAssertFalse(UseCaseType.tinyGarden.title.isEmpty)
    }

    /// 验证 mobileActions 的 title 非空。
    func testUseCaseType_mobileActions的title非空() {
        XCTAssertFalse(UseCaseType.mobileActions.title.isEmpty)
    }

    /// 验证所有 case 的 description 非空。
    func testUseCaseType_所有case的description非空() {
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.description.isEmpty, "\(useCase) 的 description 不应为空")
        }
    }

    /// 验证所有 case 的 icon 非空（SF Symbol 名称）。
    func testUseCaseType_所有case的icon非空() {
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.icon.isEmpty, "\(useCase) 的 icon 不应为空")
        }
    }

    /// 验证 askImage/audioScribe 的 requiredTask 为 "multimodal"。
    func testUseCaseType_多模态case的requiredTask为multimodal() {
        XCTAssertEqual(UseCaseType.askImage.requiredTask, "multimodal")
        XCTAssertEqual(UseCaseType.audioScribe.requiredTask, "multimodal")
    }

    /// 验证 aiChat/agentSkills/promptLab/tinyGarden/mobileActions 的 requiredTask 为 "chat"。
    func testUseCaseType_对话类case的requiredTask为chat() {
        XCTAssertEqual(UseCaseType.aiChat.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.agentSkills.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.promptLab.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.tinyGarden.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.mobileActions.requiredTask, "chat")
    }

    /// 验证 id 等于 rawValue。
    func testUseCaseType_id等于rawValue() {
        for useCase in UseCaseType.allCases {
            XCTAssertEqual(useCase.id, useCase.rawValue)
        }
    }

    // MARK: - paramTips 分支

    /// 验证 selectedUseCase 为 nil 时 paramTips 返回空字符串。
    func testParamTips_selectedUseCase为nil时返回空() {
        manager.selectedUseCase = nil
        XCTAssertEqual(manager.paramTips, "")
    }

    /// 验证 askImage 时 paramTips 返回多模态提示。
    func testParamTips_askImage返回多模态提示() {
        manager.selectedUseCase = .askImage
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 audioScribe 时 paramTips 返回多模态提示。
    func testParamTips_audioScribe返回多模态提示() {
        manager.selectedUseCase = .audioScribe
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 tinyGarden 时 paramTips 返回 Agent 提示。
    func testParamTips_tinyGarden返回Agent提示() {
        manager.selectedUseCase = .tinyGarden
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 mobileActions 时 paramTips 返回 Agent 提示。
    func testParamTips_mobileActions返回Agent提示() {
        manager.selectedUseCase = .mobileActions
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 aiChat 时 paramTips 返回空（default 分支）。
    func testParamTips_aiChat返回空() {
        manager.selectedUseCase = .aiChat
        XCTAssertEqual(manager.paramTips, "")
    }

    /// 验证 agentSkills 时 paramTips 返回空（default 分支）。
    func testParamTips_agentSkills返回空() {
        manager.selectedUseCase = .agentSkills
        XCTAssertEqual(manager.paramTips, "")
    }

    /// 验证 promptLab 时 paramTips 返回空（default 分支）。
    func testParamTips_promptLab返回空() {
        manager.selectedUseCase = .promptLab
        XCTAssertEqual(manager.paramTips, "")
    }

    // MARK: - attachmentOptions 分支

    /// 验证 aiChat 时 attachmentOptions 返回 2 个选项（linkPage + injectTag）。
    func testAttachmentOptions_aiChat返回2个选项() {
        manager.selectedUseCase = .aiChat
        let options = manager.attachmentOptions
        XCTAssertEqual(options.count, 2)
    }

    /// 验证 aiChat 的 attachmentOptions 包含 linkPage 选项。
    func testAttachmentOptions_aiChat包含linkPage() {
        manager.selectedUseCase = .aiChat
        let titles = manager.attachmentOptions.map(\.title)
        XCTAssertFalse(titles.isEmpty)
    }

    /// 验证非 aiChat 时 attachmentOptions 返回 2 个选项（mountSandbox + loadTemplate）。
    func testAttachmentOptions_非aiChat返回2个选项() {
        manager.selectedUseCase = .askImage
        XCTAssertEqual(manager.attachmentOptions.count, 2)
    }

    /// 验证 selectedUseCase 为 nil 时 attachmentOptions 返回默认 2 个选项。
    func testAttachmentOptions_nil时返回默认2个选项() {
        manager.selectedUseCase = nil
        XCTAssertEqual(manager.attachmentOptions.count, 2)
    }

    /// 验证所有 case 的 attachmentOptions 选项 title 非空。
    func testAttachmentOptions_所有选项title非空() {
        for useCase in UseCaseType.allCases {
            manager.selectedUseCase = useCase
            for option in manager.attachmentOptions {
                XCTAssertFalse(option.title.isEmpty, "\(useCase) 的附件选项 title 不应为空")
            }
        }
    }

    /// 验证所有 case 的 attachmentOptions 选项 icon 非空。
    func testAttachmentOptions_所有选项icon非空() {
        for useCase in UseCaseType.allCases {
            manager.selectedUseCase = useCase
            for option in manager.attachmentOptions {
                XCTAssertFalse(option.icon.isEmpty, "\(useCase) 的附件选项 icon 不应为空")
            }
        }
    }

    // MARK: - isModelCompatible

    /// 验证模型支持 chat 时，aiChat 用例兼容。
    func testIsModelCompatible_支持chat时aiChat兼容() {
        let manifest = makeManifest(supportedTasks: ["chat"])
        XCTAssertTrue(manager.isModelCompatible(manifest, for: .aiChat))
    }

    /// 验证模型不支持 chat 时，aiChat 用例不兼容。
    func testIsModelCompatible_不支持chat时aiChat不兼容() {
        let manifest = makeManifest(supportedTasks: ["completion"])
        XCTAssertFalse(manager.isModelCompatible(manifest, for: .aiChat))
    }

    /// 验证模型支持 multimodal 时，askImage 用例兼容。
    func testIsModelCompatible_支持multimodal时askImage兼容() {
        let manifest = makeManifest(supportedTasks: ["multimodal"])
        XCTAssertTrue(manager.isModelCompatible(manifest, for: .askImage))
    }

    /// 验证模型不支持 multimodal 时，askImage 用例不兼容。
    func testIsModelCompatible_不支持multimodal时askImage不兼容() {
        let manifest = makeManifest(supportedTasks: ["chat"])
        XCTAssertFalse(manager.isModelCompatible(manifest, for: .askImage))
    }

    /// 验证模型支持 multimodal 时，audioScribe 用例兼容。
    func testIsModelCompatible_支持multimodal时audioScribe兼容() {
        let manifest = makeManifest(supportedTasks: ["multimodal"])
        XCTAssertTrue(manager.isModelCompatible(manifest, for: .audioScribe))
    }

    /// 验证模型同时支持 chat 和 multimodal 时，所有用例兼容。
    func testIsModelCompatible_支持chat和multimodal时所有用例兼容() {
        let manifest = makeManifest(supportedTasks: ["chat", "multimodal"])
        for useCase in UseCaseType.allCases {
            XCTAssertTrue(manager.isModelCompatible(manifest, for: useCase), "\(useCase) 应兼容")
        }
    }

    /// 验证空 supportedTasks 时所有用例不兼容。
    func testIsModelCompatible_空supportedTasks时所有用例不兼容() {
        let manifest = makeManifest(supportedTasks: [])
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(manager.isModelCompatible(manifest, for: useCase), "\(useCase) 不应兼容")
        }
    }

    // MARK: - runSimulation 状态管理

    /// 验证 runSimulation 前后 isGenerating 状态正确切换。
    func testRunSimulation_isGenerating状态正确切换() async {
        let manifest = makeManifest()
        XCTAssertFalse(manager.isGenerating, "初始 isGenerating 应为 false")

        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "测试")

        XCTAssertFalse(manager.isGenerating, "runSimulation 完成后 isGenerating 应为 false")
    }

    /// 验证 runSimulation 后 generatedText 非空。
    func testRunSimulation_generatedText非空() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "测试")
        XCTAssertFalse(manager.generatedText.isEmpty, "runSimulation 后 generatedText 不应为空")
    }

    /// 验证 runSimulation 后 currentStats 的 prefillLatency 非 0。
    func testRunSimulation_currentStatsPrefillLatency非零() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "测试")
        XCTAssertGreaterThan(manager.currentStats.prefillLatency, 0)
    }

    /// 验证 runSimulation 后 currentStats 的 firstTokenLatency 非 0。
    func testRunSimulation_currentStatsFirstTokenLatency非零() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "测试")
        XCTAssertGreaterThan(manager.currentStats.firstTokenLatency, 0)
    }

    /// 验证 runSimulation 后 currentStats 的 memoryUsage 非 0。
    func testRunSimulation_currentStatsMemoryUsage非零() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "测试")
        XCTAssertGreaterThan(manager.currentStats.memoryUsage, 0)
    }

    /// 验证 askImage 用例的 prefillLatency 基准为 450（非 4B 模型）。
    func testRunSimulation_askImage的prefillLatency基准450() async {
        let manifest = makeManifest(parameterCount: "2B")
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "图片")
        XCTAssertEqual(manager.currentStats.prefillLatency, 450, "askImage 非 4B 的 prefillLatency 应为 450")
    }

    /// 验证 askImage 用例的 firstTokenLatency 基准为 520（非 4B 模型）。
    func testRunSimulation_askImage的firstTokenLatency基准520() async {
        let manifest = makeManifest(parameterCount: "2B")
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "图片")
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 520, "askImage 非 4B 的 firstTokenLatency 应为 520")
    }

    /// 验证非 askImage 用例的 prefillLatency 基准为 180（非 4B 模型）。
    func testRunSimulation_非askImage的prefillLatency基准180() async {
        let manifest = makeManifest(parameterCount: "2B")
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "对话")
        XCTAssertEqual(manager.currentStats.prefillLatency, 180, "非 askImage 非 4B 的 prefillLatency 应为 180")
    }

    /// 验证非 askImage 用例的 firstTokenLatency 基准为 210（非 4B 模型）。
    func testRunSimulation_非askImage的firstTokenLatency基准210() async {
        let manifest = makeManifest(parameterCount: "2B")
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "对话")
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 210, "非 askImage 非 4B 的 firstTokenLatency 应为 210")
    }

    /// 验证 4B 模型的 prefillLatency 比非 4B 多 80（askImage）。
    func testRunSimulation_4B模型askImage的prefillLatency为530() async {
        let manifest = makeManifest(parameterCount: "4B")
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "图片")
        XCTAssertEqual(manager.currentStats.prefillLatency, 530, "askImage 4B 的 prefillLatency 应为 450+80=530")
    }

    /// 验证 4B 模型的 firstTokenLatency 比非 4B 多 95（askImage）。
    func testRunSimulation_4B模型askImage的firstTokenLatency为615() async {
        let manifest = makeManifest(parameterCount: "4B")
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "图片")
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 615, "askImage 4B 的 firstTokenLatency 应为 520+95=615")
    }

    /// 验证 4B 模型的 prefillLatency 比非 4B 多 80（非 askImage）。
    func testRunSimulation_4B模型非askImage的prefillLatency为260() async {
        let manifest = makeManifest(parameterCount: "4B")
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "对话")
        XCTAssertEqual(manager.currentStats.prefillLatency, 260, "非 askImage 4B 的 prefillLatency 应为 180+80=260")
    }

    /// 验证 4B 模型的 firstTokenLatency 比非 4B 多 95（非 askImage）。
    func testRunSimulation_4B模型非askImage的firstTokenLatency为305() async {
        let manifest = makeManifest(parameterCount: "4B")
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "对话")
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 305, "非 askImage 4B 的 firstTokenLatency 应为 210+95=305")
    }

    /// 验证 4B 模型的 memoryUsage 基准约 1240（允许随机偏移 -20~30）。
    func testRunSimulation_4B模型memoryUsage约1240() async {
        let manifest = makeManifest(parameterCount: "4B")
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "对话")
        XCTAssertGreaterThanOrEqual(manager.currentStats.memoryUsage, 1220, "4B memoryUsage 应 >= 1240-20")
        XCTAssertLessThanOrEqual(manager.currentStats.memoryUsage, 1270, "4B memoryUsage 应 <= 1240+30")
    }

    /// 验证非 4B 模型的 memoryUsage 基准约 850（允许随机偏移 -20~30）。
    func testRunSimulation_非4B模型memoryUsage约850() async {
        let manifest = makeManifest(parameterCount: "2B")
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "对话")
        XCTAssertGreaterThanOrEqual(manager.currentStats.memoryUsage, 830, "非 4B memoryUsage 应 >= 850-20")
        XCTAssertLessThanOrEqual(manager.currentStats.memoryUsage, 880, "非 4B memoryUsage 应 <= 850+30")
    }

    // MARK: - runSimulation 重复调用保护

    /// 验证 isGenerating 为 true 时再次调用 runSimulation 不执行（guard 保护）。
    func testRunSimulation_isGenerating时再次调用不执行() async {
        let manifest = makeManifest()
        manager.isGenerating = true
        manager.generatedText = "已有内容"

        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "新测试")

        XCTAssertEqual(manager.generatedText, "已有内容", "isGenerating 为 true 时不应重置 generatedText")
    }

    // MARK: - runSimulation 空输入

    /// 验证空 prompt（纯空白）时仍能生成离线模拟响应。
    func testRunSimulation_空prompt仍生成离线模拟() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "   \n  ")
        XCTAssertFalse(manager.generatedText.isEmpty, "空 prompt 应回退至离线模拟并生成文本")
    }

    // MARK: - runSimulation 各 case 模拟响应

    /// 验证 askImage 用例的模拟响应包含多模态视觉标识。
    func testRunSimulation_askImage模拟响应含多模态标识() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        XCTAssertTrue(manager.generatedText.contains("多模态视觉模拟") || manager.generatedText.contains("MediaPipe"),
                      "askImage 模拟响应应包含多模态标识")
    }

    /// 验证 audioScribe 用例的模拟响应包含语音速记标识。
    func testRunSimulation_audioScribe模拟响应含语音标识() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        XCTAssertTrue(manager.generatedText.contains("语音速记") || manager.generatedText.contains("RTF"),
                      "audioScribe 模拟响应应包含语音标识")
    }

    /// 验证 aiChat 用例的模拟响应包含模型 displayName。
    func testRunSimulation_aiChat模拟响应含模型名称() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "问题")
        XCTAssertTrue(manager.generatedText.contains(manifest.displayName),
                      "aiChat 模拟响应应包含模型 displayName")
    }

    /// 验证 agentSkills 用例的模拟响应包含 Agent Tool Call 标识。
    func testRunSimulation_agentSkills模拟响应含Agent标识() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .agentSkills, model: manifest, prompt: "")
        XCTAssertTrue(manager.generatedText.contains("Agent Tool Call") || manager.generatedText.contains("summarizeActivePage"),
                      "agentSkills 模拟响应应包含 Agent 标识")
    }

    /// 验证 promptLab 用例的模拟响应包含 Temperature 值。
    func testRunSimulation_promptLab模拟响应含Temperature() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .promptLab, model: manifest, prompt: "")
        XCTAssertTrue(manager.generatedText.contains("Temperature"),
                      "promptLab 模拟响应应包含 Temperature")
    }

    /// 验证 promptLab 用例的模拟响应包含 topP 值。
    func testRunSimulation_promptLab模拟响应含TopP() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .promptLab, model: manifest, prompt: "")
        XCTAssertTrue(manager.generatedText.contains("Top-P"),
                      "promptLab 模拟响应应包含 Top-P")
    }

    /// 验证 tinyGarden 用例的模拟响应包含种植标识。
    func testRunSimulation_tinyGarden模拟响应含种植标识() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .tinyGarden, model: manifest, prompt: "")
        XCTAssertTrue(manager.generatedText.contains("小花园") || manager.generatedText.contains("玫瑰"),
                      "tinyGarden 模拟响应应包含种植标识")
    }

    /// 验证 mobileActions 用例的模拟响应包含快捷指令标识。
    func testRunSimulation_mobileActions模拟响应含快捷指令标识() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .mobileActions, model: manifest, prompt: "")
        XCTAssertTrue(manager.generatedText.contains("快捷指令") || manager.generatedText.contains("toggleThemeMode"),
                      "mobileActions 模拟响应应包含快捷指令标识")
    }

    // MARK: - runSimulation prompt 截断

    /// 验证长 prompt（>15 字符）在模拟响应中被截断为前 15 字符 + "..."。
    func testRunSimulation_长prompt截断为前15字符() async {
        let manifest = makeManifest()
        let longPrompt = String(repeating: "这是一段很长的测试提示词内容", count: 5)
        await manager.runSimulation(for: .mobileActions, model: manifest, prompt: longPrompt)
        // mobileActions 模拟响应包含 promptSnippet，应被截断
        XCTAssertTrue(manager.generatedText.contains("..."), "长 prompt 应被截断并添加省略号")
    }

    /// 验证短 prompt（<=15 字符）在模拟响应中不截断。
    func testRunSimulation_短prompt不截断() async {
        let manifest = makeManifest()
        let shortPrompt = "短提示"
        await manager.runSimulation(for: .mobileActions, model: manifest, prompt: shortPrompt)
        XCTAssertFalse(manager.generatedText.contains("短提示..."), "短 prompt 不应被截断")
    }

    // MARK: - stopSimulation

    /// 验证 stopSimulation 将 isGenerating 置为 false。
    func testStopSimulation_isGenerating置为false() {
        manager.isGenerating = true
        manager.stopSimulation()
        XCTAssertFalse(manager.isGenerating, "stopSimulation 后 isGenerating 应为 false")
    }

    /// 验证 stopSimulation 在 isGenerating 已为 false 时不崩溃。
    func testStopSimulation_已为false时不崩溃() {
        manager.isGenerating = false
        manager.stopSimulation()
        XCTAssertFalse(manager.isGenerating)
    }

    // MARK: - setupExtraData 各 case 填充

    /// 验证 askImage 用例填充 confidenceItems（3 项）。
    func testSetupExtraData_askImage填充confidenceItems() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        XCTAssertEqual(manager.confidenceItems.count, 3, "askImage 应填充 3 个 confidenceItems")
    }

    /// 验证 askImage 用例填充 extraPanelTitle 非空。
    func testSetupExtraData_askImage填充extraPanelTitle() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        XCTAssertFalse(manager.extraPanelTitle.isEmpty, "askImage 的 extraPanelTitle 不应为空")
    }

    /// 验证 audioScribe 用例填充 traceSteps（2 项）。
    func testSetupExtraData_audioScribe填充traceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 2, "audioScribe 应填充 2 个 traceSteps")
    }

    /// 验证 audioScribe 用例填充 extraPanelTitle 非空。
    func testSetupExtraData_audioScribe填充extraPanelTitle() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        XCTAssertFalse(manager.extraPanelTitle.isEmpty)
    }

    /// 验证 tinyGarden 用例填充 traceSteps（3 项）。
    func testSetupExtraData_tinyGarden填充traceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .tinyGarden, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 3, "tinyGarden 应填充 3 个 traceSteps")
    }

    /// 验证 mobileActions 用例填充 traceSteps（3 项）。
    func testSetupExtraData_mobileActions填充traceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .mobileActions, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 3, "mobileActions 应填充 3 个 traceSteps")
    }

    /// 验证 agentSkills 用例填充 traceSteps（3 项）。
    func testSetupExtraData_agentSkills填充traceSteps() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .agentSkills, model: manifest, prompt: "")
        XCTAssertEqual(manager.traceSteps.count, 3, "agentSkills 应填充 3 个 traceSteps")
    }

    /// 验证 aiChat 用例不填充 traceSteps 和 confidenceItems（default 分支）。
    func testSetupExtraData_aiChat不填充traceSteps和confidenceItems() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .aiChat, model: manifest, prompt: "")
        XCTAssertTrue(manager.traceSteps.isEmpty, "aiChat 不应填充 traceSteps")
        XCTAssertTrue(manager.confidenceItems.isEmpty, "aiChat 不应填充 confidenceItems")
    }

    /// 验证 promptLab 用例不填充 traceSteps 和 confidenceItems（default 分支）。
    func testSetupExtraData_promptLab不填充traceSteps和confidenceItems() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .promptLab, model: manifest, prompt: "")
        XCTAssertTrue(manager.traceSteps.isEmpty)
        XCTAssertTrue(manager.confidenceItems.isEmpty)
    }

    /// 验证 askImage 的 confidenceItems 分数在 0~1 范围内。
    func testSetupExtraData_askImage的confidenceItems分数合法() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        for item in manager.confidenceItems {
            XCTAssertGreaterThanOrEqual(item.score, 0.0, "分数应 >= 0")
            XCTAssertLessThanOrEqual(item.score, 1.0, "分数应 <= 1")
        }
    }

    /// 验证 askImage 的 confidenceItems name 非空。
    func testSetupExtraData_askImage的confidenceItemsName非空() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .askImage, model: manifest, prompt: "")
        for item in manager.confidenceItems {
            XCTAssertFalse(item.name.isEmpty, "confidenceItem name 不应为空")
        }
    }

    /// 验证 audioScribe 的 traceSteps title 非空。
    func testSetupExtraData_audioScribe的traceStepsTitle非空() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        for step in manager.traceSteps {
            XCTAssertFalse(step.title.isEmpty, "traceStep title 不应为空")
        }
    }

    /// 验证 audioScribe 的 traceSteps desc 非空。
    func testSetupExtraData_audioScribe的traceStepsDesc非空() async {
        let manifest = makeManifest()
        await manager.runSimulation(for: .audioScribe, model: manifest, prompt: "")
        for step in manager.traceSteps {
            XCTAssertFalse(step.desc.isEmpty, "traceStep desc 不应为空")
        }
    }

    // MARK: - 初始状态

    /// 验证新实例的 selectedUseCase 为 nil。
    func test初始状态_selectedUseCase为nil() {
        XCTAssertNil(manager.selectedUseCase)
    }

    /// 验证新实例的 generatedText 为空。
    func test初始状态_generatedText为空() {
        XCTAssertEqual(manager.generatedText, "")
    }

    /// 验证新实例的 isGenerating 为 false。
    func test初始状态_isGenerating为false() {
        XCTAssertFalse(manager.isGenerating)
    }

    /// 验证新实例的 currentStats 全为 0。
    func test初始状态_currentStats全为0() {
        XCTAssertEqual(manager.currentStats.speed, 0.0)
        XCTAssertEqual(manager.currentStats.prefillLatency, 0)
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 0)
        XCTAssertEqual(manager.currentStats.memoryUsage, 0.0)
    }

    /// 验证新实例的 traceSteps 为空。
    func test初始状态_traceSteps为空() {
        XCTAssertTrue(manager.traceSteps.isEmpty)
    }

    /// 验证新实例的 confidenceItems 为空。
    func test初始状态_confidenceItems为空() {
        XCTAssertTrue(manager.confidenceItems.isEmpty)
    }

    /// 验证新实例的 extraPanelTitle 为空。
    func test初始状态_extraPanelTitle为空() {
        XCTAssertEqual(manager.extraPanelTitle, "")
    }

    // MARK: - TraceStep / ConfidenceItem / AttachmentOption 结构

    /// 验证 TraceStep 的 id 等于 title。
    func testTraceStep_id等于title() {
        let step = TraceStep(title: "标题", desc: "描述", icon: "icon", colorName: "blue")
        XCTAssertEqual(step.id, "标题")
    }

    /// 验证 ConfidenceItem 的 id 等于 name。
    func testConfidenceItem_id等于name() {
        let item = ConfidenceItem(name: "物体", score: 0.9, colorName: "cyan")
        XCTAssertEqual(item.id, "物体")
    }

    /// 验证 AttachmentOption 的 id 等于 title。
    func testAttachmentOption_id等于title() {
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
    func testPerformanceStats_不等时不相等() {
        let stats1 = PerformanceStats(speed: 10.0, prefillLatency: 100, firstTokenLatency: 200, memoryUsage: 500.0)
        let stats2 = PerformanceStats(speed: 20.0, prefillLatency: 100, firstTokenLatency: 200, memoryUsage: 500.0)
        XCTAssertNotEqual(stats1, stats2)
    }
}
