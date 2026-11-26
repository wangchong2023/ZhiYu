//
//  LocalInferenceBackendProtocolTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证端侧推理后端契约类型边界（非法 JSON 解码拦截、默认采样参数合法性、Equatable 差异判定）。
//

import CoreGraphics
import XCTest
@testable import ZhiYuAICore

final class LocalInferenceBackendProtocolTests: XCTestCase {

    private enum TestConstants {
        static let samplePrompt = "Summarize quantum computing"
        static let samplePayloadByte: UInt8 = 0xAB
        static let imageWidth = 4
        static let imageHeight = 4
        static let bitsPerComponent = 8
        static let bytesPerPixel = 4
        static let startNano: UInt64 = 10_000_000_000
        static let earlierNano: UInt64 = 5_000_000_000
        static let firstTokenNano: UInt64 = 10_250_000_000
        static let endNano: UInt64 = 12_000_000_000
        static let generatedChars = 40
        static let negativeChars = -12
        static let expectedTTFTMs = 250.0
        static let expectedDecodeTPS = 5.0
        static let accuracy = 0.001
        static let similarityThreshold: Float = 0.99
    }

    private func makeRGBTestImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = TestConstants.imageWidth * TestConstants.bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: TestConstants.imageWidth,
            height: TestConstants.imageHeight,
            bitsPerComponent: TestConstants.bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        context.setFillColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: TestConstants.imageWidth, height: TestConstants.imageHeight))
        return context.makeImage()
    }

    func testAcceleratorDecodeRejectsUnknownHardwareString() {
        let invalidJSON = Data("\"TPU_UNKNOWN\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(LocalInferenceAccelerator.self, from: invalidJSON)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("未知加速器值应抛出 DecodingError.dataCorrupted，实际为 \(error)")
                return
            }
        }
    }

    func testAcceleratorRoundTripPreservesExactWireFormat() throws {
        let expectedWire: [LocalInferenceAccelerator: String] = [
            .auto: "\"AUTO\"",
            .cpu: "\"CPU\"",
            .gpu: "\"GPU\"",
            .npu: "\"NPU\""
        ]
        for (value, wire) in expectedWire {
            let encoded = try JSONEncoder().encode(value)
            XCTAssertEqual(String(data: encoded, encoding: .utf8), wire)
            let decoded = try JSONDecoder().decode(LocalInferenceAccelerator.self, from: encoded)
            XCTAssertEqual(decoded, value)
        }
    }

    func testInferenceOptionsDefaultsWithinValidSamplingBounds() {
        let defaults = LocalInferenceOptions()
        XCTAssertGreaterThanOrEqual(defaults.temperature, 0.0)
        XCTAssertLessThanOrEqual(defaults.temperature, 2.0)
        XCTAssertGreaterThan(defaults.topP, 0.0)
        XCTAssertLessThanOrEqual(defaults.topP, 1.0)
        XCTAssertGreaterThan(defaults.topK, 0)
        XCTAssertGreaterThan(defaults.maxTokens, 0)
        XCTAssertFalse(defaults.enableThinking)
        XCTAssertEqual(defaults.accelerator, .auto)
    }

    func testLiteRTBackendIsLinkedAndRejectsMissingModelFiles() async {
        XCTAssertTrue(LiteRTInferenceBackend.isRuntimeLinked, "macOS/iOS 必须成功链接开源 LiteRTLM 二进制运行时")
        let backend = LiteRTInferenceBackend()

        do {
            try await backend.loadModel(at: nil, accelerator: .gpu)
            XCTFail("nil URL 必须抛出 LiteRTBackendError.missingModelFile")
        } catch let error as LiteRTBackendError {
            XCTAssertEqual(error, .missingModelFile(""))
        } catch {
            XCTFail("非预期错误类型: \(error)")
        }

        let missingURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).litertlm")
        do {
            try await backend.loadModel(at: missingURL, accelerator: .cpu)
            XCTFail("不存在的模型路径必须抛出 LiteRTBackendError.missingModelFile")
        } catch let error as LiteRTBackendError {
            XCTAssertEqual(error, .missingModelFile(missingURL.path))
        } catch {
            XCTFail("非预期错误类型: \(error)")
        }
    }

    func testLiteRTBackendGenerateStreamThrowsWhenEmptyPromptOrNotLoaded() async {
        let backend = LiteRTInferenceBackend()

        do {
            for try await _ in backend.generateStream(
                prompt: "   ",
                imageData: [],
                audioData: nil,
                options: LocalInferenceOptions()
            ) {}
            XCTFail("空 Prompt 必须抛出 LiteRTBackendError.emptyPrompt")
        } catch let error as LiteRTBackendError {
            XCTAssertEqual(error, .emptyPrompt)
        } catch {
            XCTFail("非预期错误类型: \(error)")
        }

        do {
            for try await _ in backend.generateStream(
                prompt: "Hello Gemma 4",
                imageData: [],
                audioData: nil,
                options: LocalInferenceOptions(enableThinking: true, accelerator: .gpu)
            ) {}
            XCTFail("未加载模型直接推理必须抛出 LiteRTBackendError.modelNotLoaded")
        } catch let error as LiteRTBackendError {
            XCTAssertEqual(error, .modelNotLoaded)
        } catch {
            XCTFail("非预期错误类型: \(error)")
        }
    }

    func testLiteRTEmbeddingEngineRejectsMissingModelAndFallsBackCleanly() async throws {
        let engine = LiteRTMultimodalEmbeddingEngine()
        let missingURL = URL(fileURLWithPath: "/tmp/missing_embed_\(UUID().uuidString).litertlm")

        do {
            try await engine.loadModel(at: missingURL)
            XCTFail("不存在的向量模型路径必须抛出 LiteRTBackendError.missingModelFile")
        } catch let error as LiteRTBackendError {
            XCTAssertEqual(error, .missingModelFile(missingURL.path))
        }

        let isLoaded = await engine.isNativeModelLoaded
        XCTAssertFalse(isLoaded)

        // 未加载原生模型时必须优雅降级并输出合法 768 维归一化向量
        let vec = try await engine.embedText("blue ocean sky")
        XCTAssertEqual(vec.count, MultimodalEmbeddingEngine.Constants.defaultDimension)
        XCTAssertGreaterThan(engine.cosineSimilarity(vec, vec), TestConstants.similarityThreshold)

        // 未加载原生模型时图像嵌入必须降级至 fallbackEngine
        let image = try XCTUnwrap(makeRGBTestImage())
        let imgVec = try await engine.embedImage(image)
        XCTAssertEqual(imgVec.count, MultimodalEmbeddingEngine.Constants.defaultDimension)
        XCTAssertGreaterThan(engine.cosineSimilarity(imgVec, imgVec), TestConstants.similarityThreshold)

        await engine.unloadModel()
        let stillLoaded = await engine.isNativeModelLoaded
        XCTAssertFalse(stillLoaded)
    }

    func testLiteRTBackendRejectsDirectoryURLAsModelPath() async {
        let dirURL = FileManager.default.temporaryDirectory
        let backend = LiteRTInferenceBackend()
        do {
            try await backend.loadModel(at: dirURL, accelerator: .cpu)
            XCTFail("传入目录路径必须被拦截并抛出 missingModelFile")
        } catch let error as LiteRTBackendError {
            XCTAssertEqual(error, .missingModelFile(dirURL.path))
        } catch {
            XCTFail("非预期错误类型: \(error)")
        }

        let embedEngine = LiteRTMultimodalEmbeddingEngine()
        do {
            try await embedEngine.loadModel(at: dirURL)
            XCTFail("向量引擎传入目录路径必须被拦截并抛出 missingModelFile")
        } catch let error as LiteRTBackendError {
            XCTAssertEqual(error, .missingModelFile(dirURL.path))
        } catch {
            XCTFail("非预期错误类型: \(error)")
        }
    }

    func testLiteRTBackendRejectsCorruptedModelFileWithoutLeavingDirtyState() async throws {
        let corruptedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupted_\(UUID().uuidString).litertlm")
        try Data([TestConstants.samplePayloadByte]).write(to: corruptedURL)
        defer { try? FileManager.default.removeItem(at: corruptedURL) }

        let backend = LiteRTInferenceBackend()
        do {
            try await backend.loadModel(at: corruptedURL, accelerator: .cpu)
            XCTFail("损坏的模型文件初始化应抛出运行时错误")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        await backend.cancelGeneration()
        await backend.unloadModel()

        let embedEngine = LiteRTMultimodalEmbeddingEngine()
        do {
            try await embedEngine.loadModel(at: corruptedURL)
            XCTFail("损坏的向量模型初始化应抛出运行时错误")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        let isLoaded = await embedEngine.isNativeModelLoaded
        XCTAssertFalse(isLoaded, "初始化失败后不得残留已加载状态")
    }

    func testLiteRTBackendErrorDescriptionsAreNonEmpty() {
        let cases: [LiteRTBackendError] = [
            .runtimeUnavailable,
            .missingModelFile("/tmp/model.litertlm"),
            .modelNotLoaded,
            .emptyPrompt
        ]
        for error in cases {
            let desc = error.errorDescription ?? ""
            XCTAssertFalse(desc.isEmpty, "错误 \(error) 必须提供非空描述")
        }
    }

    func testComputeStreamMetricsHandlesClockRegressionAndNegativeCharsSafely() {
        let normal = LiteRTInferenceBackend.computeStreamMetrics(
            startNano: TestConstants.startNano,
            firstTokenNano: TestConstants.firstTokenNano,
            endNano: TestConstants.endNano,
            generatedChars: TestConstants.generatedChars
        )
        XCTAssertEqual(normal.ttftMilliseconds, TestConstants.expectedTTFTMs, accuracy: TestConstants.accuracy)
        XCTAssertEqual(normal.decodeTokensPerSecond, TestConstants.expectedDecodeTPS, accuracy: TestConstants.accuracy)

        // 时钟回拨（earlierNano < startNano）与负数字符不得触发 UInt64 下溢崩溃
        let regressed = LiteRTInferenceBackend.computeStreamMetrics(
            startNano: TestConstants.startNano,
            firstTokenNano: TestConstants.earlierNano,
            endNano: TestConstants.earlierNano,
            generatedChars: TestConstants.negativeChars
        )
        XCTAssertEqual(regressed.ttftMilliseconds, 0.0, accuracy: TestConstants.accuracy)
        XCTAssertTrue(regressed.decodeTokensPerSecond.isFinite)
        XCTAssertGreaterThan(regressed.decodeTokensPerSecond, 0.0)

        let noFirstToken = LiteRTInferenceBackend.computeStreamMetrics(
            startNano: TestConstants.startNano,
            firstTokenNano: nil,
            endNano: TestConstants.endNano,
            generatedChars: 0
        )
        XCTAssertGreaterThan(noFirstToken.ttftMilliseconds, 0.0)
        XCTAssertTrue(noFirstToken.decodeTokensPerSecond.isFinite)
    }

    func testLiteRTBuildMessageAndAcceleratorMapping() {
        let validBytes = Data([TestConstants.samplePayloadByte])
        let message = LiteRTInferenceBackend.buildMessage(
            trimmedPrompt: TestConstants.samplePrompt,
            imageData: [Data(), validBytes],
            audioData: validBytes
        )
        XCTAssertFalse(message.toString.isEmpty)

        let textOnlyMessage = LiteRTInferenceBackend.buildMessage(
            trimmedPrompt: TestConstants.samplePrompt,
            imageData: [Data()],
            audioData: Data()
        )
        XCTAssertEqual(textOnlyMessage.toString, TestConstants.samplePrompt)

        for accelerator in [LocalInferenceAccelerator.cpu, .gpu, .npu, .auto] {
            _ = LiteRTInferenceBackend.mapBackend(for: accelerator)
        }
    }

    func testExtractChunkPayloadsOrdersThoughtBeforeTextAndDropsEmptyFrames() {
        let empty = LiteRTInferenceBackend.extractChunkPayloads(thought: nil, text: "")
        XCTAssertTrue(empty.isEmpty, "空 thought 与空 text 不得输出脏 chunk")

        let emptyThought = LiteRTInferenceBackend.extractChunkPayloads(thought: "", text: "answer")
        XCTAssertEqual(emptyThought.count, 1)
        XCTAssertEqual(emptyThought.first?.characterCount, "answer".count)

        let combined = LiteRTInferenceBackend.extractChunkPayloads(thought: "plan", text: "result")
        XCTAssertEqual(combined.count, 2)
        if case .thought(let thoughtText) = combined[0].chunk {
            XCTAssertEqual(thoughtText, "plan")
        } else {
            XCTFail("同帧包含 thought 与 text 时，thought 必须排在 text 之前")
        }
        if case .text(let bodyText) = combined[1].chunk {
            XCTAssertEqual(bodyText, "result")
        } else {
            XCTFail("第二个 payload 应为正文 text")
        }
    }
}
