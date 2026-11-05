//
//  ModelLabMultimodalTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import UIKit
@testable import ZhiYu

@MainActor
final class ModelLabMultimodalTests: XCTestCase {

    // MARK: - 视觉样本提供者测试 (Ask Image)

    func testVisualSampleProviderGeneratesPresets() {
        let provider = LabVisualSampleProvider.shared
        let presets = provider.presetSamples

        XCTAssertFalse(presets.isEmpty, "预置视觉实测样本不应为空")
        XCTAssertEqual(presets.count, 3, "应提供 3 组精选视觉实测样本")

        for sample in presets {
            XCTAssertFalse(sample.id.isEmpty)
            XCTAssertFalse(sample.title.isEmpty)
            XCTAssertFalse(sample.prompt.isEmpty)
            XCTAssertGreaterThan(sample.width, 0)
            XCTAssertGreaterThan(sample.height, 0)
            XCTAssertGreaterThan(sample.byteSize, 0)
            XCTAssertFalse(sample.imageData.isEmpty)
            XCTAssertEqual(sample.resolutionString, "\(sample.width)×\(sample.height)")
            XCTAssertFalse(sample.formattedSizeString.isEmpty)
        }
    }

    func testVisualMetadataExtraction() {
        let provider = LabVisualSampleProvider.shared
        guard let firstSample = provider.presetSamples.first else {
            XCTFail("无法获取预置视觉样本")
            return
        }

        let metadata = provider.extractMetadata(from: firstSample.imageData)
        XCTAssertNotNil(metadata, "从真实样本图像数据中解析元数据应成功")
        XCTAssertEqual(metadata?.byteSize, firstSample.byteSize)
        XCTAssertGreaterThan(metadata?.width ?? 0, 0)
        XCTAssertGreaterThan(metadata?.height ?? 0, 0)

        // 测试空数据容错路径
        let emptyMeta = provider.extractMetadata(from: Data())
        XCTAssertNil(emptyMeta, "空图像数据应安全返回 nil")
    }

    // MARK: - 端侧真实视觉分析测试 (Vision)

