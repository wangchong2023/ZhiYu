//
//  ModelLabRealFeaturesTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 系统管理测试
//  核心职责：验证模型实验室真实场景特化功能（快捷指令、提示词采样、智能体 ReAct 思维链、录音安全）。
//

import XCTest
@testable import ZhiYuUnitTestHost
import UFPCore
import AVFoundation

@MainActor
final class ModelLabRealFeaturesTests: XCTestCase {

    private var mockManifest: LLMManifest!

    override func setUp() async throws {
        try await super.setUp()
        mockManifest = LLMManifest(
            modelId: "test-model-real",
            displayName: "Test Model",
            vendor: "Google",
            fileSizeInBytes: 1024,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/model.bin",
            sha256Checksum: "",
            parameterCount: "2B",
            supportedTasks: ["chat"],
            description: "On-device local model for testing",
            defaultParameters: InferenceParameters()
        )
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docDir.appendingPathComponent("\(mockManifest.modelId).bin")
        let ggufHeader = Data([0x47, 0x47, 0x55, 0x46]) // GGUF 魔数
        var dummy = ggufHeader
        dummy.append(Data(repeating: 0xAB, count: 1024 * 64)) // 64KB 大于 32KB 探针最小阈值
        try? dummy.write(to: fileURL)

        _ = GlobalModelManager.shared.isModelLocalReady(for: mockManifest.modelId)
    }

    override func tearDown() async throws {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docDir.appendingPathComponent("\(mockManifest.modelId).bin")
        try? FileManager.default.removeItem(at: fileURL)
        GlobalModelManager.shared.clearModelCache(for: mockManifest.modelId)
        try await super.tearDown()
    }

    func testAudioRecorderSafeStartAndStopNeverCrashes() async throws {
        let recorder = LabAudioRecorder.shared
        #if os(iOS)
        if #available(iOS 17.0, *) {
            try XCTSkipUnless(AVAudioApplication.shared.recordPermission == .granted, "当前环境未预先授予麦克风权限，跳过真实录音验证以防系统弹窗挂起")
        }
        #endif
        await recorder.startRecording()
        try XCTSkipUnless(recorder.isRecording, "当前环境无麦克风权限，跳过真实录音验证")

        // 验证电平采样数组非空且处于合法范围
        XCTAssertEqual(recorder.normalizedPowerLevels.count, FeatureConstants.ModelLabSimulation.waveformBarCount)
        for level in recorder.normalizedPowerLevels {
            XCTAssertGreaterThanOrEqual(level, FeatureConstants.LabMultimodal.minNormalizedMeter)
            XCTAssertLessThanOrEqual(level, FeatureConstants.LabMultimodal.maxWaveformLevel)
        }

        let recordedURL = recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNotNil(recordedURL)
    }

    func testMobileActionsSpecializedResponse() {
        let synthesizer = LabResponseSynthesizer.shared

        // 1. 未识别的复杂意图 → 诚实回显原始指令并告知沙盒未授权
        let roseResponse = synthesizer.synthesize(
            useCase: .mobileActions,
            prompt: "种一朵玫瑰",
            model: mockManifest,
            temperature: 0.7,
            topP: 0.9,
            visionResult: nil,
            sampleId: nil
        )
        XCTAssertTrue(roseResponse.contains("种一朵玫瑰"))
        XCTAssertTrue(roseResponse.contains("未获得系统授权"))

        // 2. 可识别的硬件行为调度（如开启手电筒）→ 简洁调度成功消息
        let torchResponse = synthesizer.synthesize(
            useCase: .mobileActions,
            prompt: L10n.ModelManager.Lab.Mobile.cmdTorchOn,
            model: mockManifest,
            temperature: 0.7,
            topP: 0.9,
            visionResult: nil,
            sampleId: nil
        )
        XCTAssertTrue(torchResponse.contains("执行"))
    }

    func testPromptLabSamplingResponseVariesByTemperature() {
        let synthesizer = LabResponseSynthesizer.shared

        // 高发散创意模式 (Temperature >= 0.65)
        let creativeResponse = synthesizer.synthesize(
            useCase: .promptLab,
            prompt: "种一朵玫瑰",
            model: mockManifest,
            temperature: 0.85,
            topP: 0.95,
            visionResult: nil,
            sampleId: nil
        )
        XCTAssertTrue(creativeResponse.contains("0.85"))
        XCTAssertTrue(creativeResponse.contains("创意采样") || creativeResponse.contains("Creative"))

        // 低熵严谨确定性模式 (Temperature < 0.65)
        let preciseResponse = synthesizer.synthesize(
            useCase: .promptLab,
            prompt: "种一朵玫瑰",
            model: mockManifest,
            temperature: 0.2,
            topP: 0.5,
            visionResult: nil,
            sampleId: nil
        )
        XCTAssertTrue(preciseResponse.contains("0.20"))
        XCTAssertTrue(preciseResponse.contains("严谨") || preciseResponse.contains("Deterministic"))
    }

    func testAgentSkillsOutputsReActChain() {
        let synthesizer = LabResponseSynthesizer.shared
        let response = synthesizer.synthesize(
            useCase: .agentSkills,
            prompt: "总结本地知识库中，关于大模型方案设计的内容",
            model: mockManifest,
            temperature: 0.7,
            topP: 0.9,
            visionResult: nil,
            sampleId: nil
        )

        XCTAssertTrue(response.contains("ReAct"))
        XCTAssertTrue(response.contains("Thought"))
        XCTAssertTrue(response.contains("Action"))
        XCTAssertTrue(response.contains("Observation"))
        XCTAssertTrue(response.contains("Final Answer"))
    }
}
