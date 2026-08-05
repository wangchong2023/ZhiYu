//
//  LLMManifest.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义大模型白名单的 Manifest 清单数据结构。映射远程下发的 JSON 配置，包含物理内存门槛、文件哈希指纹及默认推理超参。
//

import Foundation

/// 远程大模型清单描述结构实体
public struct LLMManifest: Codable, Sendable, Identifiable, Equatable {
    /// 唯一标识 ID
    public var id: String { modelId }
    
    /// 模型唯一 ID 标识 (如: "gemma-2b-it", "llama3-8b-instruct")
    public let modelId: String
    
    /// 原始解码的模型名称 (如: "Gemma-2-2B-IT")
    private let rawDisplayName: String
    
    /// 模型厂商 (如: "Google", "Meta", "Microsoft")
    public let vendor: String
    
    /// 模型权重 file 包大小 (单位: 字节)
    public let fileSizeInBytes: Int64
    
    /// 推荐的物理设备内存门槛限制 (单位: GB，如 8.0, 12.0)
    public let minDeviceMemoryInGb: Double
    
    /// 远程 CDN 权重文件包下载 URL 路径
    public let remoteURLString: String
    
    /// 模型的 SHA256 指纹哈希，用于本地完整性校验，防范二进制损坏
    public let sha256Checksum: String
    
    /// 大模型参数量简述 (如: "2B", "8B")
    public let parameterCount: String
    
    /// 模型支持与最擅长的核心任务类型 (如: ["TextSynthesis", "PageTagging", "OfflineRetrieval"])
    public let supportedTasks: [String]
    
    /// 原始解码的模型特定描述 and 应用场景建议
    private let rawDescription: String
    
    /// 默认推理超参数配置
    public let defaultParameters: InferenceParameters
    
    /// 备用 HuggingFace 下载源（国外首选）
    public let huggingfaceURLString: String?
    
    /// 备用 ModelScope (魔搭社区) 下载源（国内首选）
    public let modelscopeURLString: String?
    
    /// 多语言展示名称映射字典 (如: ["en": "Gemma-4", "zh-Hans": "Gemma-4"])
    public let displayNames: [String: String]?
    
    /// 多语言描述映射字典
    public let descriptions: [String: String]?
    
    /// 本地化支持任务列表 (如: ["智能对话", "文本补全"])
    public let supportedTasksLocalized: [String]?
    
    /// 界面友好展示的模型名称（自动匹配系统语言）
    public var displayName: String {
        if let names = displayNames {
            return Localized.bestMatch(in: names, fallback: rawDisplayName)
        }
        return rawDisplayName
    }
    
    /// 模型的特定描述 and 应用场景建议（自动匹配系统语言）
    public var description: String {
        if let descs = descriptions {
            return Localized.bestMatch(in: descs, fallback: rawDescription)
        }
        return rawDescription
    }

    /// 界面友好展示的支持任务列表
    public var displayTasks: [String] {
        if let localized = supportedTasksLocalized {
            return localized
        }
        return supportedTasks.map { task in
            let localizedText: String
            switch task.lowercased() {
            case "chat": localizedText = L10n.ModelManager.Task.chat
            case "completion": localizedText = L10n.ModelManager.Task.completion
            case "multimodal": localizedText = L10n.ModelManager.Task.multimodal
            case "reasoning": localizedText = L10n.ModelManager.Task.reasoning
            case "code": localizedText = L10n.ModelManager.Task.code
            case "rag": localizedText = L10n.ModelManager.Task.rag
            case "translation": localizedText = L10n.ModelManager.Task.translation
            default: localizedText = task.capitalized
            }
            
            // 单元测试或极端情况下的健壮降级兜底
            if localizedText.contains("_") || localizedText.contains(".") {
                return task.capitalized
            }
            return localizedText
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case modelId
        case rawDisplayName = "displayName"
        case vendor
        case fileSizeInBytes
        case minDeviceMemoryInGb
        case remoteURLString
        case sha256Checksum
        case parameterCount
        case supportedTasks
        case rawDescription = "description"
        case defaultParameters
        case huggingfaceURLString
        case modelscopeURLString
        case displayNames
        case descriptions
        case supportedTasksLocalized
    }
    
    public init(
        modelId: String,
        displayName: String,
        vendor: String,
        fileSizeInBytes: Int64,
        minDeviceMemoryInGb: Double,
        remoteURLString: String,
        sha256Checksum: String,
        parameterCount: String,
        supportedTasks: [String] = [],
        description: String,
        defaultParameters: InferenceParameters,
        huggingfaceURLString: String? = nil,
        modelscopeURLString: String? = nil,
        displayNames: [String: String]? = nil,
        descriptions: [String: String]? = nil,
        supportedTasksLocalized: [String]? = nil
    ) {
        self.modelId = modelId
        self.rawDisplayName = displayName
        self.vendor = vendor
        self.fileSizeInBytes = fileSizeInBytes
        self.minDeviceMemoryInGb = minDeviceMemoryInGb
        self.remoteURLString = remoteURLString
        self.sha256Checksum = sha256Checksum
        self.parameterCount = parameterCount
        self.supportedTasks = supportedTasks
        self.rawDescription = description
        self.defaultParameters = defaultParameters
        self.huggingfaceURLString = huggingfaceURLString
        self.modelscopeURLString = modelscopeURLString
        self.displayNames = displayNames
        self.descriptions = descriptions
        self.supportedTasksLocalized = supportedTasksLocalized
    }
}

/// 默认的端侧大模型推理参数结构
public struct InferenceParameters: Codable, Sendable, Equatable {
    /// 温度，控制生成内容的创造力 (范围 0.0 ~ 2.0)
    public let temperature: Double
    
    /// 候选词累积概率截断阈值
    public let topP: Double
    
    /// 候选词个数限制
    public let topK: Int
    
    /// 单次推理生成的最大 Token 数量限制
    public let maxTokens: Int
    
    public init(
        temperature: Double = PromptConstants.InferenceDefaults.temperature,
        topP: Double = PromptConstants.InferenceDefaults.topP,
        topK: Int = PromptConstants.InferenceDefaults.topK,
        maxTokens: Int = PromptConstants.InferenceDefaults.maxTokens
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
    }
}