    private func makeSolidImageData(red: CGFloat, green: CGFloat, blue: CGFloat, size: Int = 64) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size * 2))
        let image = renderer.image { ctx in
            UIColor(red: red, green: green, blue: blue, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size * 2))
        }
        return image.pngData() ?? Data()
    }

    func testVisionAnalyzerReflectsRealImagePixels() async throws {
        let analyzer = OnDeviceVisionAnalyzer.shared
        let brightResult = await analyzer.analyze(data: makeSolidImageData(red: 0.9, green: 0.9, blue: 0.9))
        let darkResult = await analyzer.analyze(data: makeSolidImageData(red: 0.05, green: 0.05, blue: 0.05))
        let vividResult = await analyzer.analyze(data: makeSolidImageData(red: 0.1, green: 0.8, blue: 0.2))
        let bright = try XCTUnwrap(brightResult)
        let dark = try XCTUnwrap(darkResult)
        let vivid = try XCTUnwrap(vividResult)

        XCTAssertGreaterThan(bright.brightness, dark.brightness + 0.5, "亮图亮度应显著高于暗图")
        XCTAssertLessThan(bright.saturation, 0.1, "灰白图饱和度应接近 0")
        XCTAssertGreaterThan(vivid.saturation, 0.5, "纯绿图饱和度应较高")
        XCTAssertEqual(vivid.height, vivid.width * 2, "应保留真实宽高比")
    }

    func testVisionAnalyzerRejectsInvalidData() async {
        let garbage = await OnDeviceVisionAnalyzer.shared.analyze(data: Data([0x00, 0x01, 0x02]))
        XCTAssertNil(garbage, "非图片数据应返回 nil")
        let empty = await OnDeviceVisionAnalyzer.shared.analyze(data: Data())
        XCTAssertNil(empty, "空数据应返回 nil")
    }

    func testVisionResultDescriptionUsesRealValues() {
        let result = VisionAnalysisResult(
            width: 1668, height: 2500,
            labels: [VisionLabel(name: "waterfall", score: 0.93), VisionLabel(name: "rock", score: 0.40)],
            ocrText: "HELLO", brightness: 0.5, saturation: 0.25,
            avgRed: 0.4, avgGreen: 0.4, avgBlue: 0.4,
            detectedCategory: .waterfallOrStream
        )
        let text = result.featureDescription
        XCTAssertTrue(text.contains("waterfall"))
        XCTAssertTrue(text.contains("93%"))
        XCTAssertTrue(text.contains("1668×2500"))
        XCTAssertTrue(text.contains("HELLO"))
        XCTAssertEqual(result.confidenceItems.map(\.name), ["waterfall", "rock"])
        XCTAssertEqual(result.confidenceItems.first?.score ?? 0, 0.93, accuracy: 0.001)
        XCTAssertFalse(text.contains(FeatureConstants.LabDemoText.notebookLabel), "不得再出现写死的办公用品标签")
    }

    func testLabResponseSynthesizerHonestFallback() {
        let manifest = LLMManifest(
            modelId: "gemma-2-2b-it",
            displayName: "Gemma 2 2B",
            vendor: "Google",
            fileSizeInBytes: 1500000000,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/gemma.bin",
            sha256Checksum: "abc",
            parameterCount: "2B",
            supportedTasks: ["chat"],
            description: "A test model.",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 2048)
        )
        // 1. 文本生成用例在无可用模型时诚实提示
        let promptOutput = LabResponseSynthesizer.shared.synthesize(
            useCase: .promptLab,
            prompt: "端侧大模型的未来应用场景。",
            model: manifest,
            temperature: 0.70,
            topP: 0.90,
            visionResult: nil,
            sampleId: nil
        )
        XCTAssertTrue(promptOutput.contains(L10n.ModelManager.Lab.modelNotReadyTitle), "无可用模型时应诚实提示未就绪")
        XCTAssertFalse(promptOutput.contains("基于您指定的超参滑块控制"), "必须彻底消除旧的死板假套话")

        // 2. 视觉用例在无模型时依然如实输出端侧提取的客观像素特征
        let vision = VisionAnalysisResult(
            width: 1920, height: 1080,
            labels: [VisionLabel(name: "Flowers", score: 0.92)],
            ocrText: "", brightness: 0.6, saturation: 0.4,
            avgRed: 0.5, avgGreen: 0.2, avgBlue: 0.2,
            detectedCategory: .flowers
        )
        let visualOutput = LabResponseSynthesizer.shared.synthesize(
            useCase: .askImage,
            prompt: "这是什么？",
            model: manifest,
            temperature: 0.70,
            topP: 0.90,
            visionResult: vision,
            sampleId: nil
        )
        XCTAssertTrue(visualOutput.contains("Flowers"), "视觉输出应包含真实提取的物体标签")
        XCTAssertTrue(visualOutput.contains("1920×1080"), "视觉输出应包含真实分辨率")
    }

    // MARK: - 音频样本提供者测试 (Audio Scribe)

    func testAudioSampleProviderGeneratesPresets() {
        let provider = LabAudioSampleProvider.shared
        let presets = provider.presetSamples

        XCTAssertEqual(presets.count, 3, "应提供 3 组精选音频速记测试样本")

        for sample in presets {
            XCTAssertFalse(sample.id.isEmpty)
            XCTAssertFalse(sample.title.isEmpty)
            XCTAssertGreaterThan(sample.durationSeconds, 0.0)
            XCTAssertFalse(sample.transcript.isEmpty)
            XCTAssertGreaterThan(sample.expectedWords, 0)
            XCTAssertGreaterThan(sample.targetRTF, 0.0)
            XCTAssertFalse(sample.durationFormatted.isEmpty)
        }
    }

    func testAudioSampleProviderFileGeneration() {
        let provider = LabAudioSampleProvider.shared
        guard let firstAudio = provider.presetSamples.first else {
            XCTFail("无法获取预置音频样本")
            return
        }

        let audioURL = provider.generateAudioFile(for: firstAudio)
        XCTAssertNotNil(audioURL, "合成真实 PCM/WAV 音频文件应成功")

        if let url = audioURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "合成的音频文件应真实存在于沙盒中")
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes?[.size] as? Int64 ?? 0
            XCTAssertGreaterThan(fileSize, 0, "音频文件字节大小应大于 0")
        }
    }

    // MARK: - 录音控制器初始状态测试

    @MainActor
    func testAudioRecorderInitialState() {
        let recorder = LabAudioRecorder.shared
        XCTAssertFalse(recorder.isRecording)
        XCTAssertFalse(recorder.normalizedPowerLevels.isEmpty)
        XCTAssertEqual(recorder.normalizedPowerLevels.count, FeatureConstants.ModelLabSimulation.waveformBarCount)
        XCTAssertEqual(recorder.durationFormatted, "00:00.0")
    }
}
