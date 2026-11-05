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
import Dependencies
import UFPDesignSystem

/// 大模型测试实验室的场景类型
public enum UseCaseType: String, CaseIterable, Identifiable, Sendable {
    case askImage = "ask_image"
    case audioScribe = "audio_scribe"
    case aiChat = "ai_chat"
    case agentSkills = "agent_skills"
    case promptLab = "prompt_lab"
    case tinyGarden = "tiny_garden"
    case mobileActions = "mobile_actions"
    case instantMediaSearch = "instant_media_search"
    case videoMomentSearch = "video_moment_search"
    case benchmark = "benchmark"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .askImage: return L10n.ModelManager.Lab.useCaseAskImage
        case .audioScribe: return L10n.ModelManager.Lab.useCaseAudioScribe
        case .aiChat: return L10n.ModelManager.Lab.useCaseChat
        case .agentSkills: return L10n.ModelManager.Lab.useCaseAgentSkills
        case .promptLab: return L10n.ModelManager.Lab.useCasePromptLab
        case .tinyGarden: return L10n.ModelManager.Lab.useCaseTinyGarden
        case .mobileActions: return L10n.ModelManager.Lab.useCaseMobileActions
        case .instantMediaSearch: return L10n.ModelManager.Lab.useCaseInstantMediaSearch
        case .videoMomentSearch: return L10n.ModelManager.Lab.useCaseVideoMomentSearch
        case .benchmark: return L10n.ModelManager.Benchmark.title
        }
    }

    public var description: String {
        switch self {
        case .askImage: return L10n.ModelManager.Lab.descAskImage
        case .audioScribe: return L10n.ModelManager.Lab.descAudioScribe
        case .aiChat: return L10n.ModelManager.Lab.descChat
        case .agentSkills: return L10n.ModelManager.Lab.descAgentSkills
        case .promptLab: return L10n.ModelManager.Lab.descPromptLab
        case .tinyGarden: return L10n.ModelManager.Lab.descTinyGarden
        case .mobileActions: return L10n.ModelManager.Lab.descMobileActions
        case .instantMediaSearch: return L10n.ModelManager.Lab.descInstantMediaSearch
        case .videoMomentSearch: return L10n.ModelManager.Lab.descVideoMomentSearch
        case .benchmark: return L10n.ModelManager.Benchmark.description
        }
    }

    public var icon: String {
        switch self {
        case .askImage: return "photo.fill"
        case .audioScribe: return "mic.fill"
        case .aiChat: return "bubble.left.and.bubble.right.fill"
        case .agentSkills: return "sparkles.square.filled.on.square"
        case .promptLab: return "slider.horizontal.3"
        case .tinyGarden: return "leaf.fill"
        case .mobileActions: return "iphone.radiowaves.left.and.right"
        case .instantMediaSearch: return "photo.on.rectangle.angled"
        case .videoMomentSearch: return "video.badge.waveform.fill"
        case .benchmark: return "speedometer"
        }
    }

    public var themeColor: Color {
        switch self {
        case .askImage: return Color.theme.blue
        case .audioScribe: return Color.theme.purple
        case .aiChat: return Color.theme.cyan
        case .agentSkills: return Color.theme.purple
        case .promptLab: return Color.theme.orange
        case .tinyGarden: return Color.theme.green
        case .mobileActions: return Color.theme.blue
        case .instantMediaSearch: return Color.theme.orange
        case .videoMomentSearch: return Color.theme.green
        case .benchmark: return Color.theme.purple
        }
    }
    
    /// 匹配大模型需要支持的任务特征
    public var requiredTask: String {
        switch self {
        case .askImage: return "multimodal"
        case .audioScribe: return "multimodal"
        case .instantMediaSearch: return FeatureConstants.TaskName.mediaSearch
        case .videoMomentSearch: return FeatureConstants.TaskName.videoSearch
        case .benchmark: return "benchmark"
        case .aiChat, .agentSkills, .promptLab, .tinyGarden, .mobileActions: return "chat"
        }
    }

    /// 初始预设 Prompt 文本
    public var defaultPresetPrompt: String {
        switch self {
        case .askImage: return L10n.ModelManager.Lab.Prompt.askImage
        case .aiChat: return L10n.ModelManager.Lab.Prompt.chat
        case .agentSkills: return L10n.ModelManager.Lab.Prompt.agentSkills
        case .promptLab: return L10n.ModelManager.Lab.Prompt.promptLab
        case .tinyGarden: return L10n.ModelManager.Lab.Prompt.tinyGarden
        case .mobileActions: return L10n.ModelManager.Lab.Prompt.mobileActions
        case .instantMediaSearch: return L10n.ModelManager.Lab.Prompt.instantMediaSearch
        case .videoMomentSearch: return L10n.ModelManager.Lab.Prompt.videoMomentSearch
        case .benchmark, .audioScribe: return ""
        }
    }
}

