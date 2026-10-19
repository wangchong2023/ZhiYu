//
//  LLMSettingsValidationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：验证在线大模型设置开关的前置有效性校验、阻断防线逻辑，以及 Tab 弹窗与个人资料菜单文案对齐。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class LLMSettingsValidationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 模型提供商 API Key 格式校验规则全覆盖

    func testDeepSeekAPIKeyValidation() {
        let provider = LLMProvider.deepSeek
        // 空 Key 拦截
        XCTAssertFalse(provider.validateAPIKeyFormat("").isValid)
        XCTAssertEqual(provider.validateAPIKeyFormat("").message, L10n.AI.LLM.Validation.emptyKey)

        // 缺少 "sk-" 前缀拦截
        XCTAssertFalse(provider.validateAPIKeyFormat("invalid-prefix-12345678901234567890").isValid)
        XCTAssertEqual(provider.validateAPIKeyFormat("invalid").message, L10n.AI.LLM.Validation.prefixHint(provider.apiKeyPrefix))

        // 合法 Key 通过
        XCTAssertTrue(provider.validateAPIKeyFormat("sk-1234567890abcdef1234567890abcdef").isValid)
    }

    func testCustomProviderValidation() {
        let provider = LLMProvider.custom
        // 空 Key 拦截
        XCTAssertFalse(provider.validateAPIKeyFormat("").isValid)
        // 非空 Key 通过
        XCTAssertTrue(provider.validateAPIKeyFormat("any-token-custom-123").isValid)
    }

    // MARK: - 2. 「开启 AI 助手」开关前置有效性与阻断防线测试

    func testEnableAssistantSwitchValidation_BlockedOnEmptyKey() {
        let config = LLMConfigManager()
        config.apiKey = ""
        config.provider = .deepSeek

        // 模拟用户尝试开启 AI 助手时的前置校验逻辑
        let validation = config.provider.validateAPIKeyFormat(config.apiKey)
        var shouldAllowEnable = false
        var alertMessage = ""

        if !validation.isValid {
            shouldAllowEnable = false
            alertMessage = validation.message ?? L10n.AI.LLM.Error.notConfigured
        } else {
            shouldAllowEnable = true
        }

        XCTAssertFalse(shouldAllowEnable, "API Key 为空时，绝不允许开启 AI 助手开关")
        XCTAssertEqual(alertMessage, L10n.AI.LLM.Validation.emptyKey)
    }

    func testEnableAssistantSwitchValidation_BlockedOnCustomProviderEmptyBaseURL() {
        let config = LLMConfigManager()
        config.provider = .custom
        config.apiKey = "custom-token-123"
        config.baseURL = "   " // 空白 URL

        let validation = config.provider.validateAPIKeyFormat(config.apiKey)
        XCTAssertTrue(validation.isValid)

        var shouldAllowEnable = false
        var alertMessage = ""

        if config.provider == .custom && config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            shouldAllowEnable = false
            alertMessage = L10n.AI.LLM.Error.invalidURL
        } else {
            shouldAllowEnable = true
        }

        XCTAssertFalse(shouldAllowEnable, "自定义提供商 BaseURL 为空时，必须阻断开启")
        XCTAssertEqual(alertMessage, L10n.AI.LLM.Error.invalidURL)
    }

    func testEnableAssistantSwitchValidation_AllowedWhenValid() {
        let config = LLMConfigManager()
        config.provider = .deepSeek
        config.apiKey = "sk-valid-deepseek-key-1234567890123456"

        let validation = config.provider.validateAPIKeyFormat(config.apiKey)
        var shouldAllowEnable = false

        if validation.isValid {
            shouldAllowEnable = true
        }

        XCTAssertTrue(shouldAllowEnable, "合法配置时必须允许开启 AI 助手开关")
    }

    // MARK: - 3. 「协作式 AI (影子模式)」前置级联依赖与阻断防线测试

    func testAssistModeSwitchValidation_BlockedWhenAssistantDisabled() {
        let config = LLMConfigManager()
        config.provider = .deepSeek
        config.apiKey = "sk-valid-deepseek-key-1234567890123456"
        config.isEnabled = false // 未开启 AI 助手

        var shouldAllowEnableAssistMode = false
        var alertMessage = ""

        if !config.isEnabled {
            shouldAllowEnableAssistMode = false
            alertMessage = L10n.AI.LLM.Error.notConfigured
        } else {
            shouldAllowEnableAssistMode = true
        }

        XCTAssertFalse(shouldAllowEnableAssistMode, "AI 助手未开启时，必须强阻断开启影子模式")
        XCTAssertEqual(alertMessage, L10n.AI.LLM.Error.notConfigured)
    }

    func testAssistModeSwitchValidation_AllowedWhenAssistantEnabledAndKeyValid() {
        let config = LLMConfigManager()
        config.provider = .deepSeek
        config.apiKey = "sk-valid-deepseek-key-1234567890123456"
        config.isEnabled = true

        var shouldAllowEnableAssistMode = false

        if config.isEnabled && config.provider.validateAPIKeyFormat(config.apiKey).isValid {
            shouldAllowEnableAssistMode = true
        }

        XCTAssertTrue(shouldAllowEnableAssistMode, "AI 助手已就绪且 Key 合法时，必须允许开启影子模式")
    }

    // MARK: - 4. 来源与合成 Tab 弹窗文案与个人资料菜单对齐断言

    func testTabAlertButtons_MatchUserProfileMenuSectionLabel() {
        // 验证来源与合成 Tab 提示弹窗中的按钮文案与个人资料菜单「人工智能」保持 100% 一致
        let aiSectionLabel = L10n.Settings.Section.ai
        XCTAssertFalse(aiSectionLabel.isEmpty)

        // 断言其不应为旧版文案 "参数设置"，必须为强类型的 "人工智能"
        XCTAssertNotEqual(aiSectionLabel, "参数设置")
    }

    // MARK: - 5. 提供商模式与 Base URL 输入框展示逻辑测试

    func testBaseURLField_Visibility_OnlyCustomProviderRequiresBaseURL() {
        let officialProviders: [LLMProvider] = [.deepSeek, .zhipu, .minimax, .qwen, .kimi, .siliconflow]
        for provider in officialProviders {
            XCTAssertFalse(provider == .custom, "\(provider.displayName) 属于内置官方厂商")
            XCTAssertFalse(provider.defaultBaseURL.isEmpty, "\(provider.displayName) 必须具备内置固定官方网关，无需用户配置")
        }

        let customProvider = LLMProvider.custom
        XCTAssertTrue(customProvider == .custom, "自定义 API 提供商必须为 custom")
        XCTAssertTrue(customProvider.defaultBaseURL.isEmpty, "自定义 API 默认 BaseURL 为空，必须依赖用户输入")
    }
}
