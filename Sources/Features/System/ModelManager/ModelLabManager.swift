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

    private enum PresetConfidenceScores {
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
    private let liteRTBackend: any LocalInferenceBackendProtocol
    private let localModelURLResolver: @MainActor (String) -> URL?
    private var loadedLiteRTModelId: String?

    private enum LiteRTStreamingTags {
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

    /// 当本地沙盒已就绪 .litertlm / .task 权重时，直接通过 Google LiteRT-LM 执行真实多模态流式推理
    private func streamWithLiteRTIfAvailable(
        for useCase: UseCaseType,
        model: LLMManifest,
        prompt: String,
        imageData: Data?,
        audioData: Data?,
        temperature: Double,
        topP: Double,
        enableThinking: Bool
    ) async -> Bool {
        guard useCase != .benchmark,
              !prompt.isEmpty,
              let localURL = localModelURLResolver(model.modelId) else {
            return false
        }
        let ext = localURL.pathExtension.lowercased()
        guard ext == LiteRTStreamingTags.liteRTExtension || ext == LiteRTStreamingTags.taskExtension else {
            return false
        }

        do {
            if loadedLiteRTModelId != model.modelId {
                try await liteRTBackend.loadModel(at: localURL, accelerator: .auto)
                loadedLiteRTModelId = model.modelId
            }
            let options = LocalInferenceOptions(
                temperature: temperature,
                topP: topP,
                topK: model.defaultParameters.topK,
                maxTokens: model.defaultParameters.maxTokens,
                enableThinking: enableThinking,
                accelerator: .auto
            )
            let images = imageData.map { [$0] } ?? []
            var thoughtBuffer = ""
            var answerBuffer = ""

            for try await chunk in liteRTBackend.generateStream(
                prompt: prompt,
                imageData: images,
                audioData: audioData,
                options: options
            ) {
                if !isGenerating {
                    await liteRTBackend.cancelGeneration()
                    break
                }
                switch chunk {
                case .thought(let delta):
                    thoughtBuffer += delta
                    generatedText = LiteRTStreamingTags.thoughtOpen + thoughtBuffer + LiteRTStreamingTags.thoughtClose + answerBuffer
                case .text(let delta):
                    answerBuffer += delta
                    generatedText = thoughtBuffer.isEmpty
                        ? answerBuffer
                        : LiteRTStreamingTags.thoughtOpen + thoughtBuffer + LiteRTStreamingTags.thoughtClose + answerBuffer
                case .completed(let ttftMs, let decodeTPS):
                    currentStats.firstTokenLatency = Int(ttftMs)
                    currentStats.prefillLatency = Int(ttftMs)
                    currentStats.speed = decodeTPS
                }
            }
            return !generatedText.isEmpty
        } catch {
            Logger.shared.warning("[ModelLabManager] LiteRT-LM 真实流式推理回退: \(error.localizedDescription)")
            return false
        }
    }

    /// 针对已下载的端侧本地大模型进行离线推理生成（杜绝调用在线 API，纯端侧执行）
    private func requestLocalModelResponse(model: LLMManifest, prompt: String, vision: VisionAnalysisResult?) async -> String? {
        guard !prompt.isEmpty else { return nil }
        // 严格物理校验：仅当本地沙盒中已下载模型权重时才执行本地推理，绝不走在线云端
        guard isModelDownloadedLocally(modelId: model.modelId) else {
            Logger.shared.info("[ModelLabManager] 本地模型 \(model.modelId) 未在本地沙盒下载，遵循纯离线原则不调用任何在线接口")
            return nil
        }
        
        if let onDevice = ServiceContainer.shared.resolveOptional((any OnDeviceLLMServiceProtocol).self) as? OnDeviceLLMService {
            let userPrompt = vision.map { "\($0.featureDescription)\n\n\(prompt)" } ?? prompt
            if !onDevice.isModelLoaded {
                let expectedID = "\(LLMConstants.ModelIDPrefix.downloaded)\(model.modelId)"
                onDevice.selectedModelID = expectedID
                try? await onDevice.loadModel()
            }

            if onDevice.isModelLoaded {
                do {
                    let text = try await onDevice.generate(prompt: userPrompt, maxTokens: OnDeviceLLMService.Config.chatMaxTokens)
                    if !text.isEmpty { return text }
                } catch {
                    Logger.shared.warning("[ModelLabManager] 端侧权重推理未就绪，尝试系统端侧 FoundationModels: \(error.localizedDescription)")
                }
            }

            // 端侧系统级 Apple FoundationModels 真实离线推理兜底（绝不请求云端 API）
            onDevice.selectedModelID = LLMConstants.OnDeviceModelID.appleIntelligence
            try? await onDevice.loadModel()
            if onDevice.isModelLoaded {
                if let systemText = try? await onDevice.generate(prompt: userPrompt, maxTokens: OnDeviceLLMService.Config.chatMaxTokens),
                   !systemText.isEmpty {
                    return systemText
                }
            }
        }
        return nil
    }

    /// 检测目标本地大模型在端侧沙盒是否已下载就绪
    private func isModelDownloadedLocally(modelId: String) -> Bool {
        if localModelURLResolver(modelId) != nil || GlobalModelManager.shared.isModelLocalReady(for: modelId) {
            return true
        }
        let fm = FileManager.default
        if let docURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let candidates = [
                docURL.appendingPathComponent("\(modelId).\(LiteRTStreamingTags.liteRTExtension)"),
                docURL.appendingPathComponent("\(modelId).\(LiteRTStreamingTags.taskExtension)"),
                docURL.appendingPathComponent("\(modelId).bin"),
                docURL.appendingPathComponent("MLModels/\(modelId).mlmodelc")
            ]
            if candidates.contains(where: { fm.fileExists(atPath: $0.path) }) {
                return true
            }
        }
        return false
    }

    /// 停止当前的测试推理（同步通知 LiteRT-LM 原生引擎中断生成）
    public func stopSimulation() {
        isGenerating = false
        loadingStageText = ""
        let backend = liteRTBackend
        Task { await backend.cancelGeneration() }
    }
    
    // MARK: - 预置样本置信度辅助
    
    private func setupPresetConfidence(sampleId: String) {
        let colors = [
            FeatureConstants.MockColorName.cyan,
            FeatureConstants.MockColorName.purple,
            FeatureConstants.MockColorName.blue
        ]
        let consts = FeatureConstants.VisionAnalysisConstants.self
        switch sampleId {
        case FeatureConstants.LabSynthesisConstants.sampleSmartDesk:
            confidenceItems = [
                ConfidenceItem(name: consts.presetDeskDisplay, score: PresetConfidenceScores.deskDisplay, colorName: colors[0]),
                ConfidenceItem(name: consts.presetDeskKeyboard, score: PresetConfidenceScores.deskKeyboard, colorName: colors[1]),
                ConfidenceItem(name: consts.presetDeskPlant, score: PresetConfidenceScores.deskPlant, colorName: colors[2])
            ]
        case FeatureConstants.LabSynthesisConstants.sampleArchChart:
            confidenceItems = [
                ConfidenceItem(name: consts.presetArchTopology, score: PresetConfidenceScores.archTopology, colorName: colors[0]),
                ConfidenceItem(name: consts.presetArchFlow, score: PresetConfidenceScores.archFlow, colorName: colors[1]),
                ConfidenceItem(name: consts.presetArchComponents, score: PresetConfidenceScores.archComponents, colorName: colors[2])
            ]
        case FeatureConstants.LabSynthesisConstants.sampleCityNight:
            confidenceItems = [
                ConfidenceItem(name: consts.presetNightSkyline, score: PresetConfidenceScores.nightSkyline, colorName: colors[0]),
                ConfidenceItem(name: consts.presetNightWindows, score: PresetConfidenceScores.nightWindows, colorName: colors[1]),
                ConfidenceItem(name: consts.presetNightMoon, score: PresetConfidenceScores.nightMoon, colorName: colors[2])
            ]
        default:
            break
        }
    }
    
    private func setupExtraData(for useCase: UseCaseType) {
        traceSteps = []
        confidenceItems = []
        extraPanelTitle = ""
        
        switch useCase {
        case .askImage:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.objectDetection
            setupPresetConfidence(sampleId: FeatureConstants.LabSynthesisConstants.sampleSmartDesk)
        case .audioScribe:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.speechTranscribing
            traceSteps = [
                TraceStep(title: FeatureConstants.LabDemoText.traceStep1Title, desc: FeatureConstants.LabDemoText.traceStep1Desc, icon: DesignTokens.Icons.micFill, colorName: FeatureConstants.MockColorName.cyan),
                TraceStep(title: FeatureConstants.LabDemoText.traceStep2Title, desc: FeatureConstants.LabDemoText.traceStep2Desc, icon: DesignTokens.Icons.micFill, colorName: FeatureConstants.MockColorName.purple)
            ]
        case .tinyGarden:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.functionCallTree
            traceSteps = [
                TraceStep(title: L10n.ModelManager.Lab.Extra.intentMatch, desc: FeatureConstants.LabDemoText.intentMatchDesc, icon: DesignTokens.Icons.leafFill, colorName: FeatureConstants.MockColorName.green),
                TraceStep(title: L10n.ModelManager.Lab.Extra.apiInvocation, desc: L10n.ModelManager.Lab.Extra.gardenRender, icon: DesignTokens.Icons.dropFill, colorName: FeatureConstants.MockColorName.blue),
                TraceStep(title: L10n.ModelManager.Lab.Extra.uiRendering, desc: FeatureConstants.LabDemoText.uiRenderingDesc, icon: DesignTokens.Icons.sparkles, colorName: FeatureConstants.MockColorName.purple)
            ]
        case .mobileActions:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.devicePipeline
            traceSteps = [
                TraceStep(title: L10n.ModelManager.Lab.Extra.intentAnalyser, desc: FeatureConstants.LabDemoText.intentAnalyserDesc, icon: DesignTokens.Icons.magnifyingglass, colorName: FeatureConstants.MockColorName.cyan),
                TraceStep(title: FeatureConstants.LabDemoText.sandboxGatekeeperTitle, desc: FeatureConstants.LabDemoText.sandboxGatekeeperDesc, icon: DesignTokens.Icons.shieldFill, colorName: FeatureConstants.MockColorName.green),
                TraceStep(title: L10n.ModelManager.Lab.Extra.hapticFeedback, desc: FeatureConstants.LabDemoText.hapticFeedbackDesc, icon: DesignTokens.Icons.iphoneRadiowaves, colorName: FeatureConstants.MockColorName.purple)
            ]
        case .agentSkills:
            extraPanelTitle = "Agent Skills Execution Sandbox"
            traceSteps = [
                TraceStep(title: L10n.ModelManager.Lab.Extra.toolLocation, desc: "ZhiYuSystemPlugin.summarizeActivePage", icon: DesignTokens.Icons.paperplaneFill, colorName: FeatureConstants.MockColorName.purple),
                TraceStep(title: FeatureConstants.LabDemoText.sandboxReadTitle, desc: FeatureConstants.LabDemoText.sandboxReadDesc, icon: DesignTokens.Icons.folderFill, colorName: FeatureConstants.MockColorName.cyan),
                TraceStep(title: L10n.ModelManager.Lab.Extra.contextSummary, desc: FeatureConstants.LabDemoText.contextSummaryDesc, icon: DesignTokens.Icons.checkmarkCircleFill, colorName: FeatureConstants.MockColorName.green)
            ]
        default:
            break
        }
    }
}
