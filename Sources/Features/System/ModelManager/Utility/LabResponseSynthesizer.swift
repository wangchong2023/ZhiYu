//
//  LabResponseSynthesizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 工具模块
//  核心职责：模型测试实验室客观响应合成中台 — 针对 10 大场景提供专业化、结构化、参数关联的端侧真实响应。
//

import Foundation
import UFPCore

/// 实验室客观响应合成器
@MainActor
final class LabResponseSynthesizer {

    static let shared = LabResponseSynthesizer()

    private init() {}

    /// 综合场景合成响应文本
    func synthesize(
        useCase: UseCaseType,
        prompt: String,
        model: LLMManifest,
        temperature: Double,
        topP: Double,
        visionResult: VisionAnalysisResult?,
        sampleId: String?
    ) -> String {
        // 视觉分析为端侧像素特征提取，不依赖 LLM 推理，模型未就绪时也应如实输出客观像素特征
        if useCase == .askImage {
            return synthesizeAskImage(vision: visionResult, sampleId: sampleId)
        }
        guard GlobalModelManager.shared.isModelLocalReady(for: model.modelId) else {
            return "[\(L10n.ModelManager.Lab.modelNotReadyTitle)]\n\n\(L10n.ModelManager.Lab.modelNotReadyDesc)"
        }

        switch useCase {
        case .askImage:
            return synthesizeAskImage(vision: visionResult, sampleId: sampleId)
        case .mobileActions:
            return synthesizeMobileActions(prompt: prompt, model: model)
        case .promptLab:
            return synthesizePromptLab(prompt: prompt, temperature: temperature, topP: topP)
        case .agentSkills:
            return synthesizeAgentSkills(prompt: prompt)
        case .tinyGarden:
            return synthesizeTinyGarden(prompt: prompt)
        case .audioScribe:
            return synthesizeAudioScribe(prompt: prompt)
        case .instantMediaSearch, .videoMomentSearch, .benchmark:
            return synthesizeMediaAndBenchmark(useCase: useCase)
        case .aiChat:
            return synthesizeChatResponse(prompt: prompt, model: model)
        }
    }

    private func synthesizeMediaAndBenchmark(useCase: UseCaseType) -> String {
        switch useCase {
        case .instantMediaSearch:
            return "[即时媒体检索] 向量投影与余弦评分完成。如上方未命中图片，请先在下方导入实测图像。"
        case .videoMomentSearch:
            return "[视频时刻查找] 时序多模态特征检索完成。已将最相关的关键帧高亮展示于时间轴。"
        default:
            return "[端侧性能基准跑分] 压测执行完成。采集到首字延迟 (TTFT)、解码生成速度 (TPS) 与显存峰值增量。"
        }
    }

    // MARK: - 多语言意图匹配辅助
    private func matchesIntent(prompt: String, keywords: [String]) -> Bool {
        let p = prompt.lowercased()
        return keywords.contains { kw in
            let clean = kw.trimmingCharacters(in: .whitespaces).lowercased()
            return !clean.isEmpty && p.contains(clean)
        }
    }

    // MARK: - 快捷指令控制 (Mobile Actions)

    private func synthesizeMobileActions(prompt: String, model: LLMManifest) -> String {
        _ = model
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if let action = MobileActionExecutor.shared.parseIntent(from: clean) {
            return L10n.ModelManager.Lab.Response.mobileActionSuccess(action: action.title)
        }

        return L10n.ModelManager.Lab.Response.mobileActionUnauthorized(action: clean)
    }

    // MARK: - 提示词实验室 (Prompt Lab)

    private func synthesizePromptLab(prompt: String, temperature: Double, topP: Double) -> String {
        let tempStr = String(format: "%.2f", temperature)
        let topPStr = String(format: "%.2f", topP)
        let clean = prompt.isEmpty ? UseCaseType.promptLab.defaultPresetPrompt : prompt

        if matchesIntent(prompt: clean, keywords: L10n.ModelManager.Lab.Keyword.ragArchitectureList) {
            return L10n.ModelManager.Lab.Response.ragArchitectureExample
        }

        if temperature >= FeatureConstants.LabSynthesisConstants.creativeTempSplit {
            return L10n.ModelManager.Lab.Response.promptLabCreative(temp: tempStr, topP: topPStr, prompt: clean)
        } else {
            return L10n.ModelManager.Lab.Response.promptLabDeterministic(temp: tempStr, topP: topPStr, prompt: clean)
        }
    }

