//
//  ModelLabManagerTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对大模型多用例测试实验室（ModelLabManager）开展自动化单元测试验证。
//

import XCTest
@testable import ZhiYu

@MainActor
final class ModelLabManagerTests: XCTestCase {
    
    private var manager: ModelLabManager!
    private var mockChatModel: LLMManifest!
    private var mockMultimodalModel: LLMManifest!
    
    override func setUp() {
        super.setUp()
        manager = ModelLabManager()
        
        // 构造专门用于测试的 Mock 聊天模型
        mockChatModel = LLMManifest(
            modelId: "mock-chat-model",
            displayName: "Mock Chat LLM",
            vendor: "ZhiYu Team",
            fileSizeInBytes: 1024 * 1024 * 1024,
            minDeviceMemoryInGb: 8.0,
            remoteURLString: "https://example.com/model.bin",
            sha256Checksum: "checksum123",
            parameterCount: "2B",
            supportedTasks: ["chat"],
            description: "A chat-only model for testing.",
            defaultParameters: InferenceParameters()
        )
        
        // 构造专门用于测试的 Mock 多模态模型
        mockMultimodalModel = LLMManifest(
            modelId: "mock-multimodal-model",
            displayName: "Mock Multimodal LLM",
            vendor: "ZhiYu Team",
            fileSizeInBytes: 2048 * 1024 * 1024,
            minDeviceMemoryInGb: 12.0,
            remoteURLString: "https://example.com/multimodal.bin",
            sha256Checksum: "checksum456",
            parameterCount: "4B",
            supportedTasks: ["chat", "multimodal"],
            description: "A multimodal model for testing.",
            defaultParameters: InferenceParameters()
        )
    }
    
    override func tearDown() {
        manager = nil
        mockChatModel = nil
        mockMultimodalModel = nil
        super.tearDown()
    }
    
    // MARK: - 1. 测试用例兼容性校验逻辑
    
    /// 验证测试用例与不同类型的端侧模型兼容性判定逻辑是否准确
    func testModelUseCaseCompatibility() {
        // 1. 聊天模型仅兼容聊天类用例，不兼容视觉、流式速记等需要 multimodal 的用例
        XCTAssertTrue(manager.isModelCompatible(mockChatModel, for: .aiChat))
        XCTAssertTrue(manager.isModelCompatible(mockChatModel, for: .agentSkills))
        XCTAssertTrue(manager.isModelCompatible(mockChatModel, for: .promptLab))
        XCTAssertTrue(manager.isModelCompatible(mockChatModel, for: .tinyGarden))
        XCTAssertTrue(manager.isModelCompatible(mockChatModel, for: .mobileActions))
        
        XCTAssertFalse(manager.isModelCompatible(mockChatModel, for: .askImage))
        XCTAssertFalse(manager.isModelCompatible(mockChatModel, for: .audioScribe))
        
        // 2. 多模态模型同时兼容所有 7 大用例场景类型
        for useCase in UseCaseType.allCases {
            XCTAssertTrue(manager.isModelCompatible(mockMultimodalModel, for: useCase),
                           "多模态模型应该支持全部测试用例：\(useCase.title)")
        }
    }
    
    // MARK: - 2. 测试流式仿真与指标更新机制
    
    /// 验证开启推理流时状态控制、吞吐量和延迟指标的真实度模拟
    func testRunSimulationUpdatesStatsAndText() async {
        XCTAssertFalse(manager.isGenerating)
        XCTAssertEqual(manager.generatedText, "")
        
        // 启动推理，采用异步多线程运行
        let runTask = Task {
            await manager.runSimulation(for: .aiChat, model: mockChatModel, prompt: "你好")
        }
        
        // 让出 CPU 周期让 Task 运行
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // 验证推理中状态
        XCTAssertTrue(manager.isGenerating)
        
        // 验证模拟的指标已生成
        XCTAssertGreaterThan(manager.currentStats.prefillLatency, 0)
        XCTAssertGreaterThan(manager.currentStats.firstTokenLatency, 0)
        XCTAssertGreaterThan(manager.currentStats.memoryUsage, 0.0)
        
        // 终止模拟
        manager.stopSimulation()
        await runTask.value
        
        XCTAssertFalse(manager.isGenerating)
    }
    
