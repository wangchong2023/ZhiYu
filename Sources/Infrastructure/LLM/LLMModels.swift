//
//  LLMModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：大语言模型客户端：多提供商适配、流式响应解析、端侧推理。
//
import Foundation
import UFPCore
import Dependencies

// MARK: - LLM 提供商元数据

/// LLM 提供商元数据
/// 包含 API 端点、默认模型及 UI 展示参数。
struct LLMProviderMetadata: Codable, Sendable {
    /// 唯一标识符
    let id: String
    /// 本地化名称键值
    let nameKey: String
    /// API 基础路径
    let baseURL: String
    /// 默认使用的模型名称
    let defaultModel: String
    /// 建议的模型列表
    let suggestedModels: [String]
    /// API Key 必须包含的前缀 (如 "sk-")
    let apiKeyPrefix: String?
    /// API Key 最小长度要求
    let apiKeyMinLength: Int?
    /// API Key 占位提示字符串
    let apiKeyPlaceholder: String?
    /// 显示图标 (SF Symbol)
    let icon: String
}

// MARK: - LLM Registry
final class LLMRegistry: Sendable {
    static let shared = LLMRegistry()
    private let providers: [String: LLMProviderMetadata]

    private init() {
        providers = LLMRegistry.loadProviders()
    }

    private static func loadProviders() -> [String: LLMProviderMetadata] {
        var result: [String: LLMProviderMetadata] = [:]
        // 首先尝试从 Bundle 加载（Apple 推荐方式）
        if let url = Bundle.main.url(forResource: LLMConstants.BundleResource.llmProviders, withExtension: SystemConstants.FileExtension.json),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([LLMProviderMetadata].self, from: data) {
            for item in list {
                result[item.id] = item
            }
            return result
        }

        // 兜底方案：如果 JSON 未能加载（如尚未打包），使用硬编码数据（DeepSeek 第一位）
        let fallbacks: [LLMProviderMetadata] = [
            .init(id: "deepseek", nameKey: "llm.provider.deepSeek", baseURL: APIPaths.llmProviderDeepSeek, defaultModel: "deepseek-v4-pro", suggestedModels: ["deepseek-v4-pro", "deepseek-v4-flash"], apiKeyPrefix: LLMConstants.APIKeySecret.prefix, apiKeyMinLength: 30, apiKeyPlaceholder: "sk-...", icon: "wave.3.forward"),
            .init(id: "zhipu", nameKey: "llm.provider.zhipu", baseURL: APIPaths.llmProviderZhipu, defaultModel: "glm-5.2", suggestedModels: ["glm-5.2", "glm-5", "glm-5-turbo", "glm-5v-turbo", "glm-4-flash"], apiKeyPrefix: "", apiKeyMinLength: 20, apiKeyPlaceholder: "your-api-key", icon: "sparkles"),
            .init(id: "minimax", nameKey: "llm.provider.minimax", baseURL: APIPaths.llmProviderMinimax, defaultModel: "abab7-chat", suggestedModels: ["abab7-chat", "abab6.5t-chat", "abab6.5s-chat"], apiKeyPrefix: "", apiKeyMinLength: 20, apiKeyPlaceholder: "your-api-key", icon: "cpu"),
            .init(id: "qwen", nameKey: "llm.provider.qwen", baseURL: APIPaths.llmProviderQwen, defaultModel: "qwen3.7-max", suggestedModels: ["qwen3.7-max", "qwen3.8-max-preview", "qwen3.7-plus", "qwen3.7-flash"], apiKeyPrefix: LLMConstants.APIKeySecret.prefix, apiKeyMinLength: 25, apiKeyPlaceholder: "sk-...", icon: "cloud.fill"),
            .init(id: "kimi", nameKey: "llm.provider.kimi", baseURL: APIPaths.llmProviderKimi, defaultModel: "kimi-k3", suggestedModels: ["kimi-k3", "kimi-k2.7", "moonshot-v1-128k", "moonshot-v1-32k", "moonshot-v1-8k"], apiKeyPrefix: LLMConstants.APIKeySecret.prefix, apiKeyMinLength: 30, apiKeyPlaceholder: "sk-...", icon: "moon.fill"),
            .init(id: "siliconflow", nameKey: "llm.provider.siliconflow", baseURL: APIPaths.llmProviderSiliconFlow, defaultModel: "deepseek-ai/DeepSeek-V4-Pro", suggestedModels: ["deepseek-ai/DeepSeek-V4-Lite", "Qwen/Qwen3.7-Max"], apiKeyPrefix: LLMConstants.APIKeySecret.prefix, apiKeyMinLength: 30, apiKeyPlaceholder: "sk-...", icon: "bolt.fill"),
            .init(id: "custom", nameKey: "llm.provider.custom", baseURL: "", defaultModel: "", suggestedModels: [], apiKeyPrefix: "", apiKeyMinLength: 0, apiKeyPlaceholder: "sk-...", icon: "server.rack")
        ]
        for item in fallbacks {
            result[item.id] = item
        }
        return result
    }

