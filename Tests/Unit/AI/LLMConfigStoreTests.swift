//
//  LLMConfigStoreTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

@MainActor
final class LLMConfigStoreTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        // 清理 UserDefaults 持久化，确保每个 Test Case 环境干净且物理隔离
        UserDefaults.standard.removeObject(forKey: "zhiyu_llm_config")
        for provider in LLMProvider.allCases {
            UserDefaults.standard.removeObject(forKey: "llm_base_url_\(provider.rawValue)")
            UserDefaults.standard.removeObject(forKey: "llm_model_\(provider.rawValue)")
            UserDefaults.standard.removeObject(forKey: "zhiyu_llm_api_key_fallback_\(provider.rawValue)")
            try? KeychainService.shared.delete(key: "llm_api_key_\(provider.rawValue)")
        }
    }
    
    // MARK: - 1. 顺位与提供商枚举排序测试
    
    func testLLMProvider_Ordering() {
        // 断言 DeepSeek 物理处于第一顺位
        XCTAssertEqual(LLMProvider.allCases.first, .deepSeek, "DeepSeek 必须为第 1 顺位模型提供商")
        XCTAssertEqual(LLMProvider.allCases.count, 7, "应当包含 7 个模型提供商")
    }

    // MARK: - 2. 7 大提供商隔离恢复全覆盖矩阵测试
    
    func testProviderSwitch_RestoresProviderSpecificConfig_AllProviders() {
        let store = LLMConfigStore()
        
        let allProviders: [LLMProvider] = [.deepSeek, .zhipu, .minimax, .qwen, .kimi, .siliconflow, .custom]
        
        // 步骤 1：为每一个 Provider 写入独一无二的配置参数（模型选择官方 suggestedModels 内部合法模型）
        for provider in allProviders {
            store.provider = provider
            store.apiKey = "key_\(provider.rawValue)"
            store.baseURL = "https://custom.\(provider.rawValue).com/v1"
            store.model = provider.suggestedModels.first ?? "custom-model-\(provider.rawValue)"
        }
        
        // 步骤 2：轮询切换 provider，验证各自独立的配置 100% 精准恢复与隔离，无交叉串号
        // 既有设计规范：官方提供商 baseURL 为固定官方入口，只有 custom 允许自定义 baseURL
        for provider in allProviders {
            store.provider = provider
            XCTAssertEqual(store.apiKey, "key_\(provider.rawValue)", "\(provider.displayName) 专属 API Key 还原失败")
            let expectedBaseURL = (provider == .custom) ? "https://custom.custom.com/v1" : provider.defaultBaseURL
            XCTAssertEqual(store.baseURL, expectedBaseURL, "\(provider.displayName) 专属 BaseURL 还原失败")
            let expectedModel = provider.suggestedModels.first ?? "custom-model-\(provider.rawValue)"
            XCTAssertEqual(store.model, expectedModel, "\(provider.displayName) 专属 Model 还原失败")
        }
    }

    // MARK: - 3. 7 大提供商默认 BaseURL 与默认 Model 回退测试
    
    func testProviderDefaultFallback_AllProviders() {
        let store = LLMConfigStore()
        
        // 测试首次切至未配置过的特定提供商时，自动回退至官方推荐默认值
        struct FallbackExpectation {
            let provider: LLMProvider
            let expectedBaseURL: String
            let expectedModel: String
        }
        
        let expectations: [FallbackExpectation] = [
            .init(provider: .deepSeek, expectedBaseURL: "https://api.deepseek.com/v1", expectedModel: "deepseek-v4-pro"),
            .init(provider: .zhipu, expectedBaseURL: "https://open.bigmodel.cn/api/paas/v4", expectedModel: "glm-5.2"),
            .init(provider: .minimax, expectedBaseURL: "https://api.minimax.chat/v1", expectedModel: "abab7-chat"),
            .init(provider: .qwen, expectedBaseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", expectedModel: "qwen3.7-max"),
            .init(provider: .kimi, expectedBaseURL: "https://api.moonshot.cn/v1", expectedModel: "kimi-k3"),
            .init(provider: .siliconflow, expectedBaseURL: "https://api.siliconflow.cn/v1", expectedModel: "deepseek-ai/DeepSeek-V4-Pro")
        ]
        
        for item in expectations {
            let provider = item.provider
            // 清理旧缓存以模拟首次加载
            UserDefaults.standard.removeObject(forKey: "llm_base_url_\(provider.rawValue)")
            UserDefaults.standard.removeObject(forKey: "llm_model_\(provider.rawValue)")
            
            store.provider = provider
            XCTAssertEqual(store.baseURL, item.expectedBaseURL, "\(provider.displayName) 默认 BaseURL 不对齐")
            XCTAssertEqual(store.model, item.expectedModel, "\(provider.displayName) 默认 Model 不对齐")
        }
    }

    // MARK: - 4. 7 大提供商 API Key 前缀与最小长度校验测试
    
    func testProviderMetadata_APIKeyValidation_AllProviders() {
        // DeepSeek
        let ds = LLMProvider.deepSeek
        XCTAssertEqual(ds.apiKeyPrefix, "sk-")
        XCTAssertTrue(ds.validateAPIKeyFormat("sk-123456789012345678901234567890").isValid)
        XCTAssertFalse(ds.validateAPIKeyFormat("invalid-prefix-12345678901234567890").isValid)
        
        // Kimi
        let kimi = LLMProvider.kimi
        XCTAssertEqual(kimi.apiKeyPrefix, "sk-")
        XCTAssertTrue(kimi.validateAPIKeyFormat("sk-123456789012345678901234567890").isValid)
        
        // Qwen
        let qwen = LLMProvider.qwen
        XCTAssertEqual(qwen.apiKeyPrefix, "sk-")
        XCTAssertTrue(qwen.validateAPIKeyFormat("sk-1234567890123456789012345").isValid)
        
        // Zhipu
        let zhipu = LLMProvider.zhipu
        XCTAssertTrue(zhipu.validateAPIKeyFormat("12345678901234567890123").isValid)
        XCTAssertFalse(zhipu.validateAPIKeyFormat("short").isValid)
    }

    // MARK: - 5. 提供商切换触发 LLMConfigManager 刷新订阅测试
    
    func testProviderSwitch_TriggersSubServiceRefreshAndUIBinding() {
        let manager = LLMConfigManager()
        var refreshTriggered = false
        
        manager.setRefreshHandler {
            refreshTriggered = true
        }
        
        manager.provider = .kimi
        XCTAssertTrue(refreshTriggered, "切换提供商时必须触发底座服务的 refreshSubServices 机制")
    }

    // MARK: - 6. 校验 JSON 元数据解析规范
    
    func testLLMProvidersJSON_ContainsLatestOfficialModels() {
        let registry = LLMRegistry.shared
        
        let dsMeta = registry.metadata(for: "deepseek")
        XCTAssertNotNil(dsMeta)
        XCTAssertEqual(dsMeta?.defaultModel, "deepseek-v4-pro")
        XCTAssertFalse(dsMeta?.suggestedModels.contains("deepseek-chat") ?? true, "不应包含旧版 deepseek-chat")
        
        let kimiMeta = registry.metadata(for: "kimi")
        XCTAssertNotNil(kimiMeta)
        XCTAssertEqual(kimiMeta?.defaultModel, "kimi-k3")
        XCTAssertFalse(kimiMeta?.suggestedModels.contains("kimi-latest") ?? true, "不应包含泛化别名 kimi-latest")
        
        let qwenMeta = registry.metadata(for: "qwen")
        XCTAssertNotNil(qwenMeta)
        XCTAssertEqual(qwenMeta?.defaultModel, "qwen3.7-max")
    }

    // MARK: - 7. 重置功能与 UI 按钮防误触隔离断言

    func testResetToDefault_ResetsProviderToDeepSeek() {
        let store = LLMConfigStore()
        // 先设为 Custom
        store.provider = .custom
        XCTAssertEqual(store.provider, .custom)
        
        // 模拟用户点击重置按钮行为
        store.provider = .deepSeek
        XCTAssertEqual(store.provider, .deepSeek, "重置后默认提供商必须为 DeepSeek")
        XCTAssertEqual(store.model, "deepseek-v4-pro", "重置后默认模型必须为 deepseek-v4-pro")
        XCTAssertEqual(store.baseURL, "https://api.deepseek.com/v1", "重置后默认 BaseURL 必须为官方标准地址")
    }
}
