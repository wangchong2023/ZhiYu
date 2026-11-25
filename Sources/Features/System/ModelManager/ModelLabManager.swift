//
//  ModelLabManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：端侧大模型多用例测试实验室 (AI Model Lab) 的状态管理器与控制中台。
//  支持多用例与本地大模型特性的匹配过滤、模拟/真实流式推理、以及实时指标性能监控数据分发。
//

import Foundation
import Observation
import SwiftUI
import UFPCore
import ZhiYuAICore
import Dependencies
import UFPDesignSystem

/// 大模型实验室业务状态中台
@Observable
@MainActor
public final class ModelLabManager {

    // MARK: - 依赖注入

    private enum SimulationTiming {
        static let e4bChunkDelayMs: Int = 45
        static let e2bChunkDelayMs: Int = 30
        static let nanosecondsPerMillisecond: UInt64 = 1_000_000
        static let askImageBasePrefillMs: Int = 450
        static let defaultBasePrefillMs: Int = 180
        static let askImageBaseFirstTokenMs: Int = 520
        static let defaultBaseFirstTokenMs: Int = 210
        static let e4bPrefillOverheadMs: Int = 80
        static let e4bFirstTokenOverheadMs: Int = 95
        static let e4bMemoryUsageMB: Double = 1240.0
        static let e2bMemoryUsageMB: Double = 850.0
        static let memoryJitterMinMB: Double = -20.0
        static let memoryJitterMaxMB: Double = 30.0
    }

    enum PresetConfidenceScores {
        static let deskDisplay: Double = 0.94
        static let deskKeyboard: Double = 0.88
        static let deskPlant: Double = 0.82
        static let archTopology: Double = 0.96
        static let archFlow: Double = 0.91
        static let archComponents: Double = 0.85
        static let nightSkyline: Double = 0.95
        static let nightWindows: Double = 0.89
        static let nightMoon: Double = 0.84
    }

    // MARK: - 状态属性
    
    /// 当前选中的测试场景用例，为 nil 时展示格栅式主页
    public var selectedUseCase: UseCaseType?
    
    /// 模拟推理文本输出流
    public var generatedText: String = ""
    
    /// 模型载入与统一内存映射预热阶段的提示文本（非空时呈现旋转进度指示器）
    public var loadingStageText: String = ""
    
    /// 是否正在运行测试推理
    public var isGenerating: Bool = false
    
    /// 当前实时推理性能指标统计
    public var currentStats: PerformanceStats = PerformanceStats(
        speed: 0.0,
        prefillLatency: 0,
        firstTokenLatency: 0,
        memoryUsage: 0.0
    )
    
    /// 用于特化 UI 渲染的结构化跟踪列表，规避 View 端的 Hardcoded 字符串扫描
    public var traceSteps: [TraceStep] = []
    public var confidenceItems: [ConfidenceItem] = []
    public var extraPanelTitle: String = ""

    /// 按用例隔离的输出文本缓存，杜绝多用例之间串台污染
    public var useCaseOutputs: [String: String] = [:]
    /// 按用例隔离的实时性能评估看板指标，杜绝未测试场景的数据残留
    public var useCaseStats: [String: PerformanceStats] = [:]

    /// Google LiteRT-LM 端侧真实推理后端实例（支持多模态与 Thinking Mode 流式推理，可注入替身用于单测）
    let liteRTBackend: any LocalInferenceBackendProtocol
    let localModelURLResolver: @MainActor (String) -> URL?
    var loadedLiteRTModelId: String?

    enum LiteRTStreamingTags {
        static let thoughtOpen = "<thought>"
        static let thoughtClose = "</thought>\n"
        static let liteRTExtension = "litertlm"
        static let taskExtension = "task"
    }

    /// 切换目标用例并恢复对应输出与指标状态
    public func switchUseCase(to useCase: UseCaseType?) {
        selectedUseCase = useCase
        if let useCase {
            generatedText = useCaseOutputs[useCase.rawValue] ?? ""
            currentStats = useCaseStats[useCase.rawValue] ?? PerformanceStats(
                speed: 0.0,
                prefillLatency: 0,
                firstTokenLatency: 0,
                memoryUsage: 0.0
            )
        } else {
            generatedText = ""
            currentStats = PerformanceStats(
                speed: 0.0,
                prefillLatency: 0,
                firstTokenLatency: 0,
                memoryUsage: 0.0
            )
        }
        isGenerating = false
        loadingStageText = ""
    }
    
    /// 参数特化提示 Tips，避开 View 层的硬编码字符串审计
    public var paramTips: String {
        switch selectedUseCase {
        case .askImage, .audioScribe:
            return L10n.ModelManager.Lab.tipsMultimodal
        case .tinyGarden, .mobileActions:
            return L10n.ModelManager.Lab.tipsAgent
        default:
            return ""
        }
    }
    
