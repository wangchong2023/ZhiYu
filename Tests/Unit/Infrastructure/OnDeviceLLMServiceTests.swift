//
//  OnDeviceLLMServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证端侧 LLM 服务的状态管理、模型卸载、生成取消与错误类型语义。
//

import XCTest
@testable import ZhiYu

@MainActor
final class OnDeviceLLMServiceTests: XCTestCase {

    // MARK: - 测试夹具

    private func makeService() -> OnDeviceLLMService {
        OnDeviceLLMService()
    }

    // MARK: - 初始化与可用性

    func testInit_isAvailable_reflectsIOSVersion() {
        let service = OnDeviceLLMService()

        if #available(iOS 17.0, *) {
            XCTAssertTrue(service.isAvailable, "iOS 17+ 应可用")
        } else {
            XCTAssertFalse(service.isAvailable, "iOS 17 以下应不可用")
        }
    }

    func testInit_initialState_isModelLoadedFalse() {
        let service = OnDeviceLLMService()

        XCTAssertFalse(service.isModelLoaded, "初始状态模型未加载")
    }

    func testInit_initialState_isGeneratingFalse() {
        let service = OnDeviceLLMService()

        XCTAssertFalse(service.isGenerating, "初始状态不在生成中")
    }

    func testInit_initialState_loadedModelNameEmpty() {
        let service = OnDeviceLLMService()

        XCTAssertEqual(service.loadedModelName, "", "初始状态模型名称为空")
    }

    func testInit_initialState_generationProgressZero() {
        let service = OnDeviceLLMService()

        XCTAssertEqual(service.generationProgress, 0, "初始状态进度为 0")
    }

    // MARK: - cancelGeneration

    func testCancelGeneration_resetsGeneratingState() {
        let service = OnDeviceLLMService()

        service.cancelGeneration()

        XCTAssertFalse(service.isGenerating, "取消后应不在生成中")
    }

    func testCancelGeneration_resetsGeneratedText() {
        let service = OnDeviceLLMService()

        service.cancelGeneration()

        XCTAssertEqual(service.generatedText, "", "取消后生成文本应为空")
    }

    func testCancelGeneration_resetsProgress() {
        let service = OnDeviceLLMService()

        service.cancelGeneration()

        XCTAssertEqual(service.generationProgress, 0, "取消后进度应为 0")
    }

    // MARK: - unloadModel

    func testUnloadModel_resetsIsModelLoaded() {
        let service = OnDeviceLLMService()

        service.unloadModel()

        XCTAssertFalse(service.isModelLoaded, "卸载后模型未加载")
    }

    func testUnloadModel_clearsLoadedModelName() {
        let service = OnDeviceLLMService()

        service.unloadModel()

        XCTAssertEqual(service.loadedModelName, "", "卸载后模型名称为空")
    }

    func testUnloadModel_resetsInferenceSpeed() {
        let service = OnDeviceLLMService()

        service.unloadModel()

        XCTAssertEqual(service.inferenceSpeed, 0, "卸载后推理速度为 0")
    }

    // MARK: - generate 未加载模型时抛错

    func testGenerate_modelNotLoaded_throwsError() async {
        let service = OnDeviceLLMService()

        do {
            _ = try await service.generate(prompt: "test", maxTokens: 10)
            XCTFail("未加载模型时应抛出错误")
        } catch {
            guard case OnDeviceError.modelNotLoaded = error else {
                XCTFail("应抛出 modelNotLoaded 错误，收到: \(error)")
                return
            }
        }
    }

    // MARK: - OnDeviceModel DTO

    func testOnDeviceModel_sizeLabel_formatsCorrectly() {
        let model = OnDeviceModel(
            id: "test",
            name: "Test",
            url: nil,
            size: 1024,
            type: .bundled
        )

        XCTAssertFalse(model.sizeLabel.isEmpty, "sizeLabel 不应为空")
    }

    func testOnDeviceModel_icon_bundledType() {
        let model = OnDeviceModel(id: "t", name: "T", url: nil, size: 0, type: .bundled)
        XCTAssertEqual(model.icon, "cube.box.fill")
    }

    func testOnDeviceModel_icon_downloadedType() {
        let model = OnDeviceModel(id: "t", name: "T", url: nil, size: 0, type: .downloaded)
        XCTAssertEqual(model.icon, "arrow.down.circle.fill")
    }

    func testOnDeviceModel_icon_systemType() {
        let model = OnDeviceModel(id: "t", name: "T", url: nil, size: 0, type: .system)
        XCTAssertEqual(model.icon, "apple.logo")
    }

    // MARK: - OnDeviceError

    func testOnDeviceError_modelNotFound_hasDescription() {
        XCTAssertNotNil(OnDeviceError.modelNotFound.errorDescription)
    }

    func testOnDeviceError_modelNotLoaded_hasDescription() {
        XCTAssertNotNil(OnDeviceError.modelNotLoaded.errorDescription)
    }

    func testOnDeviceError_notSupported_hasDescription() {
        XCTAssertNotNil(OnDeviceError.notSupported.errorDescription)
    }

    func testOnDeviceError_inferenceFailed_containsMessage() {
        let desc = OnDeviceError.inferenceFailed("test error").errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("test error") == true, "应包含错误消息")
    }

    func testOnDeviceError_compilationFailed_hasDescription() {
        XCTAssertNotNil(OnDeviceError.compilationFailed.errorDescription)
    }

    // MARK: - Config 常量

    func testConfig_defaultMaxTokens_is256() {
        XCTAssertEqual(OnDeviceLLMService.Config.defaultMaxTokens, 256)
    }

    func testConfig_generationTemperature_is07() {
        XCTAssertEqual(OnDeviceLLMService.Config.generationTemperature, 0.7)
    }

    func testConfig_smartIngestMaxTokens_is500() {
        XCTAssertEqual(OnDeviceLLMService.Config.smartIngestMaxTokens, 500)
    }

    func testConfig_chatMaxTokens_is300() {
        XCTAssertEqual(OnDeviceLLMService.Config.chatMaxTokens, 300)
    }

    func testConfig_contextPageLimit_is5() {
        XCTAssertEqual(OnDeviceLLMService.Config.contextPageLimit, 5)
    }

    func testConfig_contentPreviewChars_is200() {
        XCTAssertEqual(OnDeviceLLMService.Config.contentPreviewChars, 200)
    }
}