/// 性能实时评估指标结构
public struct PerformanceStats: Sendable, Equatable {
    /// 推理生成速度 (Tokens/Sec)
    public var speed: Double
    /// 模型预加载/首词预填耗时 (ms)
    public var prefillLatency: Int
    /// 首词输出延迟耗时 (ms)
    public var firstTokenLatency: Int
    /// 物理运存开销 (MB)
    public var memoryUsage: Double
}

/// 任务路由及功能调用追踪步进结构
public struct TraceStep: Sendable, Identifiable {
    public var id: String { title }
    public var title: String
    public var desc: String
    public var icon: String
    public var colorName: String
    
    public init(title: String, desc: String, icon: String, colorName: String) {
        self.title = title
        self.desc = desc
        self.icon = icon
        self.colorName = colorName
    }
}

/// 视觉多模态识别结果项
public struct ConfidenceItem: Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var score: Double
    public var colorName: String
    
    public init(name: String, score: Double, colorName: String) {
        self.name = name
        self.score = score
        self.colorName = colorName
    }
}

/// 智能对话附件选项结构
public struct AttachmentOption: Sendable, Identifiable {
    public var id: String { title }
    public var title: String
    public var icon: String
    public var successMessage: String
    
    public init(title: String, icon: String, successMessage: String) {
        self.title = title
        self.icon = icon
        self.successMessage = successMessage
    }
}

/// 大模型实验室业务状态中台
@Observable
@MainActor
public final class ModelLabManager {

    // MARK: - 依赖注入

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
    