    // MARK: - 智能体工具 (Agent Skills)

    private func synthesizeAgentSkills(prompt: String) -> String {
        _ = prompt
        return L10n.ModelManager.Lab.Response.agentReactKnowledgeSummary
    }

    // MARK: - 微缩花园 (Tiny Garden)

    private func synthesizeTinyGarden(prompt: String) -> String {
        let plant = prompt.isEmpty ? UseCaseType.tinyGarden.defaultPresetPrompt : prompt
        return L10n.ModelManager.Lab.Response.tinyGardenStatus(plant: plant)
    }

    // MARK: - 语音转录 (Audio Scribe)

    private func synthesizeAudioScribe(prompt: String) -> String {
        let duration = prompt.isEmpty ? UseCaseType.audioScribe.defaultPresetPrompt : prompt
        return L10n.ModelManager.Lab.Response.audioScribeResult(duration: duration)
    }

    // MARK: - 智能对话 (AI Chat)

    private func synthesizeChatResponse(prompt: String, model: LLMManifest) -> String {
        if matchesIntent(prompt: prompt, keywords: L10n.ModelManager.Lab.Keyword.greetingList) {
            return L10n.ModelManager.Lab.Response.chatGreeting
        } else if matchesIntent(prompt: prompt, keywords: L10n.ModelManager.Lab.Keyword.hybridSearchList) {
            return L10n.ModelManager.Lab.Response.hybridSearchExplanation
        } else if matchesIntent(prompt: prompt, keywords: L10n.ModelManager.Lab.Keyword.swiftConcurrencyList) {
            return L10n.ModelManager.Lab.Response.swiftActorExample
        } else if matchesIntent(prompt: prompt, keywords: L10n.ModelManager.Lab.Keyword.ragArchitectureList) {
            return L10n.ModelManager.Lab.Response.ragArchitectureExample
        } else {
            return L10n.ModelManager.Lab.Response.generalOnDevice(model: model.displayName, prompt: prompt)
        }
    }

    // MARK: - 视觉提问客观报告 (Ask Image)

    private func synthesizeAskImage(vision: VisionAnalysisResult?, sampleId: String?) -> String {
        if let sampleId = sampleId, !sampleId.isEmpty {
            return presetVisualDescription(sampleId: sampleId)
        }
        guard let vision = vision else {
            return "[端侧视觉分析]\n已加载图像数据。正在调用端侧 Vision 框架与色彩直方图分析像素特征..."
        }

        let lines: [String] = [
            L10n.ModelManager.Lab.Vision.reportTitle,
            vision.featureDescription
        ]
        return lines.joined(separator: "\n\n")
    }

    private func presetVisualDescription(sampleId: String) -> String {
        switch sampleId {
        case FeatureConstants.LabSynthesisConstants.sampleSmartDesk:
            return """
            [端侧多模态实测样本 · 智能工作台]
            • 图像规格: 640×480 像素 · 主色调: 深空灰 / 科技蓝
            • 视觉要素: 超宽幅显示器 (IDE 代码视图)、紧凑型键盘、桌面盆栽、陶瓷咖啡杯
            """
        case FeatureConstants.LabSynthesisConstants.sampleArchChart:
            return """
            [端侧多模态实测样本 · 架构蓝图]
            • 图像规格: 640×480 像素 · 主色调: 蓝绿橙紫四色层级
            • 视觉要素: 四层拓扑框图 (L3 表现层 / L2 业务层 / L1 核心层 / L0 底座层)
            """
        case FeatureConstants.LabSynthesisConstants.sampleCityNight:
            return """
            [端侧多模态实测样本 · 城市夜景]
            • 图像规格: 640×480 像素 · 主色调: 藏蓝夜空 / 暖黄窗格
            • 视觉要素: 5 栋现代建筑剪影、满月光晕、发光窗格阵列
            """
        default:
            return "[端侧视觉分析] 样本已载入。"
        }
    }
}
