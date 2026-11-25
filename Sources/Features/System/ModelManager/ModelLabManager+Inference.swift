//
//  ModelLabManager+Inference.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 模型实验室推理与样本扩展
//  核心职责：承载 ModelLabManager 的 LiteRT-LM 真实流式推理、离线端侧模型推理回退、
//           沙盒权重检测、停止生成与预置用例置信度/追踪步骤配置。
//

import Foundation
import UFPCore
import ZhiYuAICore
import UFPDesignSystem

extension ModelLabManager {

    /// 当本地沙盒已就绪 .litertlm / .task 权重时，直接通过 Google LiteRT-LM 执行真实多模态流式推理
    func streamWithLiteRTIfAvailable(
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
    func requestLocalModelResponse(model: LLMManifest, prompt: String, vision: VisionAnalysisResult?) async -> String? {
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
    func isModelDownloadedLocally(modelId: String) -> Bool {
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

    func setupPresetConfidence(sampleId: String) {
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

    func setupExtraData(for useCase: UseCaseType) {
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
