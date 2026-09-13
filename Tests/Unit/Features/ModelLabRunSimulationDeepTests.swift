//
//  ModelLabRunSimulationDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：ModelLabManager 深度测试 — runSimulation 状态管理、4B 模型指标差异、
//            各 case 模拟响应、prompt 截断、stopSimulation 中断、重复调用保护。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class ModelLabRunSimulationDeepTests: XCTestCase {

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
}
