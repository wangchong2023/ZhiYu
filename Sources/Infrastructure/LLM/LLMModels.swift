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

// MARK: - LLM 提供商元数据

/// LLM 提供商元数据
/// 包含 API 端点、默认模型及 UI 展示参数。
@MainActor
struct LLMProviderMetadata: Codable {
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
final class LLMRegistry {
    nonisolated(unsafe) static let shared = LLMRegistry()
    private var providers: [String: LLMProviderMetadata] = [:]

    private init() {
        loadProviders()
    }

    private func loadProviders() {
        // 首先尝试从 Bundle 加载（Apple 推荐方式）
        if let url = Bundle.main.url(forResource: "LLMProviders", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([LLMProviderMetadata].self, from: data) {
            for item in list {
                providers[item.id] = item
            }
            return
        }

        // 兜底方案：如果 JSON 未能加载（如尚未打包），使用硬编码数据（DeepSeek 第一位）
        let fallbacks: [LLMProviderMetadata] = [
            .init(id: "deepseek", nameKey: "llm.provider.deepSeek", baseURL: AppConstants.URLs.llmProviderDeepSeek, defaultModel: "deepseek-v4-pro", suggestedModels: ["deepseek-v4-pro", "deepseek-v4-flash"], apiKeyPrefix: "sk-", apiKeyMinLength: 30, apiKeyPlaceholder: "sk-...", icon: "wave.3.forward"),
            .init(id: "zhipu", nameKey: "llm.provider.zhipu", baseURL: AppConstants.URLs.llmProviderZhipu, defaultModel: "glm-5.2", suggestedModels: ["glm-5.2", "glm-5", "glm-5-turbo", "glm-5v-turbo", "glm-4-flash"], apiKeyPrefix: "", apiKeyMinLength: 20, apiKeyPlaceholder: "your-api-key", icon: "sparkles"),
            .init(id: "minimax", nameKey: "llm.provider.minimax", baseURL: AppConstants.URLs.llmProviderMinimax, defaultModel: "abab7-chat", suggestedModels: ["abab7-chat", "abab6.5t-chat", "abab6.5s-chat"], apiKeyPrefix: "", apiKeyMinLength: 20, apiKeyPlaceholder: "your-api-key", icon: "cpu"),
            .init(id: "qwen", nameKey: "llm.provider.qwen", baseURL: AppConstants.URLs.llmProviderQwen, defaultModel: "qwen3.7-max", suggestedModels: ["qwen3.7-max", "qwen3.8-max-preview", "qwen3.7-plus", "qwen3.7-flash"], apiKeyPrefix: "sk-", apiKeyMinLength: 25, apiKeyPlaceholder: "sk-...", icon: "cloud.fill"),
            .init(id: "kimi", nameKey: "llm.provider.kimi", baseURL: AppConstants.URLs.llmProviderKimi, defaultModel: "kimi-k3", suggestedModels: ["kimi-k3", "kimi-k2.7", "moonshot-v1-128k", "moonshot-v1-32k", "moonshot-v1-8k"], apiKeyPrefix: "sk-", apiKeyMinLength: 30, apiKeyPlaceholder: "sk-...", icon: "moon.fill"),
            .init(id: "siliconflow", nameKey: "llm.provider.siliconflow", baseURL: AppConstants.URLs.llmProviderSiliconFlow, defaultModel: "deepseek-ai/DeepSeek-V4-Pro", suggestedModels: ["deepseek-ai/DeepSeek-V4-Lite", "Qwen/Qwen3.7-Max"], apiKeyPrefix: "sk-", apiKeyMinLength: 30, apiKeyPlaceholder: "sk-...", icon: "bolt.fill"),
            .init(id: "custom", nameKey: "llm.provider.custom", baseURL: "", defaultModel: "", suggestedModels: [], apiKeyPrefix: "", apiKeyMinLength: 0, apiKeyPlaceholder: "sk-...", icon: "server.rack")
        ]
        for item in fallbacks {
            providers[item.id] = item
        }
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

// MARK: - LLM Config (Persistence)
/// Manages LLM provider configuration with UserDefaults + Keychain persistence.
final class LLMConfigStore: ObservableObject {
    @Published var provider: LLMProvider {
        didSet { 
            if oldValue != provider {
                saveConfig()
                // 切换提供商时，自动联动装载该提供商专属的 API Key, BaseURL 和 Model
                loadConfigForCurrentProvider()
            }
        }
    }
    @Published var apiKey: String {
        didSet { saveAPIKey(for: provider) }
    }
    @Published var baseURL: String {
        didSet { saveBaseURL(baseURL, for: provider) }
    }
    @Published var model: String {
        didSet { saveModel(model, for: provider) }
    }
    @Published var isEnabled: Bool {
        didSet { saveConfig() }
    }
    @Published var autoScan: Bool {
        didSet { saveConfig() }
    }
    @Published var autoRefactor: Bool {
        didSet { saveConfig() }
    }

    private let configKey = "zhiyu_llm_config"
    private let legacyKeychainAPIKey = "llm_api_key"
    
    private func keychainKey(for provider: LLMProvider) -> String {
        return "llm_api_key_\(provider.rawValue)"
    }
    private func baseURLStorageKey(for provider: LLMProvider) -> String {
        return "llm_base_url_\(provider.rawValue)"
    }
    private func modelStorageKey(for provider: LLMProvider) -> String {
        return "llm_model_\(provider.rawValue)"
    }

    struct Config: Codable {
        let provider: LLMProvider
        let baseURL: String
        let model: String
        let isEnabled: Bool
        let autoScan: Bool
        let autoRefactor: Bool
    }

    init() {
        var initialProvider: LLMProvider = .deepSeek
        var initialIsEnabled = false
        var initialAutoScan = true
        var initialAutoRefactor = false

        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(Config.self, from: data) {
            initialProvider = config.provider
            initialIsEnabled = config.isEnabled
            initialAutoScan = config.autoScan
            initialAutoRefactor = config.autoRefactor
        }

        self.provider = initialProvider
        self.isEnabled = initialIsEnabled
        self.autoScan = initialAutoScan
        self.autoRefactor = initialAutoRefactor
        
        // 自动初始化当前提供商绑定的独立存储参数
        self.baseURL = ""
        self.model = ""
        self.apiKey = ""
        
        self.baseURL = loadBaseURL(for: initialProvider)
        self.model = loadModel(for: initialProvider)
        self.apiKey = loadAPIKey(for: initialProvider)
    }

    /// 切换提供商时联动加载对应 API Key、BaseURL 和 Model
    private func loadConfigForCurrentProvider() {
        self.apiKey = loadAPIKey(for: provider)
        self.baseURL = loadBaseURL(for: provider)
        self.model = loadModel(for: provider)
    }

    /// 加载指定提供商绑定的 Base URL，官方提供商固定返回标准官方 URL
    private func loadBaseURL(for provider: LLMProvider) -> String {
        if provider != .custom {
            return provider.defaultBaseURL
        }
        let key = baseURLStorageKey(for: provider)
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        return provider.defaultBaseURL
    }

    /// 保存指定提供商绑定的 Base URL
    private func saveBaseURL(_ url: String, for provider: LLMProvider) {
        let key = baseURLStorageKey(for: provider)
        UserDefaults.standard.set(url, forKey: key)
        saveConfig()
    }

    /// 加载指定提供商绑定的 Model，针对官方提供商过滤历史非法/废弃脏数据，自动回退至旗舰默认模型
    /// 加载指定提供商绑定的 Model，针对官方提供商过滤历史非法/废弃脏数据，自动回退至旗舰默认模型
    private func loadModel(for provider: LLMProvider) -> String {
        if provider == .custom {
            let key = modelStorageKey(for: provider)
            return UserDefaults.standard.string(forKey: key) ?? ""
        }
        
        let key = modelStorageKey(for: provider)
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            if provider.suggestedModels.contains(stored) {
                return stored
            }
        }
        return provider.defaultModel
    }

    /// 保存指定提供商绑定的 Model
    private func saveModel(_ m: String, for provider: LLMProvider) {
        let key = modelStorageKey(for: provider)
        UserDefaults.standard.set(m, forKey: key)
        saveConfig()
    }

    private func saveConfig() {
        let config = Config(
            provider: provider,
            baseURL: baseURL,
            model: model,
            isEnabled: isEnabled,
            autoScan: autoScan,
            autoRefactor: autoRefactor
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    /// 从安全的 Keychain 或硬件芯片解密加载特定 LLM 提供商的 API 密钥
    private func loadAPIKey(for provider: LLMProvider) -> String {
        let key = keychainKey(for: provider)
        
        do {
            if let storedValue = try KeychainService.shared.retrieve(key: key), !storedValue.isEmpty {
                let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                // 1. 优先尝试 SecureEnclave 硬件解密
                if let decrypted = try? SecureEnclaveCryptoService.shared.decrypt(trimmed), !decrypted.isEmpty {
                    return decrypted.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // 2. 尝试 SecurityManager 软件 AES-GCM 解密
                if let decrypted = try? SecurityManager.shared.decrypt(trimmed), !decrypted.isEmpty {
                    return decrypted.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // 3. 兼容合法格式的明文存储（如 sk- 开头且满足最小长度要求）
                if trimmed.hasPrefix("sk-") || trimmed.count >= 20 {
                    return trimmed
                }
                Logger.shared.error("[LLMConfigStore] API 密钥解密失败 (provider: \(provider))，请重新配置")
                return ""
            }
        } catch {
            Logger.shared.error("[LLMConfigStore] 从钥匙串读取 API 密钥失败", error: error)
        }
        
        // 迁移逻辑：如果新版分提供商 Key 不存在，尝试读取旧版全局 Key
        if let legacyValue = try? KeychainService.shared.retrieve(key: legacyKeychainAPIKey), !legacyValue.isEmpty {
            let clean = legacyValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean
        }

        return ""
    }

    /// 将特定 LLM 提供商的 API 密钥物理加密并安全存储到钥匙串
    private func saveAPIKey(for provider: LLMProvider) {
        let key = keychainKey(for: provider)

        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackKey = "zhiyu_llm_api_key_fallback_\(provider.rawValue)"
        UserDefaults.standard.removeObject(forKey: fallbackKey)

        guard !cleanKey.isEmpty else {
            try? KeychainService.shared.delete(key: key)
            return
        }

        do {
            if let encrypted = try? SecureEnclaveCryptoService.shared.encrypt(cleanKey) {
                try KeychainService.shared.store(key: key, value: encrypted)
            } else if let encrypted = try? SecurityManager.shared.encrypt(cleanKey) {
                try KeychainService.shared.store(key: key, value: encrypted)
            } else {
                try KeychainService.shared.store(key: key, value: cleanKey)
            }
        } catch {
            Logger.shared.error("[LLMConfigStore] 写入加密的 API 密钥至钥匙串失败", error: error)
        }
    }
}
