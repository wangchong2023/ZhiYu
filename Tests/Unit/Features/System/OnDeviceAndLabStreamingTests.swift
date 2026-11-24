//
//  OnDeviceAndLabStreamingTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/11/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1/L2] 基础设施与功能层单元测试
//  核心职责：针对 OnDeviceLLMService 与 ModelLabManager 的真实端侧推理生命周期（发现、加载、流式思考链、取消、卸载与故障恢复）执行回归验证。
//

import XCTest
@testable import ZhiYuUnitTestHost
import ZhiYuAICore

/// 可控端侧推理后端替身（仅用于测试流式、思考链、取消、卸载与异常路径）
private actor StubLocalInferenceBackend: LocalInferenceBackendProtocol {
    enum StubFailure: LocalizedError {
        case outOfMemory
        var errorDescription: String? { "Simulated GPU OOM" }
    }

    var loadedURL: URL?
    var loadedAccelerator: LocalInferenceAccelerator?
    var lastOptions: LocalInferenceOptions?
    var lastPrompt: String?
    var lastImageCount: Int = 0
    var cancelCallCount: Int = 0
    var unloadCallCount: Int = 0
    var chunksToEmit: [LocalInferenceChunk] = []
    var errorToThrow: Error?

    nonisolated var backendIdentifier: String { "stub-litert-lm" }

    var isLoaded: Bool { loadedURL != nil }

    func configure(chunks: [LocalInferenceChunk], error: Error? = nil) {
        self.chunksToEmit = chunks
        self.errorToThrow = error
    }

    func loadModel(at url: URL?, accelerator: LocalInferenceAccelerator) async throws {
        loadedURL = url
        loadedAccelerator = accelerator
    }

    func unloadModel() async {
        unloadCallCount += 1
        loadedURL = nil
    }

    nonisolated func generateStream(
        prompt: String,
        imageData: [Data],
        audioData: Data?,
        options: LocalInferenceOptions
    ) -> AsyncThrowingStream<LocalInferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.recordInvocation(prompt: prompt, imageCount: imageData.count, options: options)
                if let err = await self.errorToThrow {
                    continuation.finish(throwing: err)
                    return
                }
                for chunk in await self.chunksToEmit {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    func cancelGeneration() async {
        cancelCallCount += 1
    }

    private func recordInvocation(prompt: String, imageCount: Int, options: LocalInferenceOptions) {
        lastPrompt = prompt
        lastImageCount = imageCount
        lastOptions = options
    }
}

@MainActor
final class OnDeviceAndLabStreamingTests: XCTestCase {

    // MARK: - OnDeviceLLMService 发现、加载、流式、错误恢复与卸载

    func testDiscoverModelsFindsLiteRTLMAndMeasuresNonZeroFileSize() throws {
        let fm = FileManager.default
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "unit_test_gemma_\(UUID().uuidString.prefix(8)).litertlm"
        let modelURL = docDir.appendingPathComponent(fileName)
        let payload = Data(repeating: 0x42, count: 40_960)
        try payload.write(to: modelURL)
        defer { try? fm.removeItem(at: modelURL) }

        let service = OnDeviceLLMService(liteRTBackend: StubLocalInferenceBackend())
        service.discoverModels()

        let discovered = service.availableModels.first { $0.url?.lastPathComponent == fileName }
        XCTAssertNotNil(discovered, "discoverModels 必须发现 Documents 中的 .litertlm 模型文件")
        XCTAssertEqual(discovered?.size, Int64(payload.count), "单文件模型体积不应误报为 0 字节")
    }

    func testOnDeviceServiceStreamsThoughtAndAnswerThenUnloadsCleanly() async throws {
        let backend = StubLocalInferenceBackend()
        await backend.configure(chunks: [
            .thought("先分析题意"),
            .text("最终答案是 42"),
            .completed(ttftMilliseconds: 120.0, decodeTokensPerSecond: 38.5)
        ])

        let service = OnDeviceLLMService(liteRTBackend: backend)
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("stub_model.litertlm")
        service.availableModels = [
            OnDeviceModel(id: "downloaded_stub", name: "Stub Gemma", url: fakeURL, size: 1024, type: .downloaded)
        ]
        service.selectedModelID = "downloaded_stub"
        service.preferredAccelerator = .gpu

        try await service.loadModel()
        XCTAssertTrue(service.isModelLoaded)
        let loadedAcc = await backend.loadedAccelerator
        XCTAssertEqual(loadedAcc, .gpu)

        let output = try await service.generate(prompt: "什么是宇宙终极答案", maxTokens: 128)
        XCTAssertEqual(output, "<thought>先分析题意</thought>\n最终答案是 42")
        XCTAssertEqual(service.inferenceSpeed, 38.5, accuracy: 0.01)
        XCTAssertFalse(service.isGenerating)

        // 触发取消应转发至原生后端
        service.cancelGeneration()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cancelCount = await backend.cancelCallCount
        XCTAssertEqual(cancelCount, 1)

        // 卸载后必须释放后端并阻止后续生成
        service.unloadModel()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let unloadCount = await backend.unloadCallCount
        XCTAssertEqual(unloadCount, 1)
        XCTAssertFalse(service.isModelLoaded)

        do {
            _ = try await service.generate(prompt: "after unload")
            XCTFail("卸载后调用 generate 必须抛出 OnDeviceError.modelNotLoaded")
        } catch let error as OnDeviceError {
            XCTAssertEqual(error, .modelNotLoaded)
        }
    }

    func testOnDeviceServiceResetsIsGeneratingWhenBackendThrowsOOM() async throws {
        let backend = StubLocalInferenceBackend()
        await backend.configure(chunks: [], error: StubLocalInferenceBackend.StubFailure.outOfMemory)

        let service = OnDeviceLLMService(liteRTBackend: backend)
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("oom_model.litertlm")
        service.availableModels = [
            OnDeviceModel(id: "downloaded_oom", name: "OOM Gemma", url: fakeURL, size: 1024, type: .downloaded)
        ]
        service.selectedModelID = "downloaded_oom"
        try await service.loadModel()

        do {
            _ = try await service.generate(prompt: "trigger oom")
            XCTFail("后端抛出 OOM 时 generate 必须上抛 OnDeviceError.inferenceFailed")
        } catch let error as OnDeviceError {
            if case .inferenceFailed(let message) = error {
                XCTAssertTrue(message.contains("OOM"))
            } else {
                XCTFail("期望 inferenceFailed，实际为 \(error)")
            }
        }
        XCTAssertFalse(service.isGenerating, "推理抛错后 isGenerating 必须复位，禁止永久锁死")
    }

    // MARK: - ModelLabManager 真实流式、Thinking 透传、取消与异常降级

    func testModelLabManagerStreamsRealLiteRTWithThinkingAndImagePayload() async {
        let backend = StubLocalInferenceBackend()
        await backend.configure(chunks: [
            .thought("识别图中物体"),
            .text("这是一台桌面显示器"),
            .completed(ttftMilliseconds: 145.0, decodeTokensPerSecond: 29.4)
        ])

        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent("gemma4.litertlm")
        let manager = ModelLabManager(
            liteRTBackend: backend,
            localModelURLResolver: { _ in fakeURL }
        )

        let manifest = LLMManifest(
            modelId: "gemma-4-e2b-it",
            displayName: "Gemma 4 E2B",
            vendor: "Google",
            fileSizeInBytes: 1_500_000_000,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/gemma4.litertlm",
            sha256Checksum: "",
            parameterCount: "E2B",
            supportedTasks: ["chat", "multimodal"],
            description: "Gemma 4",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 512)
        )

        await manager.runSimulation(
            for: .aiChat,
            model: manifest,
            prompt: "描述图片",
            imageData: Data([0xFF, 0xD8, 0xFF]),
            temperature: 0.35,
            topP: 0.85,
            enableThinking: true
        )

        XCTAssertFalse(manager.isGenerating)
        XCTAssertEqual(manager.generatedText, "<thought>识别图中物体</thought>\n这是一台桌面显示器")
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 145)
        XCTAssertEqual(manager.currentStats.speed, 29.4, accuracy: 0.01)

        let capturedOptions = await backend.lastOptions
        XCTAssertEqual(capturedOptions?.enableThinking, true)
        XCTAssertEqual(capturedOptions?.temperature ?? 0, 0.35, accuracy: 0.001)
        XCTAssertEqual(capturedOptions?.topP ?? 0, 0.85, accuracy: 0.001)
        let capturedImages = await backend.lastImageCount
        XCTAssertEqual(capturedImages, 1)

        manager.stopSimulation()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cancelCount = await backend.cancelCallCount
        XCTAssertEqual(cancelCount, 1, "stopSimulation 必须立即通知底层 LiteRT 引擎取消生成")
    }
}