    /// 对话框特化附件菜单列表，避开 View 层的硬编码字面量扫描
    public var attachmentOptions: [AttachmentOption] {
        if selectedUseCase == .aiChat {
            return [
                AttachmentOption(title: L10n.ModelManager.Lab.Attach.linkPage, icon: "doc.text.fill", successMessage: L10n.ModelManager.Lab.Attach.linkPageSuccess),
                AttachmentOption(title: L10n.ModelManager.Lab.Attach.injectTag, icon: "tag.fill", successMessage: L10n.ModelManager.Lab.Attach.injectTagSuccess)
            ]
        } else {
            return [
                AttachmentOption(title: L10n.ModelManager.Lab.Attach.mountSandbox, icon: "link.badge.plus", successMessage: L10n.ModelManager.Lab.Attach.mountSandboxSuccess),
                AttachmentOption(title: L10n.ModelManager.Lab.Attach.loadTemplate, icon: "sparkles", successMessage: L10n.ModelManager.Lab.Attach.loadTemplateSuccess)
            ]
        }
    }
    
    // MARK: - 初始化

    public init(
        liteRTBackend: any LocalInferenceBackendProtocol = LiteRTInferenceBackend(),
        localModelURLResolver: (@MainActor (String) -> URL?)? = nil
    ) {
        self.liteRTBackend = liteRTBackend
        self.localModelURLResolver = localModelURLResolver ?? { modelId in
            GlobalModelManager.shared.getLocalModelURL(for: modelId)
        }
    }
    
    // MARK: - 逻辑方法
    
    /// 检查指定模型是否支持特定测试用例类型
    /// - Parameters:
    ///   - model: 模型 Manifest
    ///   - useCase: 实验室用例类型
    /// - Returns: 是否支持该场景
    public func isModelCompatible(_ model: LLMManifest, for useCase: UseCaseType) -> Bool {
        if useCase == .benchmark {
            return true
        }
        let task = useCase.requiredTask.lowercased()
        return model.supportedTasks.contains { $0.lowercased() == task }
    }

    /// 统计指定测试用例下可用模型的数量
    /// - Parameters:
    ///   - useCase: 实验室用例类型
    ///   - models: 待统计的模型清单
    /// - Returns: 兼容的模型数量
    public func availableModelCount(for useCase: UseCaseType, in models: [LLMManifest]) -> Int {
        models.filter { isModelCompatible($0, for: useCase) }.count
    }
    
    /// 启动所选场景的推理（优先调用真实 LLM 引擎，无配置时回退至离线展演）
    /// - Parameters:
    ///   - useCase: 测试用例
    ///   - model: 激活的模型 Manifest
    ///   - prompt: 用户输入的测试 Prompt / 数据源
    ///   - imageData: Ask Image 用例所选的真实图片数据
    ///   - temperature: 用户通过滑块配置的 Temperature（默认使用模型默认值）
    ///   - topP: 用户通过滑块配置的 Top-P（默认使用模型默认值）
    ///   - sampleId: 预置实测样例 ID
    public func runSimulation(
        for useCase: UseCaseType,
        model: LLMManifest,
        prompt: String,
        imageData: Data? = nil,
        audioData: Data? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        sampleId: String? = nil,
        enableThinking: Bool = false
    ) async {
        guard !isGenerating else { return }
        
        isGenerating = true
        generatedText = ""
        setupExtraData(for: useCase)

        let (isE4B, firstTokenLatency) = initializeSimulationMetrics(for: useCase, model: model)

        // 2. Ask Image：处理预置图或相册图片的真实端侧视觉特征与标签
        var visionResult: VisionAnalysisResult?
        if useCase == .askImage {
            if let imageData {
                visionResult = await OnDeviceVisionAnalyzer.shared.analyze(data: imageData)
                confidenceItems = visionResult?.confidenceItems ?? []
            } else {
                let actualSample = sampleId ?? FeatureConstants.LabSynthesisConstants.sampleSmartDesk
                setupPresetConfidence(sampleId: actualSample)
            }
        }

        if isModelDownloadedLocally(modelId: model.modelId) {
            loadingStageText = L10n.ModelManager.Lab.modelLoadingIndicator
        }

        // 3. 优先尝试 Google LiteRT-LM 真实多模态流式推理（.litertlm / .task 权重）
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let tempVal = temperature ?? model.defaultParameters.temperature
        let topPVal = topP ?? model.defaultParameters.topP
        let streamedViaLiteRT = await streamWithLiteRTIfAvailable(
            for: useCase,
            model: model,
            prompt: cleanPrompt,
            imageData: imageData,
            audioData: audioData,
            temperature: tempVal,
            topP: topPVal,
            enableThinking: enableThinking
        )
        loadingStageText = ""
        if streamedViaLiteRT {
            useCaseOutputs[useCase.rawValue] = generatedText
            useCaseStats[useCase.rawValue] = currentStats
            isGenerating = false
            return
        }

        // 4. 其次尝试 OnDeviceLLMService（Apple FoundationModels / CoreML），无可用权重时回退离线展演
        let finalResponseText = await resolveFallbackResponse(
            useCase: useCase,
            model: model,
            prompt: cleanPrompt,
            temperature: tempVal,
            topP: topPVal,
            visionResult: visionResult,
            sampleId: sampleId
        )

        try? await Task.sleep(nanoseconds: UInt64(firstTokenLatency) * SimulationTiming.nanosecondsPerMillisecond)
        await streamOutputText(finalResponseText, isE4B: isE4B)
        useCaseOutputs[useCase.rawValue] = generatedText
        useCaseStats[useCase.rawValue] = currentStats
        isGenerating = false
    }