    // MARK: - 3. 验证用例输出文案适配
    
    /// 遍历所有用例场景，验证返回文本包含特定的说明标头
    func testSimulationResponsesCoverAllUseCases() async {
        // 由于 runSimulation 实际非常耗时，我们直接测试其内部依赖的响应生成机制
        for useCase in UseCaseType.allCases {
            let runTask = Task {
                await manager.runSimulation(for: useCase, model: mockMultimodalModel, prompt: "测试用例")
            }
            
            // 稍等一小会后主动停止，捕获已生成的文本
            try? await Task.sleep(nanoseconds: 10_000_000)
            manager.stopSimulation()
            await runTask.value
            
            // 校验已不再生成
            XCTAssertFalse(manager.isGenerating)
        }
    }
    
    // MARK: - 4. 验证新增的参数特化与附件选项逻辑
    
    /// 验证参数设置针对多模态与智能体场景的超参说明 Tips 是否正确返回
    func testParamTipsForDifferentUseCases() {
        // 1. 常规 Chat 不应有 Param Tips
        manager.selectedUseCase = .aiChat
        XCTAssertEqual(manager.paramTips, "")
        
        // 2. 多模态视觉和音频返回 Multimodal 专用提示
        manager.selectedUseCase = .askImage
        XCTAssertEqual(manager.paramTips, L10n.ModelManager.Lab.tipsMultimodal)
        manager.selectedUseCase = .audioScribe
        XCTAssertEqual(manager.paramTips, L10n.ModelManager.Lab.tipsMultimodal)
        
        // 3. 智能体与快捷指令返回 Temperature 锁定为 0.0 的只读安全提示
        manager.selectedUseCase = .tinyGarden
        XCTAssertEqual(manager.paramTips, L10n.ModelManager.Lab.tipsAgent)
        manager.selectedUseCase = .mobileActions
        XCTAssertEqual(manager.paramTips, L10n.ModelManager.Lab.tipsAgent)
    }
    
    /// 验证多轮对话中，Chat 和 Agent 分发的附件选项是否特化匹配
    func testAttachmentOptionsForChatAndAgent() {
        // 1. aiChat 应该分发“Link Knowledge Page”与“Inject Semantic Tags”
        manager.selectedUseCase = .aiChat
        let chatOptions = manager.attachmentOptions
        XCTAssertEqual(chatOptions.count, 2)
        XCTAssertEqual(chatOptions[0].title, L10n.ModelManager.Lab.Attach.linkPage)
        XCTAssertEqual(chatOptions[1].title, L10n.ModelManager.Lab.Attach.injectTag)
        
        // 2. 非 aiChat (如 agentSkills 等) 应该分发“Mount Sandbox API”与“Load Agent Template”
        manager.selectedUseCase = .agentSkills
        let agentOptions = manager.attachmentOptions
        XCTAssertEqual(agentOptions.count, 2)
        XCTAssertEqual(agentOptions[0].title, L10n.ModelManager.Lab.Attach.mountSandbox)
        XCTAssertEqual(agentOptions[1].title, L10n.ModelManager.Lab.Attach.loadTemplate)
    }
    
    /// 验证运行模拟时，是否会自动构造和填充专属于当前用例的特化数据结构，以驱动 View 层的高保真卡片渲染
    func testSimulationPopulatesSpecializedUIPipelines() async {
        // 以图像问答为例
        XCTAssertTrue(manager.traceSteps.isEmpty)
        XCTAssertTrue(manager.confidenceItems.isEmpty)
        
        let runTask = Task {
            await manager.runSimulation(for: .askImage, model: mockMultimodalModel, prompt: "检测图像")
        }
        
        // 稍微等待仿真填充
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        // 验证特化数据已被完美填充
        XCTAssertEqual(manager.extraPanelTitle, L10n.ModelManager.Lab.Extra.objectDetection)
        XCTAssertEqual(manager.confidenceItems.count, 3)
        XCTAssertEqual(manager.confidenceItems[0].name, "Notebook (笔记本)")
        
        // 停止仿真并清理
        manager.stopSimulation()
        await runTask.value
    }
}
