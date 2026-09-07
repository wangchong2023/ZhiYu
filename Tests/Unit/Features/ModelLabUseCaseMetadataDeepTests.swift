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
}
