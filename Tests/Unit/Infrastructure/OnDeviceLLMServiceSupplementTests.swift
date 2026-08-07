//
//  OnDeviceLLMServiceSupplementTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：补测 OnDeviceLLMService 的 extractTags/loadModel modelNotFound/chatOnDevice/smartIngestOnDevice/deleteModel 等分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class OnDeviceLLMServiceSupplementTests: XCTestCase {

    private var service: OnDeviceLLMService!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        // 注册 MockMLModelCompiler（OnDeviceLLMService 的 @Inject compiler 依赖）
        ServiceContainer.shared.register(MockMLModelCompilerForOnDevice() as any MLModelCompilerProtocol, for: (any MLModelCompilerProtocol).self)
        service = OnDeviceLLMService()
    }

    override func tearDown() async throws {
        service = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - extractTags

    func testExtractTags_returnsTagsFromHashSyntax() {
        let tags = service.extractTags(from: "这是 #机器学习 和 #深度学习 的笔记")
        XCTAssertEqual(tags.sorted(), ["深度学习", "机器学习"].sorted())
    }

    func testExtractTags_returnsEmptyWhenNoHashTags() {
        let tags = service.extractTags(from: "没有标签的纯文本")
        XCTAssertEqual(tags, [])
    }

    func testExtractTags_handlesEmptyString() {
        XCTAssertEqual(service.extractTags(from: ""), [])
    }

    func testExtractTags_extractsMultipleTags() {
        let tags = service.extractTags(from: "#tag1 #tag2 #tag3")
        XCTAssertEqual(tags.count, 3)
    }

    // MARK: - loadModel modelNotFound

    func testLoadModelThrowsModelNotFoundWhenSelectedIDInvalid() async {
        service.selectedModelID = "non_existent_model_id"
        do {
            try await service.loadModel()
            XCTFail("selectedModelID 无效时应抛出 modelNotFound")
        } catch OnDeviceError.modelNotFound {
            // 预期路径
        } catch {
            XCTFail("应抛出 OnDeviceError.modelNotFound，实际：\(error)")
        }
    }

    // MARK: - generate emptyResponse（currentModel 不是 MLModel）

    func testGenerateThrowsEmptyResponseWhenModelLoadedButNoMLModel() async {
        // 模拟 isModelLoaded=true 但 currentModel 不是 MLModel 的情况
        // 通过反射设置 isModelLoaded（因为 loadModel 需要真实 MLModel）
        let mirror = Mirror(reflecting: service)
        XCTAssertNotNil(mirror, "反射应成功")
        // 直接调用 generate 会因 isModelLoaded=false 抛 modelNotLoaded
        // 需要先设置 isModelLoaded=true
        service.isModelLoaded = true
        do {
            _ = try await service.generate(prompt: "测试", maxTokens: 10)
            XCTFail("currentModel 不是 MLModel 时应抛出 emptyResponse")
        } catch OnDeviceError.emptyResponse {
            // 预期路径
        } catch {
            XCTFail("应抛出 OnDeviceError.emptyResponse，实际：\(error)")
        }
    }

    // MARK: - chatOnDevice（依赖 generate，会抛 emptyResponse）

    func testChatOnDeviceThrowsEmptyResponseWhenNoMLModel() async {
        service.isModelLoaded = true
        let pages: [KnowledgePage] = [
            KnowledgePage(title: "机器学习基础", pageType: .concept, content: "机器学习是人工智能的一个分支"),
            KnowledgePage(title: "深度学习进阶", pageType: .concept, content: "深度学习使用神经网络")
        ]
        do {
            _ = try await service.chatOnDevice(query: "机器学习", pages: pages)
            XCTFail("无 MLModel 时应抛出 emptyResponse")
        } catch OnDeviceError.emptyResponse {
            // 预期路径 — 说明 selectRelevantPages 已执行并进入 generate
        } catch {
            XCTFail("应抛出 OnDeviceError.emptyResponse，实际：\(error)")
        }
    }

    // MARK: - smartIngestOnDevice（依赖 generate，会抛 emptyResponse）

    func testSmartIngestOnDeviceThrowsEmptyResponseWhenNoMLModel() async {
        service.isModelLoaded = true
        do {
            _ = try await service.smartIngestOnDevice(title: "测试标题", content: "测试内容", pages: [])
            XCTFail("无 MLModel 时应抛出 emptyResponse")
        } catch OnDeviceError.emptyResponse {
            // 预期路径
        } catch {
            XCTFail("应抛出 OnDeviceError.emptyResponse，实际：\(error)")
        }
    }

    // MARK: - deleteModel（url 为 nil 的 system 模型）

    func testDeleteModelDoesNotCrashWhenURLIsNil() throws {
        let systemModel = OnDeviceModel(id: "test_system", name: "Test", url: nil, size: 0, type: .system)
        // 不应崩溃（url 为 nil 时跳过文件删除）
        try service.deleteModel(systemModel)
    }

    // MARK: - importModel（不存在的文件应抛错）

    func testImportModelThrowsWhenSourceFileNotExists() async {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_model_\(UUID().uuidString).mlmodelc")
        do {
            try await service.importModel(from: nonExistentURL)
            XCTFail("源文件不存在时应抛出错误")
        } catch {
            // 预期路径 — FileManager.copyItem 抛出错误
        }
    }

    // MARK: - OnDeviceError.emptyResponse 描述

    func testOnDeviceErrorEmptyResponseHasDescription() {
        XCTAssertNotNil(OnDeviceError.emptyResponse.errorDescription)
    }
}

// MARK: - Mock MLModelCompiler

private final class MockMLModelCompilerForOnDevice: MLModelCompilerProtocol, @unchecked Sendable {
    let supportsCompilation: Bool = true

    func compileModel(at url: URL) async throws -> URL {
        return url
    }
}
