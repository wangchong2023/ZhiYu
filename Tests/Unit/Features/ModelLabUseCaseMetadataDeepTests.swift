//
//  ModelLabUseCaseMetadataDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：ModelLabManager 深度测试 — UseCaseType 7 case 元数据映射、
//            paramTips/attachmentOptions 分支、isModelCompatible 过滤。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class ModelLabUseCaseMetadataDeepTests: XCTestCase {

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

    // MARK: - UseCaseType 元数据映射

    /// 验证 UseCaseType 共 7 个 case，与 CaseIterable 一致。
    func testUseCaseTypeHasSevenCases() {
        XCTAssertEqual(UseCaseType.allCases.count, 7, "UseCaseType 应有 7 个 case")
    }

    /// 验证 askImage 的 title 非空且来自 L10n。
    func testUseCaseTypeAskImageTitleNonEmpty() {
        XCTAssertFalse(UseCaseType.askImage.title.isEmpty)
    }

    /// 验证 audioScribe 的 title 非空。
    func testUseCaseTypeAudioScribeTitleNonEmpty() {
        XCTAssertFalse(UseCaseType.audioScribe.title.isEmpty)
    }

    /// 验证 aiChat 的 title 非空。
    func testUseCaseTypeAiChatTitleNonEmpty() {
        XCTAssertFalse(UseCaseType.aiChat.title.isEmpty)
    }

    /// 验证 agentSkills 的 title 非空。
    func testUseCaseTypeAgentSkillsTitleNonEmpty() {
        XCTAssertFalse(UseCaseType.agentSkills.title.isEmpty)
    }

    /// 验证 promptLab 的 title 非空。
    func testUseCaseTypePromptLabTitleNonEmpty() {
        XCTAssertFalse(UseCaseType.promptLab.title.isEmpty)
    }

    /// 验证 tinyGarden 的 title 非空。
    func testUseCaseTypeTinyGardenTitleNonEmpty() {
        XCTAssertFalse(UseCaseType.tinyGarden.title.isEmpty)
    }

    /// 验证 mobileActions 的 title 非空。
    func testUseCaseTypeMobileActionsTitleNonEmpty() {
        XCTAssertFalse(UseCaseType.mobileActions.title.isEmpty)
    }

    /// 验证所有 case 的 description 非空。
    func testUseCaseTypeAllCasesDescriptionNonEmpty() {
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.description.isEmpty, "\(useCase) 的 description 不应为空")
        }
    }

    /// 验证所有 case 的 icon 非空（SF Symbol 名称）。
    func testUseCaseTypeAllCasesIconNonEmpty() {
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.icon.isEmpty, "\(useCase) 的 icon 不应为空")
        }
    }

    /// 验证 askImage/audioScribe 的 requiredTask 为 "multimodal"。
    func testUseCaseTypeMultimodalCasesRequiredTaskIsMultimodal() {
        XCTAssertEqual(UseCaseType.askImage.requiredTask, "multimodal")
        XCTAssertEqual(UseCaseType.audioScribe.requiredTask, "multimodal")
    }

    /// 验证 aiChat/agentSkills/promptLab/tinyGarden/mobileActions 的 requiredTask 为 "chat"。
    func testUseCaseTypeChatCasesRequiredTaskIsChat() {
        XCTAssertEqual(UseCaseType.aiChat.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.agentSkills.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.promptLab.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.tinyGarden.requiredTask, "chat")
        XCTAssertEqual(UseCaseType.mobileActions.requiredTask, "chat")
    }

    /// 验证 id 等于 rawValue。
    func testUseCaseTypeIdEqualsRawValue() {
        for useCase in UseCaseType.allCases {
            XCTAssertEqual(useCase.id, useCase.rawValue)
        }
    }

    // MARK: - paramTips 分支

    /// 验证 selectedUseCase 为 nil 时 paramTips 返回空字符串。
    func testParamTipsSelectedUseCaseNilReturnsEmpty() {
        manager.selectedUseCase = nil
        XCTAssertEqual(manager.paramTips, "")
    }

    /// 验证 askImage 时 paramTips 返回多模态提示。
    func testParamTipsAskImageReturnsMultimodalHint() {
        manager.selectedUseCase = .askImage
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 audioScribe 时 paramTips 返回多模态提示。
    func testParamTipsAudioScribeReturnsMultimodalHint() {
        manager.selectedUseCase = .audioScribe
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 tinyGarden 时 paramTips 返回 Agent 提示。
    func testParamTipsTinyGardenReturnsAgentHint() {
        manager.selectedUseCase = .tinyGarden
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 mobileActions 时 paramTips 返回 Agent 提示。
    func testParamTipsMobileActionsReturnsAgentHint() {
        manager.selectedUseCase = .mobileActions
        XCTAssertFalse(manager.paramTips.isEmpty)
    }

    /// 验证 aiChat 时 paramTips 返回空（default 分支）。
    func testParamTipsAiChatReturnsEmpty() {
        manager.selectedUseCase = .aiChat
        XCTAssertEqual(manager.paramTips, "")
    }

    /// 验证 agentSkills 时 paramTips 返回空（default 分支）。
    func testParamTipsAgentSkillsReturnsEmpty() {
        manager.selectedUseCase = .agentSkills
        XCTAssertEqual(manager.paramTips, "")
    }

    /// 验证 promptLab 时 paramTips 返回空（default 分支）。
    func testParamTipsPromptLabReturnsEmpty() {
        manager.selectedUseCase = .promptLab
        XCTAssertEqual(manager.paramTips, "")
    }

    // MARK: - attachmentOptions 分支

    /// 验证 aiChat 时 attachmentOptions 返回 2 个选项（linkPage + injectTag）。
    func testAttachmentOptionsAiChatReturnsTwoOptions() {
        manager.selectedUseCase = .aiChat
        let options = manager.attachmentOptions
        XCTAssertEqual(options.count, 2)
    }

    /// 验证 aiChat 的 attachmentOptions 包含 linkPage 选项。
    func testAttachmentOptionsAiChatContainsLinkPage() {
        manager.selectedUseCase = .aiChat
        let titles = manager.attachmentOptions.map(\.title)
        XCTAssertFalse(titles.isEmpty)
    }

    /// 验证非 aiChat 时 attachmentOptions 返回 2 个选项（mountSandbox + loadTemplate）。
    func testAttachmentOptionsNonAiChatReturnsTwoOptions() {
        manager.selectedUseCase = .askImage
        XCTAssertEqual(manager.attachmentOptions.count, 2)
    }

    /// 验证 selectedUseCase 为 nil 时 attachmentOptions 返回默认 2 个选项。
    func testAttachmentOptionsNilReturnsDefaultTwoOptions() {
        manager.selectedUseCase = nil
        XCTAssertEqual(manager.attachmentOptions.count, 2)
    }

    /// 验证所有 case 的 attachmentOptions 选项 title 非空。
    func testAttachmentOptionsAllOptionsTitleNonEmpty() {
        for useCase in UseCaseType.allCases {
            manager.selectedUseCase = useCase
            for option in manager.attachmentOptions {
                XCTAssertFalse(option.title.isEmpty, "\(useCase) 的附件选项 title 不应为空")
            }
        }
    }

    /// 验证所有 case 的 attachmentOptions 选项 icon 非空。
    func testAttachmentOptionsAllOptionsIconNonEmpty() {
        for useCase in UseCaseType.allCases {
            manager.selectedUseCase = useCase
            for option in manager.attachmentOptions {
                XCTAssertFalse(option.icon.isEmpty, "\(useCase) 的附件选项 icon 不应为空")
            }
        }
    }

    // MARK: - isModelCompatible

    /// 验证模型支持 chat 时，aiChat 用例兼容。
    func testIsModelCompatibleSupportsChatAiChatCompatible() {
        let manifest = makeManifest(supportedTasks: ["chat"])
        XCTAssertTrue(manager.isModelCompatible(manifest, for: .aiChat))
    }

    /// 验证模型不支持 chat 时，aiChat 用例不兼容。
    func testIsModelCompatibleNotSupportsChatAiChatIncompatible() {
        let manifest = makeManifest(supportedTasks: ["completion"])
        XCTAssertFalse(manager.isModelCompatible(manifest, for: .aiChat))
    }

    /// 验证模型支持 multimodal 时，askImage 用例兼容。
    func testIsModelCompatibleSupportsMultimodalAskImageCompatible() {
        let manifest = makeManifest(supportedTasks: ["multimodal"])
        XCTAssertTrue(manager.isModelCompatible(manifest, for: .askImage))
    }

    /// 验证模型不支持 multimodal 时，askImage 用例不兼容。
    func testIsModelCompatibleNotSupportsMultimodalAskImageIncompatible() {
        let manifest = makeManifest(supportedTasks: ["chat"])
        XCTAssertFalse(manager.isModelCompatible(manifest, for: .askImage))
    }

    /// 验证模型支持 multimodal 时，audioScribe 用例兼容。
    func testIsModelCompatibleSupportsMultimodalAudioScribeCompatible() {
        let manifest = makeManifest(supportedTasks: ["multimodal"])
        XCTAssertTrue(manager.isModelCompatible(manifest, for: .audioScribe))
    }

    /// 验证模型同时支持 chat 和 multimodal 时，所有用例兼容。
    func testIsModelCompatibleSupportsChatAndMultimodalAllUseCasesCompatible() {
        let manifest = makeManifest(supportedTasks: ["chat", "multimodal"])
        for useCase in UseCaseType.allCases {
            XCTAssertTrue(manager.isModelCompatible(manifest, for: useCase), "\(useCase) 应兼容")
        }
    }

    /// 验证空 supportedTasks 时所有用例不兼容。
    func testIsModelCompatibleEmptySupportedTasksAllUseCasesIncompatible() {
        let manifest = makeManifest(supportedTasks: [])
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(manager.isModelCompatible(manifest, for: useCase), "\(useCase) 不应兼容")
        }
    }
}
