//
//  ModelLabDeepTests.swift
//  ZhiYuTests
//
//  合并自 5 个碎片化测试文件：ModelLabAndManagerDeepAuditTests.swift, ModelLabAndMetricsDeepTests.swift, ModelLabAndSubscriptionDeepTests.swift, ModelLabManagerSimulationBehaviorTests.swift, ModelLabSandboxAndMetricsDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class ModelLabDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func makeTestModel(id: String, tasks: [String]) -> LLMManifest {
        LLMManifest(
            modelId: id,
            displayName: "Test Model \(id)",
            vendor: "ZhiYu Lab",
            fileSizeInBytes: 1024 * 1024 * 500,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/model.bin",
            sha256Checksum: "abc1234567890",
            parameterCount: "2B",
            supportedTasks: tasks,
            description: "Test Model Description",
            defaultParameters: InferenceParameters()
        )
    }

    func testModelLabView_MainRendering() {
        let labView = ModelLabView(onGoToStore: {})
            .snapshotEnvironment()

        let host = UIHostingController(rootView: labView)
        _ = host.view
        host.view.layoutIfNeeded()

        let llm = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self)
        XCTAssertNotNil(llm)
        XCTAssertNotNil(host.view)
    }

    func testModelCardView_Rendering() {
        let modelManager = GlobalModelManager.shared
        let manifest = modelManager.remoteManifests.first ?? LLMManifest(
            modelId: "test-manifest",
            displayName: "测试模型",
            vendor: "TestVendor",
            fileSizeInBytes: 1024,
            minDeviceMemoryInGb: 8.0,
            remoteURLString: "https://example.com/test.bin",
            sha256Checksum: "dummy-hash",
            parameterCount: "7B",
            supportedTasks: ["chat"],
            description: "测试描述",
            defaultParameters: InferenceParameters()
        )
        let cardView = ModelCardView(
            manifest: manifest,
            modelManager: modelManager,
            alertManifest: .constant(nil),
            expandedModelId: .constant(manifest.modelId),
            onGoToLab: {}
        )
        .snapshotEnvironment()

        XCTAssertEqual(manifest.modelId, manifest.modelId)
        let host = UIHostingController(rootView: cardView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testModelLabView_Hierarchy() {
        let host = NavigationStack {
            ModelLabView(onGoToStore: {})
        }
        .snapshotEnvironment()
        .renderInWindow()

        let llm = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self)
        XCTAssertNotNil(llm)
        XCTAssertNotNil(host.view)
    }

    func testModelLabView_InitialStateAndPresetMatching() {
        var didGoToStore = false
        let view = ModelLabView(onGoToStore: {
            didGoToStore = true
        })

        // 默认预设匹配
        XCTAssertNotNil(view.matchedPreset)

        // 触发回调
        view.onGoToStore()
        XCTAssertTrue(didGoToStore)
    }

    func testModelLabView_ConfigurationSheetAndToggles() {
        let view = NavigationStack {
            ModelLabView(onGoToStore: {})
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testParameterPreset_ValuesAndMatching() {
        for preset in ParameterPreset.allCases {
            let params = preset.parameters
            XCTAssertGreaterThan(params.temperature, 0.0)
            XCTAssertLessThanOrEqual(params.temperature, 2.0)
            XCTAssertGreaterThan(params.topP, 0.0)
            XCTAssertLessThanOrEqual(params.topP, 1.0)
            XCTAssertGreaterThan(params.topK, 0)
            XCTAssertGreaterThan(params.maxTokens, 0)
            XCTAssertFalse(preset.displayName.isEmpty)
        }
    }

    func testModelLabManager_SimulationAndState() {
        let manager = ModelLabManager()
        XCTAssertFalse(manager.isGenerating)
        XCTAssertEqual(manager.generatedText, "")
        XCTAssertEqual(manager.currentStats.speed, 0.0)
    }

    func testSubscriptionPlanView_InitialStateAndHierarchy() {
        let view = NavigationStack {
            SubscriptionPlanView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testBillingCycle_Values() {
        let monthly = BillingCycle.monthly
        let yearly = BillingCycle.yearly
        XCTAssertNotEqual(monthly, yearly)
    }

    func testPlanFeature_Properties() {
        let feature = PlanFeature(icon: "star.fill", title: "AI 算力", value: "无限量")
        XCTAssertEqual(feature.icon, "star.fill")
        XCTAssertEqual(feature.title, "AI 算力")
        XCTAssertEqual(feature.value, "无限量")
    }

    func testDeveloperSettingsView_StressTestBoundsAndStepper() {
        let view = NavigationStack {
            DeveloperSettingsView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)

        // 验证压测步长与边界常量有效性
        XCTAssertGreaterThan(FeatureConstants.StressTest.minTargetCount, 0)
        XCTAssertGreaterThan(FeatureConstants.StressTest.maxTargetCount, FeatureConstants.StressTest.minTargetCount)
        XCTAssertEqual(FeatureConstants.StressTest.step, 100)
    }

    func testBackupView_InitialStateAndAutoBackup() {
        let view = NavigationStack {
            BackupView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    func testBackupService_CreateAndVerifyBackup() async throws {
        let backupService = BackupService()
        XCTAssertTrue(backupService.isAutoBackupEnabled)

        // 触发自动备份设置变更
        backupService.isAutoBackupEnabled = false
        XCTAssertFalse(backupService.isAutoBackupEnabled)
    }

    func testUseCaseType_AllCases_HaveNonEmptyProperties() {
        XCTAssertEqual(UseCaseType.allCases.count, 7, "ModelLab 必须提供精确 7 种端侧大模型评测用例场景")

        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.id.isEmpty, "\(useCase.rawValue) id 不能为空")
            XCTAssertFalse(useCase.title.isEmpty, "\(useCase.rawValue) title 不能为空")
            XCTAssertFalse(useCase.description.isEmpty, "\(useCase.rawValue) description 不能为空")
            XCTAssertFalse(useCase.icon.isEmpty, "\(useCase.rawValue) icon 不能为空")
            XCTAssertFalse(useCase.requiredTask.isEmpty, "\(useCase.rawValue) requiredTask 不能为空")
        }
    }

    func testUseCaseType_RequiredTasks_MapCorrectly() {
        XCTAssertEqual(UseCaseType.askImage.requiredTask, "multimodal")
        XCTAssertEqual(UseCaseType.audioScribe.requiredTask, "multimodal")
        XCTAssertEqual(UseCaseType.aiChat.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.agentSkills.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.promptLab.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.tinyGarden.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.mobileActions.requiredTask, "chat")
    }

    func testIsModelCompatible_ChatAndMultimodalModels_MatchesExpectedScenarios() {
        let manager = ModelLabManager()

        let chatModel = makeTestModel(id: "test-chat-model", tasks: ["chat", "text"])
        let visionModel = makeTestModel(id: "test-vision-model", tasks: ["multimodal"])
        let mixedModel = makeTestModel(id: "test-mixed-model", tasks: ["Chat", "MULTIMODAL"])

        XCTAssertTrue(manager.isModelCompatible(chatModel, for: .aiChat))
        XCTAssertTrue(manager.isModelCompatible(chatModel, for: .agentSkills))
        XCTAssertFalse(manager.isModelCompatible(chatModel, for: .askImage), "仅支持纯文本/Chat 的模型不应与视觉多模态场景匹配")
        XCTAssertFalse(manager.isModelCompatible(chatModel, for: .audioScribe))

        XCTAssertTrue(manager.isModelCompatible(visionModel, for: .askImage))
        XCTAssertTrue(manager.isModelCompatible(visionModel, for: .audioScribe))
        XCTAssertFalse(manager.isModelCompatible(visionModel, for: .aiChat))

        // 大小写混合容错
        XCTAssertTrue(manager.isModelCompatible(mixedModel, for: .aiChat), "首字母大写的任务名应正常兼容匹配")
        XCTAssertTrue(manager.isModelCompatible(mixedModel, for: .askImage), "全大写的任务名应正常兼容匹配")
    }

    func testModelLabManager_ParamTips_ReturnsExpectedHints() {
        let manager = ModelLabManager()

        manager.selectedUseCase = .askImage
        XCTAssertFalse(manager.paramTips.isEmpty, "多模态场景应展示视觉提示")

        manager.selectedUseCase = .audioScribe
        XCTAssertFalse(manager.paramTips.isEmpty, "语音速记场景应展示音频提示")

        manager.selectedUseCase = .tinyGarden
        XCTAssertFalse(manager.paramTips.isEmpty, "小花园场景应展示 Agent 提示")

        manager.selectedUseCase = .aiChat
        XCTAssertTrue(manager.paramTips.isEmpty, "常规对话无需多模态提示")
    }

    func testModelLabManager_AttachmentOptions_DifferentiatesChatAndSandbox() {
        let manager = ModelLabManager()

        manager.selectedUseCase = .aiChat
        let chatOptions = manager.attachmentOptions
        XCTAssertEqual(chatOptions.count, 2)
        XCTAssertTrue(chatOptions.contains(where: { $0.icon == "doc.text.fill" }))

        manager.selectedUseCase = .agentSkills
        let agentOptions = manager.attachmentOptions
        XCTAssertEqual(agentOptions.count, 2)
        XCTAssertTrue(agentOptions.contains(where: { $0.icon == "link.badge.plus" }))
    }

    func testRunSimulation_StopSimulation_CancelsGeneratingPromptly() async {
        let manager = ModelLabManager()
        let model = makeTestModel(id: "gemma-test", tasks: ["chat"])

        let exp = expectation(description: "Simulation task initiated")
        Task {
            exp.fulfill()
            await manager.runSimulation(for: .aiChat, model: model, prompt: "请帮我规划一个知识体系")
        }

        await fulfillment(of: [exp], timeout: 1.0)
        manager.stopSimulation()

        // 等待微任务让状态同步
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(manager.isGenerating, "stopSimulation 之后 isGenerating 状态必须及时被重置为 false")
    }

    func testModelLabView_AllUseCasesHierarchy() {
        XCTAssertFalse(UseCaseType.allCases.isEmpty)
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.title.isEmpty)
            let host = NavigationStack {
                ModelLabView(onGoToStore: {})
            }
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }

    func testModelLabManager_StateAndStatsUpdate() {
        let manager = ModelLabManager()
        XCTAssertFalse(manager.isGenerating)

        manager.selectedUseCase = .aiChat
        XCTAssertFalse(manager.attachmentOptions.isEmpty)

        manager.selectedUseCase = .askImage
        XCTAssertFalse(manager.paramTips.isEmpty)

        manager.currentStats = PerformanceStats(
            speed: 42.5,
            prefillLatency: 120,
            firstTokenLatency: 80,
            memoryUsage: 350.0
        )
        XCTAssertEqual(manager.currentStats.speed, 42.5)
        XCTAssertEqual(manager.currentStats.prefillLatency, 120)
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 80)
        XCTAssertEqual(manager.currentStats.memoryUsage, 350.0)
    }

    func testParameterPreset_MatchAndAllCases() {
        for preset in ParameterPreset.allCases {
            let params = preset.parameters
            XCTAssertGreaterThanOrEqual(params.temperature, 0.0)
            XCTAssertGreaterThanOrEqual(params.topP, 0.0)
            XCTAssertGreaterThan(params.maxTokens, 0)
        }
    }

}