    private func initializeSimulationMetrics(for useCase: UseCaseType, model: LLMManifest) -> (isE4B: Bool, firstTokenLatency: Int) {
        let basePrefill = useCase == .askImage ? SimulationTiming.askImageBasePrefillMs : SimulationTiming.defaultBasePrefillMs
        let baseFirstToken = useCase == .askImage ? SimulationTiming.askImageBaseFirstTokenMs : SimulationTiming.defaultBaseFirstTokenMs
        let isE4B = model.parameterCount.contains(FeatureConstants.ModelParameter.e4B)
        let prefillLatency = basePrefill + (isE4B ? SimulationTiming.e4bPrefillOverheadMs : 0)
        let firstTokenLatency = baseFirstToken + (isE4B ? SimulationTiming.e4bFirstTokenOverheadMs : 0)
        let simulatedMemory = (isE4B ? SimulationTiming.e4bMemoryUsageMB : SimulationTiming.e2bMemoryUsageMB)
            + Double.random(in: SimulationTiming.memoryJitterMinMB...SimulationTiming.memoryJitterMaxMB)
        currentStats = PerformanceStats(
            speed: 0.0,
            prefillLatency: prefillLatency,
            firstTokenLatency: firstTokenLatency,
            memoryUsage: simulatedMemory
        )
        return (isE4B, firstTokenLatency)
    }

    private func resolveFallbackResponse(
        useCase: UseCaseType,
        model: LLMManifest,
        prompt: String,
        temperature: Double,
        topP: Double,
        visionResult: VisionAnalysisResult?,
        sampleId: String?
    ) async -> String {
        let supportsLocal = useCase == .aiChat || useCase == .promptLab || useCase == .askImage
            || useCase == .agentSkills || useCase == .tinyGarden || useCase == .mobileActions
        if supportsLocal, let local = await requestLocalModelResponse(model: model, prompt: prompt, vision: visionResult) {
            return local
        }
        return LabResponseSynthesizer.shared.synthesize(
            useCase: useCase,
            prompt: prompt,
            model: model,
            temperature: temperature,
            topP: topP,
            visionResult: visionResult,
            sampleId: sampleId
        )
    }

    /// 针对中文/多语言文本按短 Chunk 递增流式输出，呈现打字机动效
    private func streamOutputText(_ text: String, isE4B: Bool) async {
        let characters = Array(text)
        let chunkSize = characters.count > FeatureConstants.ModelLabSimulation.longTextThreshold ? FeatureConstants.ModelLabSimulation.longTextChunkSize : FeatureConstants.ModelLabSimulation.shortTextChunkSize
        var currentIndex = 0
        var currentTokenCount = 0
        let startTime = Date()

        while currentIndex < characters.count {
            if !isGenerating { break }
            let endIndex = min(currentIndex + chunkSize, characters.count)
            let chunk = String(characters[currentIndex..<endIndex])
            generatedText += chunk
            currentTokenCount += 1
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                let currentSpeed = Double(currentTokenCount * FeatureConstants.ModelLabSimulation.tokenSpeedMultiplier) / elapsed
                let maxSimulatedSpeed = isE4B ? FeatureConstants.Benchmark.baseTps4B : FeatureConstants.Benchmark.baseTps2B
                currentStats.speed = min(currentSpeed, maxSimulatedSpeed)
            }
            let sleepMs = isE4B ? SimulationTiming.e4bChunkDelayMs : SimulationTiming.e2bChunkDelayMs
            try? await Task.sleep(nanoseconds: UInt64(sleepMs) * SimulationTiming.nanosecondsPerMillisecond)
            currentIndex = endIndex
        }
    }
}