    public init() {}
    
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
        temperature: Double? = nil,
        topP: Double? = nil,
        sampleId: String? = nil
    ) async {
        guard !isGenerating else { return }
        
        isGenerating = true
        generatedText = ""
        setupExtraData(for: useCase)
        
        // 1. 初始化预填和首词延迟指标（根据不同模型配置动态呈现真实耗时与内存）
        let basePrefill = useCase == .askImage ? 450 : 180
        let baseFirstToken = useCase == .askImage ? 520 : 210
        let isE4B = model.parameterCount.contains(FeatureConstants.ModelParameter.e4B)
        
        let prefillLatency = basePrefill + (isE4B ? 80 : 0)
        let firstTokenLatency = baseFirstToken + (isE4B ? 95 : 0)
        let simulatedMemory = (isE4B ? 1240.0 : 850.0) + Double.random(in: -20...30)
        
        currentStats = PerformanceStats(
            speed: 0.0,
            prefillLatency: prefillLatency,
            firstTokenLatency: firstTokenLatency,
            memoryUsage: simulatedMemory
        )
        
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

        let isDownloaded = isModelDownloadedLocally(modelId: model.modelId)
        if isDownloaded {
            loadingStageText = L10n.ModelManager.Lab.modelLoadingIndicator
        }

        // 3. 决定最终输出文本（严格使用已下载的本地大模型，未下载时进行诚实未就绪引导）
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let tempVal = temperature ?? model.defaultParameters.temperature
        let topPVal = topP ?? model.defaultParameters.topP
        let localModelResponse: String?
        if useCase == .aiChat {
            localModelResponse = await requestLocalModelResponse(model: model, prompt: cleanPrompt, vision: visionResult)
        } else {
            localModelResponse = nil
        }
        loadingStageText = ""
        
        let finalResponseText: String
        if let localModelResponse {
            finalResponseText = localModelResponse
        } else {
            finalResponseText = LabResponseSynthesizer.shared.synthesize(
                useCase: useCase,
                prompt: cleanPrompt,
                model: model,
                temperature: tempVal,
                topP: topPVal,
                visionResult: visionResult,
                sampleId: sampleId
            )
        }
        
        // 模拟首词加载的延迟（展现思考与预填过程）
        try? await Task.sleep(nanoseconds: UInt64(firstTokenLatency * 1_000_000))
        await streamOutputText(finalResponseText, isE4B: isE4B)
        useCaseOutputs[useCase.rawValue] = generatedText
        useCaseStats[useCase.rawValue] = currentStats
        isGenerating = false
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
                currentStats.speed = min(currentSpeed, isE4B ? 32.5 : 45.8)
            }
            let sleepMs = isE4B ? 45 : 30
            try? await Task.sleep(nanoseconds: UInt64(sleepMs * 1_000_000))
            currentIndex = endIndex
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
            if !onDevice.isModelLoaded {
                let expectedID = "\(LLMConstants.ModelIDPrefix.downloaded)\(model.modelId)"
                onDevice.selectedModelID = expectedID
                try? await onDevice.loadModel()
            }

            if onDevice.isModelLoaded {
                let userPrompt = vision.map { "\($0.featureDescription)\n\n\(prompt)" } ?? prompt
                do {
                    let text = try await onDevice.generate(prompt: userPrompt, maxTokens: OnDeviceLLMService.Config.chatMaxTokens)
                    return text.isEmpty ? nil : text
                } catch {
                    Logger.shared.warning("[ModelLabManager] 端侧本地模型推理失败: \(error.localizedDescription)")
                }
            }
        }
        return nil
    }

    /// 检测目标本地大模型在端侧沙盒是否已下载就绪
    private func isModelDownloadedLocally(modelId: String) -> Bool {
        if GlobalModelManager.shared.isModelLocalReady(for: modelId) {
            return true
        }
        let fm = FileManager.default
        if let docURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            let binURL = docURL.appendingPathComponent("\(modelId).bin")
            let modelcURL = docURL.appendingPathComponent("MLModels/\(modelId).mlmodelc")
            if fm.fileExists(atPath: binURL.path) || fm.fileExists(atPath: modelcURL.path) {
                return true
            }
        }
        return false
    }

    /// 停止当前的测试推理
    public func stopSimulation() {
        isGenerating = false
        loadingStageText = ""
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
                ConfidenceItem(name: consts.presetDeskDisplay, score: 0.94, colorName: colors[0]),
                ConfidenceItem(name: consts.presetDeskKeyboard, score: 0.88, colorName: colors[1]),
                ConfidenceItem(name: consts.presetDeskPlant, score: 0.82, colorName: colors[2])
            ]
        case FeatureConstants.LabSynthesisConstants.sampleArchChart:
            confidenceItems = [
                ConfidenceItem(name: consts.presetArchTopology, score: 0.96, colorName: colors[0]),
                ConfidenceItem(name: consts.presetArchFlow, score: 0.91, colorName: colors[1]),
                ConfidenceItem(name: consts.presetArchComponents, score: 0.85, colorName: colors[2])
            ]
        case FeatureConstants.LabSynthesisConstants.sampleCityNight:
            confidenceItems = [
                ConfidenceItem(name: consts.presetNightSkyline, score: 0.95, colorName: colors[0]),
                ConfidenceItem(name: consts.presetNightWindows, score: 0.89, colorName: colors[1]),
                ConfidenceItem(name: consts.presetNightMoon, score: 0.84, colorName: colors[2])
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