    /// 根据 ID 获取提供商元数据
    func metadata(for id: String) -> LLMProviderMetadata? {
        providers[id]
    }
}

// MARK: - LLM 提供商枚举
/// 智宇支持的所有 AI 服务商
public enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case deepSeek = "deepseek"
    case zhipu = "zhipu"
    case minimax = "minimax"
    case qwen = "qwen"
    case kimi = "kimi"
    case siliconflow = "siliconflow"
    case custom = "custom"

    /// 获取提供商唯一标识
    public var id: String { rawValue }

    /// 内部获取关联元数据
    private var metadata: LLMProviderMetadata? {
        LLMRegistry.shared.metadata(for: rawValue)
    }

    /// 本地化显示名称
    public var displayName: String {
        if let key = metadata?.nameKey {
            return L10n.AI.tr(key)
        }
        return rawValue.capitalized
    }

    /// 默认 API 基础路径
    public var defaultBaseURL: String {
        metadata?.baseURL ?? ""
    }

    /// 默认模型名称
    public var defaultModel: String {
        metadata?.defaultModel ?? ""
    }

    /// 建议模型列表
    public var suggestedModels: [String] {
        metadata?.suggestedModels ?? []
    }

    /// API Key 必需的前缀
    public var apiKeyPrefix: String {
        metadata?.apiKeyPrefix ?? ""
    }

    /// API Key 最小长度要求
    public var apiKeyMinLength: Int {
        metadata?.apiKeyMinLength ?? 0
    }

    /// API Key Placeholder 提示词
    public var apiKeyPlaceholder: String {
        metadata?.apiKeyPlaceholder ?? "sk-..."
    }

    /// 验证给定 API Key 格式规范性
    public func validateAPIKeyFormat(_ key: String) -> (isValid: Bool, message: String?) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (false, L10n.AI.LLM.Validation.emptyKey)
        }
        if !apiKeyPrefix.isEmpty && !trimmed.hasPrefix(apiKeyPrefix) {
            return (false, L10n.AI.LLM.Validation.prefixHint(apiKeyPrefix))
        }
        if apiKeyMinLength > 0 && trimmed.count < apiKeyMinLength {
            return (false, L10n.AI.LLM.Validation.lengthHint(apiKeyMinLength))
        }
        return (true, nil)
    }

    public var icon: String {
        metadata?.icon ?? "server.rack"
    }
}

// MARK: - Smart Ingest Result
typealias SmartIngestResult = SmartIngestResultDTO

// MARK: - LLM Errors
enum LLMError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case httpError(Int)
    case apiError(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return L10n.AI.LLM.Error.notConfigured
        case .invalidURL:
            return L10n.AI.LLM.Error.invalidURL
        case .invalidResponse:
            return L10n.AI.LLM.Error.invalidResponse
        case .unauthorized:
            return L10n.AI.LLM.Error.unauthorized
        case .rateLimited:
            return L10n.AI.LLM.Error.rateLimited
        case .httpError(let code):
            return "\(L10n.AI.LLM.Error.httpError): \(code)"
        case .apiError(let message):
            return "\(L10n.AI.LLM.Error.apiError): \(message)"
        case .cancelled:
            return L10n.AI.LLM.Error.cancelled
        }
    }
}
