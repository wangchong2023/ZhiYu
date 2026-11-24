//
//  LocalInferenceBackendProtocolTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证端侧推理后端契约类型边界（非法 JSON 解码拦截、默认采样参数合法性、Equatable 差异判定）。
//

import XCTest
@testable import ZhiYuAICore

final class LocalInferenceBackendProtocolTests: XCTestCase {

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
        XCTAssertGreaterThan(engine.cosineSimilarity(vec, vec), 0.99)
    }
}
