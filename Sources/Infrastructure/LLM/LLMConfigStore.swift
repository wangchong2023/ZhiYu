//
//  LLMConfigStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / LLM
//  核心职责：大模型配置管理（LLMConfigStore），负责提供商配置持久化与密钥安全存取。
//

import Foundation
import Combine
import UFPCore
import Dependencies

// MARK: - LLM Config (Persistence)
/// Manages LLM provider configuration with UserDefaults + Keychain persistence.
final class LLMConfigStore: ObservableObject {
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?
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

        let resolvedKeyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        if let data = resolvedKeyStore?.data(forKey: configKey),
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
        if let stored = keyStore?.string(forKey: key), !stored.isEmpty {
            return stored
        }
        return provider.defaultBaseURL
    }

    /// 保存指定提供商绑定的 Base URL
    private func saveBaseURL(_ url: String, for provider: LLMProvider) {
        let key = baseURLStorageKey(for: provider)
        keyStore?.set(url, forKey: key)
        saveConfig()
    }

    /// 加载指定提供商绑定的 Model，针对官方提供商过滤历史非法/废弃脏数据，自动回退至旗舰默认模型
    private func loadModel(for provider: LLMProvider) -> String {
        if provider == .custom {
            let key = modelStorageKey(for: provider)
            return keyStore?.string(forKey: key) ?? ""
        }
        
        let key = modelStorageKey(for: provider)
        if let stored = keyStore?.string(forKey: key), !stored.isEmpty {
            if provider.suggestedModels.contains(stored) {
                return stored
            }
        }
        return provider.defaultModel
    }

    /// 保存指定提供商绑定的 Model
    private func saveModel(_ m: String, for provider: LLMProvider) {
        let key = modelStorageKey(for: provider)
        keyStore?.set(m, forKey: key)
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
            keyStore?.set(data, forKey: configKey)
        }
    }

    /// 从安全的 Keychain 或硬件芯片解密加载特定 LLM 提供商的 API 密钥
    private func loadAPIKey(for provider: LLMProvider) -> String {
        let key = keychainKey(for: provider)

        do {
            if let storedValue = try KeychainService.shared.retrieve(key: key), !storedValue.isEmpty {
                let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                // 优先尝试 SecureEnclave 硬件解密，其次 SecurityManager 软件解密；均失败时返回原始存储值
                return Self.decryptAPIKey(trimmed)
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
        keyStore?.removeObject(forKey: fallbackKey)

        guard !cleanKey.isEmpty else {
            try? KeychainService.shared.delete(key: key)
            return
        }

        do {
            let encrypted = Self.encryptAPIKey(cleanKey)
            try KeychainService.shared.store(key: key, value: encrypted)
        } catch {
            Logger.shared.error("[LLMConfigStore] 写入加密的 API 密钥至钥匙串失败", error: error)
        }
    }

    /// 解密 API 密钥：优先 SecureEnclave 硬件解密，其次 SecurityManager 软件解密，均失败返回原文
    /// - Parameter trimmed: 已修剪空白的密文
    /// - Returns: 解密后的明文密钥
    private static func decryptAPIKey(_ trimmed: String) -> String {
        // 1. 优先尝试 SecureEnclave 硬件解密
        if let decrypted = try? SecureEnclaveCryptoService.shared.decrypt(trimmed), !decrypted.isEmpty {
            return decrypted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 2. 尝试 SecurityManager 软件 AES-GCM 解密
        if let decrypted = try? SecurityManager.shared.decrypt(trimmed), !decrypted.isEmpty {
            return decrypted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 3. 解密失败时返回原始存储值（信任 Keychain 存储层，由调用方判断有效性）
        //    避免因明文格式检查过严而静默丢弃合法存储的 API 密钥
        return trimmed
    }

    /// 加密 API 密钥：优先 SecureEnclave 硬件加密，其次 SecurityManager 软件加密，均失败返回原文
    /// - Parameter cleanKey: 已修剪空白的明文密钥
    /// - Returns: 加密后的密文
    private static func encryptAPIKey(_ cleanKey: String) -> String {
        if let encrypted = try? SecureEnclaveCryptoService.shared.encrypt(cleanKey) {
            return encrypted
        }
        if let encrypted = try? SecurityManager.shared.encrypt(cleanKey) {
            return encrypted
        }
        return cleanKey
    }
}
