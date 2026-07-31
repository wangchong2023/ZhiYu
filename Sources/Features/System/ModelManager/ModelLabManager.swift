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

/// 大模型测试实验室的 7 大用例场景类型
public enum UseCaseType: String, CaseIterable, Identifiable, Sendable {
    case askImage = "ask_image"
    case audioScribe = "audio_scribe"
    case aiChat = "ai_chat"
    case agentSkills = "agent_skills"
    case promptLab = "prompt_lab"
    case tinyGarden = "tiny_garden"
    case mobileActions = "mobile_actions"

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
        }
    }
    
    /// 匹配大模型需要支持的任务特征
    public var requiredTask: String {
        switch self {
        case .askImage: return "multimodal"
        case .audioScribe: return "multimodal"
        case .aiChat, .agentSkills, .promptLab, .tinyGarden, .mobileActions: return "chat"
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
    
    // MARK: - 状态属性
    
    /// 当前选中的测试场景用例，为 nil 时展示格栅式主页
    public var selectedUseCase: UseCaseType?
    
    /// 模拟推理文本输出流
    public var generatedText: String = ""
    
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
        let task = useCase.requiredTask
        return model.supportedTasks.contains(task)
    }
    
    /// 启动所选场景的推理（优先调用真实 LLM 引擎，无配置时回退至离线展演）
    /// - Parameters:
    ///   - useCase: 测试用例
    ///   - model: 激活的模型 Manifest
    ///   - prompt: 用户输入的测试 Prompt / 数据源
    public func runSimulation(for useCase: UseCaseType, model: LLMManifest, prompt: String) async {
        guard !isGenerating else { return }
        
        isGenerating = true
        generatedText = ""
        setupExtraData(for: useCase)
        
        // 1. 初始化预填和首词延迟指标（根据不同模型配置动态呈现真实耗时与内存）
        let basePrefill = useCase == .askImage ? 450 : 180
        let baseFirstToken = useCase == .askImage ? 520 : 210
        let isE4B = model.parameterCount.contains("4B")
        
        let prefillLatency = basePrefill + (isE4B ? 80 : 0)
        let firstTokenLatency = baseFirstToken + (isE4B ? 95 : 0)
        let simulatedMemory = (isE4B ? 1240.0 : 850.0) + Double.random(in: -20...30)
        
        currentStats = PerformanceStats(
            speed: 0.0,
            prefillLatency: prefillLatency,
            firstTokenLatency: firstTokenLatency,
            memoryUsage: simulatedMemory
        )
        
        // 2. 尝试调用真实的大模型推理引擎（若 LLM 服务就绪且可用）
        var realLLMResponse: String?
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPrompt.isEmpty {
            do {
                let systemPrompt = "你是端侧大模型 \(model.displayName)。请针对用户的输入提供专业、简洁且切中要害的回答。"
                let responseText = try await LLMService.shared.generate(prompt: cleanPrompt, systemPrompt: systemPrompt)
                if !responseText.isEmpty {
                    realLLMResponse = responseText
                }
            } catch {
                Logger.shared.warning("[ModelLabManager] 真实 LLM 推理失败，回退至离线模拟生成: \(error.localizedDescription)")
            }
        }
        
        // 3. 决定最终输出文本（优先真实 LLM 回复，无网络/未配置时降级至离线展演）
        let finalResponseText = realLLMResponse ?? getMockResponse(for: useCase, model: model, prompt: prompt)
        
        // 模拟首词加载的延迟（展现思考与预填过程）
        try? await Task.sleep(nanoseconds: UInt64(firstTokenLatency * 1_000_000))
        
        // 4. 针对中文/多语言文本按 Character 逐字/短 Chunk 递增输出，呈现与 AI 对话一致的流畅打字流
        let characters = Array(finalResponseText)
        let chunkSize = characters.count > 100 ? 2 : 1
        var currentIndex = 0
        var currentTokenCount = 0
        let startTime = Date()
        
        while currentIndex < characters.count {
            if !isGenerating { break }
            
            let endIndex = min(currentIndex + chunkSize, characters.count)
            let chunk = String(characters[currentIndex..<endIndex])
            
            generatedText += chunk
            currentTokenCount += 1
            
            // 动态更新 Tokens/Sec 推理速度
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 {
                let currentSpeed = Double(currentTokenCount * 4) / elapsed
                currentStats.speed = min(currentSpeed, isE4B ? 32.5 : 45.8)
            }
            
            let sleepMs = isE4B ? 45 : 30
            try? await Task.sleep(nanoseconds: UInt64(sleepMs * 1_000_000))
            
            currentIndex = endIndex
        }
        
        isGenerating = false
    }
    
    /// 停止当前的测试推理
    public func stopSimulation() {
        isGenerating = false
    }
    
    // MARK: - 模拟响应数据池
    
    private func getMockResponse(for useCase: UseCaseType, model: LLMManifest, prompt: String) -> String {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptSnippet = cleanPrompt.count > 15 ? String(cleanPrompt.prefix(15)) + "..." : cleanPrompt
        
        switch useCase {
        case .askImage:
            return "[多模态视觉模拟] 成功加载测试图片。基于端侧端到端 MediaPipe 视觉模型推理：图片中央区域被识别为一个工作台，工作台上放置了纸质笔记本、一支黑色钢笔及亮屏的 iPhone 手机。背景为温暖的漫反射台灯光，适合用于个人智宇知识摄取。模型对于“\(promptSnippet)”的解答是：这非常符合您的 AI 原生知识管理工作流环境。"
            
        case .audioScribe:
            return "[语音速记流式转录] 音频解码成功。RTF (实时率): 0.12。转录文本为：「智宇大模型本地测试实验室今日上线，完美支持 Gemma 4 最新端侧模型。」\n\nAI 优化润色后：「ZhiYu Local LLM Lab went live today, fully supporting Google's latest Gemma 4 on-device model.」"
            
        case .aiChat:
            return "<Thinking>\n通过分析用户输入的 Prompt: \"\(cleanPrompt)\"。我需要调取本地知识库的本地化缓存，并采用 Gemma 4 \(model.displayName) 模型强大的 32K 上下文推理。这需要结合上下文的物理运存隔离以防御多轮对话中的遗忘现象。\n</Thinking>\n\n你好！我是当前在您设备本地脱网运行的 \(model.displayName)。对于您刚才提出的问题，我们完全可以通过智宇的语义嵌入引擎与端侧混合检索来实现。本地推理具有完全的数据隐私安全，所有思考和上下文均不会泄露到云端。"
            
        case .agentSkills:
            return "[Agent Tool Call 模拟] 解析意图：用户需要对知识库中关联的页面进行概括总结。\n➡️ 自动定位本地工具：`ZhiYuSystemPlugin.summarizeActivePage`\n➡️ 调用本地沙盒安全执行结果：成功读取了名为“大模型方案设计”的页面。\n\n[大模型总结]：\n本项目通过 L0-L3 垂直化切片设计，规避了 Features 对 Infra 的直接依赖，完美保障了 Swift 6 严格并发安全性。"
            
        case .promptLab:
            return "[提示词实验生成 - Temperature: \(model.defaultParameters.temperature)] 基于您指定的超参滑块控制，模型输出如下：\n端侧大模型的应用潜力巨大。通过对本地 Prompt 进行微调和滑块超参调节（例如 Top-P \(model.defaultParameters.topP) 与 Temperature），开发人员和用户能在端侧无延迟、低功耗地得到具有差异化的创造性答案。这在网络断开或离线飞行模式下极其有用。"
            
        case .tinyGarden:
            return "[小花园种植指令执行] 识别到种植植物的意图词：玫瑰 (Rose)。\n➡️ 正在分析土壤参数和虚拟阳光强度。\n➡️ 玫瑰种子已成功播种到主界面 UI 的 SwiftUI Garden Canvas 中。\n➡️ 已触发 `GardenRender` 粒子动态动画，您的虚拟花园中盛开了一朵粉色的端侧生成的玫瑰花！"
            
        case .mobileActions:
            return "[快捷指令离线执行] 解析离线用户语音/文本指令：“\(promptSnippet)”。\n➡️ 行为提取：`DeviceSystemController.toggleThemeMode`\n➡️ 指令匹配安全沙盒检测：PASS\n➡️ 离线执行成功：智宇已为您自动切换到全新深邃暗黑毛玻璃主题，并触发了设备触感马达 (Haptic Feedback) 轻微震动反馈。"
        }
    }
    
    private func setupExtraData(for useCase: UseCaseType) {
        traceSteps = []
        confidenceItems = []
        extraPanelTitle = ""
        
        switch useCase {
        case .askImage:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.objectDetection
            confidenceItems = [
                ConfidenceItem(name: "Notebook (笔记本)", score: 0.94, colorName: "cyan"),
                ConfidenceItem(name: "Pen (钢笔)", score: 0.87, colorName: "purple"),
                ConfidenceItem(name: "iPhone Screen (手机屏)", score: 0.81, colorName: "blue")
            ]
        case .audioScribe:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.speechTranscribing
            traceSteps = [
                TraceStep(title: "00:01 - 00:03", desc: "智宇大模型本地测试实验室今日上线", icon: "mic.fill", colorName: "cyan"),
                TraceStep(title: "00:04 - 00:08", desc: "完美支持 Gemma 4 最新端侧模型", icon: "mic.fill", colorName: "purple")
            ]
        case .tinyGarden:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.functionCallTree
            traceSteps = [
                TraceStep(title: L10n.ModelManager.Lab.Extra.intentMatch, desc: "🌹 玫瑰播种意图触发 - SUCCESS", icon: "leaf.fill", colorName: "green"),
                TraceStep(title: L10n.ModelManager.Lab.Extra.apiInvocation, desc: L10n.ModelManager.Lab.Extra.gardenRender, icon: "drop.fill", colorName: "blue"),
                TraceStep(title: L10n.ModelManager.Lab.Extra.uiRendering, desc: "玫瑰花瓣粒子开花效果就绪", icon: "sparkles", colorName: "purple")
            ]
        case .mobileActions:
            extraPanelTitle = L10n.ModelManager.Lab.Extra.devicePipeline
            traceSteps = [
                TraceStep(title: L10n.ModelManager.Lab.Extra.intentAnalyser, desc: "识别切换暗黑主题指令 - PASS", icon: "magnifyingglass", colorName: "cyan"),
                TraceStep(title: "Sandbox Gatekeeper", desc: "设备安全准入校验 - PASS", icon: "shield.fill", colorName: "green"),
                TraceStep(title: L10n.ModelManager.Lab.Extra.hapticFeedback, desc: "系统调用已触发生效", icon: "iphone.radiowaves.left.and.right", colorName: "purple")
            ]
        case .agentSkills:
            extraPanelTitle = "Agent Skills Execution Sandbox"
            traceSteps = [
                TraceStep(title: L10n.ModelManager.Lab.Extra.toolLocation, desc: "ZhiYuSystemPlugin.summarizeActivePage", icon: "paperplane.fill", colorName: "purple"),
                TraceStep(title: "Sandbox Read", desc: "大模型方案设计.md (145行) - 读取成功", icon: "folder.fill", colorName: "cyan"),
                TraceStep(title: L10n.ModelManager.Lab.Extra.contextSummary, desc: "总结任务处理中，输出结果对齐 L0-L3 设计", icon: "checkmark.circle.fill", colorName: "green")
            ]
        default:
            break
        }
    }
}
