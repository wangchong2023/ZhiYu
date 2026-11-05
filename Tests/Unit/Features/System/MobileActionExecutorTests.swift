//
//  MobileActionExecutorTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试 / 系统功能层
//  核心职责：端侧智能体行为执行器 (MobileActionExecutor) 与思考过程解析器 (ThinkingContentParser) 的全面单测覆盖。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class MobileActionExecutorTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        MobileActionExecutor.shared.clearLogs()
    }

    // MARK: - 测试 1: 手电筒意图解析与执行

    @MainActor
    func testTorchIntentParsingAndExecution() async {
        let executor = MobileActionExecutor.shared
        executor.clearLogs()

        // 验证开启手电筒意图识别
        let actionOn = executor.parseIntent(from: "请帮我打开手电筒")
        XCTAssertEqual(actionOn, .torch(on: true))

        // 验证关闭手电筒意图识别
        let actionOff = executor.parseIntent(from: "关掉手电")
        XCTAssertEqual(actionOff, .torch(on: false))

        // 验证英文 turn off torch
        let actionEnglish = executor.parseIntent(from: "turn off torch light")
        XCTAssertEqual(actionEnglish, .torch(on: false))

        // 执行动作并检查日志记录
        if let action = actionOn {
            let record = await executor.execute(action: action)
            XCTAssertTrue(record.isSuccess)
            XCTAssertEqual(executor.isTorchOn, true)
            XCTAssertEqual(executor.recentLogs.count, 1)
            XCTAssertEqual(executor.recentLogs.first?.action, .torch(on: true))
        }
    }

    // MARK: - 测试 2: 触觉震动意图解析与执行

    @MainActor
    func testHapticIntentParsingAndExecution() async {
        let executor = MobileActionExecutor.shared
        executor.clearLogs()

        let actionChinese = executor.parseIntent(from: "给我一个成功的触感反馈")
        XCTAssertEqual(actionChinese, .haptic(pattern: .success))

        let actionEnglish = executor.parseIntent(from: "trigger haptic feedback")
        XCTAssertEqual(actionEnglish, .haptic(pattern: .success))

        if let action = actionChinese {
            let record = await executor.execute(action: action)
            XCTAssertTrue(record.isSuccess)
            XCTAssertEqual(executor.recentLogs.count, 1)
        }
    }

    // MARK: - 测试 3: 本地通知意图解析与安全回退

    @MainActor
    func testNotificationIntentParsing() async {
        let executor = MobileActionExecutor.shared
        executor.clearLogs()

        guard let action = executor.parseIntent(from: "发送一条待办提醒通知") else {
            XCTFail("应解析为有效动作")
            return
        }

        guard case .localNotification = action else {
            XCTFail("应解析为 localNotification 动作")
            return
        }

        let record = await executor.execute(action: action)
        XCTAssertTrue(record.isSuccess)
        XCTAssertEqual(executor.recentLogs.count, 1)
    }

    // MARK: - 测试 4: 外观模式切换与日志截断

    @MainActor
    func testThemeModeIntentAndLogLimit() async {
        let executor = MobileActionExecutor.shared

        let actionDark = executor.parseIntent(from: "切换到暗黑模式")
        XCTAssertEqual(actionDark, .themeMode(isDark: true))

        let actionLight = executor.parseIntent(from: "切换为浅色主题")
        XCTAssertEqual(actionLight, .themeMode(isDark: false))

        // 循环执行多次，验证最近日志上限控制
        for _ in 0..<15 {
            await executor.execute(action: .haptic(pattern: .selection))
        }

        XCTAssertEqual(executor.recentLogs.count, FeatureConstants.MobileActionConstants.maxRecentLogsCount)

        executor.clearLogs()
        XCTAssertEqual(executor.recentLogs.count, 0)
    }

    // MARK: - 测试 5: 深度思考过程解析器 (ThinkingContentParser)

    func testThinkingContentParser() {
        // 场景 A: 包含完整的 <think> 标签
        let rawWithThinking = """
        <think>
        1. 分析用户意图为设备状态检查。
        2. 提取当前硬件芯片与内存负载。
        </think>
        系统已就绪，当前各项硬件加速器运行平稳。
        """

        let parsed = ThinkingContentParser.parse(rawText: rawWithThinking)
        XCTAssertNotNil(parsed.thinkingText)
        XCTAssertTrue(parsed.thinkingText?.contains("分析用户意图") == true)
        XCTAssertEqual(parsed.answerText, "系统已就绪，当前各项硬件加速器运行平稳。")

        // 场景 B: 不包含 <think> 标签的普通回复
        let rawPlain = "这是一条端侧大模型的直接回复文本。"
        let parsedPlain = ThinkingContentParser.parse(rawText: rawPlain)
        XCTAssertNil(parsedPlain.thinkingText)
        XCTAssertEqual(parsedPlain.answerText, rawPlain)

        // 场景 C: 流式生成中，标签尚未闭合
        let rawStreaming = "<think>\n正在分析第一步..."
        let parsedStreaming = ThinkingContentParser.parse(rawText: rawStreaming)
        XCTAssertNotNil(parsedStreaming.thinkingText)
        XCTAssertEqual(parsedStreaming.thinkingText, "正在分析第一步...")
        XCTAssertEqual(parsedStreaming.answerText, "")
    }

    // MARK: - 测试 6: 对话气泡性能角标、模型规格徽章与配置窗口选项验证

    @MainActor
    func testChatMetricsBadgeAndConfigOptionsAndManifestSpecs() {
        // 1. 验证 AI 消息的性能角标与用户消息为 nil
        let aiMsg = LabChatMessage(isUser: false, text: "Done", firstTokenLatencyMs: 210, tokensPerSecond: 28.4)
        XCTAssertNotNil(aiMsg.metricsBadgeText)
        XCTAssertTrue(aiMsg.metricsBadgeText?.contains("210") == true)

        let userMsg = LabChatMessage(isUser: true, text: "Hello", firstTokenLatencyMs: 210, tokensPerSecond: 28.4)
        XCTAssertNil(userMsg.metricsBadgeText)

        // 2. 验证 LLMManifest 量化精度、运行时格式与沙盒路径推导
        let ggufManifest = LLMManifest(
            modelId: "qwen-2.5-0.5b",
            displayName: "Qwen 2.5",
            vendor: "Alibaba",
            fileSizeInBytes: 500_000_000,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/qwen2.5-q4_k_m.gguf",
            sha256Checksum: "",
            parameterCount: "0.5B",
            description: "Desc",
            defaultParameters: InferenceParameters()
        )
        XCTAssertEqual(ggufManifest.quantizationBadge, FeatureConstants.ModelSpecConstants.quantInt4Q4KM)
        XCTAssertEqual(ggufManifest.runtimeEngineBadge, FeatureConstants.ModelSpecConstants.engineGGUF)
        XCTAssertEqual(ggufManifest.localSandboxRelativePath, "Documents/qwen-2.5-0.5b.bin")

        // 3. 验证推理加速器与上下文窗口显存估算
        XCTAssertEqual(InferenceAccelerator.allCases.count, 4)
        XCTAssertEqual(ContextWindowOption.size2K.estimatedKVMemoryMB, 128)
        XCTAssertEqual(ContextWindowOption.size32K.estimatedKVMemoryMB, 1536)
    }
}
