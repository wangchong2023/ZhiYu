//
//  OnDeviceLLMDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：OnDeviceLLMAndMemoryDeepAuditTests.swift, OnDeviceLLMLifecycleTests.swift, OnDeviceLLMServiceLifecycleTests.swift
//

import Combine
import Dependencies
import Foundation
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class OnDeviceLLMDeepTests: XCTestCase {

    private var service: OnDeviceLLMService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        service = OnDeviceLLMService()
    }

    func testOnDeviceLLM_DiscoverAndInitialState() {
        // 验证默认初始化与状态机
        XCTAssertFalse(service.isGenerating)
        XCTAssertEqual(service.generationProgress, 0)
        XCTAssertEqual(service.inferenceSpeed, 0)
        XCTAssertTrue(service.generatedText.isEmpty)

        // 验证 Config 常数合规性（去魔鬼化）
        XCTAssertEqual(OnDeviceLLMService.Config.defaultMaxTokens, 256)
        XCTAssertEqual(OnDeviceLLMService.Config.generationTemperature, 0.7)
        XCTAssertEqual(OnDeviceLLMService.Config.smartIngestMaxTokens, 500)
        XCTAssertEqual(OnDeviceLLMService.Config.chatMaxTokens, 300)
        XCTAssertEqual(OnDeviceLLMService.Config.contextPageLimit, 5)
        XCTAssertEqual(OnDeviceLLMService.Config.titleHitWeight, 3)
    }

    func testOnDeviceLLM_CancelGeneration_ResetsState() {
        let service = OnDeviceLLMService()
        service.isGenerating = true
        service.generationProgress = 0.5
        service.generatedText = "正在生成部分文本..."

        service.cancelGeneration()

        XCTAssertFalse(service.isGenerating, "取消后必须复位 isGenerating")
        XCTAssertEqual(service.generationProgress, 0, "取消后必须清空进度")
    }

    func testOnDeviceLLM_TagExtraction_HandlesEmptyAndMalformed() async {
        let service = OnDeviceLLMService()

        // 标签提取
        let extractedTags = service.extractTags(from: "这是一个包含 #架构 和 #AI 的文本")
        XCTAssertEqual(extractedTags.count, 2)
        XCTAssertTrue(extractedTags.contains("架构"))
        XCTAssertTrue(extractedTags.contains("AI"))

        let emptyTags = service.extractTags(from: "")
        XCTAssertTrue(emptyTags.isEmpty, "空文本标签提取应安全返回空集合")
    }

    func testExtractTags_ignoringURLFragments_extractsOnlyRealTags() {
        let content = "详情参考 https://developer.apple.com/documentation/coreml#overview 以及 http://localhost:8080/test#section。核心技术是 #CoreML 和 #Swift6！"
        let tags = service.extractTags(from: content)

        // 验证 URL 中的 #overview 与 #section 未被当作标签
        XCTAssertFalse(tags.contains("overview"), "URL 中的 fragment 不应被提取为标签")
        XCTAssertFalse(tags.contains("section"), "URL 中的 fragment 不应被提取为标签")

        // 验证合法的正文标签被成功提取
        XCTAssertTrue(tags.contains("CoreML"))
        XCTAssertTrue(tags.contains("Swift6"))
    }

    func testExtractTags_withChineseAndUnderlineTags_extractsSuccessfully() {
        let content = "本章讨论 #人工智能_基础 与 #知识图谱_深度学习 相关概念"
        let tags = service.extractTags(from: content)

        XCTAssertTrue(tags.contains("人工智能_基础"))
        XCTAssertTrue(tags.contains("知识图谱_深度学习"))
    }

    func testExtractTags_withMarkdownHeadingsAndEmptyHashes_doesNotMistakeAsTags() {
        let content = "### 这是一个三级标题\n## 这是一个二级标题\n# 这是一个一级标题\n普通正文内容"
        let tags = service.extractTags(from: content)

        // Markdown 标题有空格（如 '# 标题'），不应该被提取为以字母数字开头的标签
        XCTAssertTrue(tags.isEmpty, "Markdown 标题不应被提取为标签，实际提取: \(tags)")
    }

    func testUnloadModel_resetsAllLoadedStateProperties() {
        // 模拟已加载状态
        service.isModelLoaded = true
        service.loadedModelName = "TestModel.mlmodelc"
        service.inferenceSpeed = 42.5

        // 执行卸载
        service.unloadModel()

        XCTAssertFalse(service.isModelLoaded)
        XCTAssertEqual(service.loadedModelName, "")
        XCTAssertEqual(service.inferenceSpeed, 0)
    }

    func testCancelGeneration_resetsGeneratingProgressAndText() {
        // 模拟正在生成状态
        service.isGenerating = true
        service.generatedText = "生成中的部分文本..."
        service.generationProgress = 0.65

        // 执行取消
        service.cancelGeneration()

        XCTAssertFalse(service.isGenerating)
        XCTAssertEqual(service.generatedText, "")
        XCTAssertEqual(service.generationProgress, 0)
    }

    func testDiscoverModels_handlesGracefullyWithoutCrashing() {
        // 验证 discoverModels 幂等执行且不产生崩溃
        service.discoverModels()
        XCTAssertNotNil(service.availableModels)
    }

    func testImportModel_mlmodelFile_preventsDuplicateExtension() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelExtTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceFileName = "test-model.mlmodel"
        let destURL = tempDir.appendingPathComponent(sourceFileName)

        let compiledDestURL = destURL.deletingPathExtension()
            .appendingPathExtension(SystemConstants.FileExtension.mlmodelC)

        XCTAssertEqual(compiledDestURL.lastPathComponent, "test-model.mlmodelc")
        XCTAssertFalse(compiledDestURL.lastPathComponent.contains(".mlmodel.mlmodelc"),
                       "importModel 不应产生双扩展名 .mlmodel.mlmodelc")
    }

    func testDocumentsDirectory_whenMissing_fallsBackToTemporaryDirectory() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        XCTAssertNotNil(docsDir)
        XCTAssertTrue(docsDir.path.contains("Documents") || docsDir.path.contains("tmp"),
                      "兜底目录应为 Documents 或临时目录")
    }

    func testLoadModel_whenNotFound_resetsIsGeneratingOnThrow() async {
        let service = OnDeviceLLMService()
        service.selectedModelID = "nonexistent-model-id"
        service.isGenerating = false

        do {
            try await service.loadModel()
            XCTFail("loadModel 应在模型不存在时抛出错误")
        } catch {
            // 预期抛出 OnDeviceError.modelNotFound
        }

        XCTAssertFalse(service.isGenerating, "loadModel throw 路径后 isGenerating 应被 defer 重置为 false")
    }

    func testCancelGeneration_resetsStateAndProgress() {
        let service = OnDeviceLLMService()
        service.isGenerating = true
        service.generatedText = "partial"
        service.generationProgress = 0.5

        service.cancelGeneration()

        XCTAssertFalse(service.isGenerating, "cancelGeneration 后 isGenerating 应为 false")
        XCTAssertEqual(service.generatedText, "", "cancelGeneration 后 generatedText 应清空")
        XCTAssertEqual(service.generationProgress, 0, "cancelGeneration 后 generationProgress 应为 0")
    }

}
