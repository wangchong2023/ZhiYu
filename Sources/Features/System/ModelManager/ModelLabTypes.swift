//
//  ModelLabTypes.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：定义 AI 模型实验室（Model Lab）的场景枚举、性能指标、追踪步骤与附件选项数据结构。
//

import Foundation
import SwiftUI
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
