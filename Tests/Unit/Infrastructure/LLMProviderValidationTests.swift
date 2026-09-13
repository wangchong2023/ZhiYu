//
//  LLMProviderValidationTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMProvider.validateAPIKeyFormat 的边界条件与各提供商规范。
//

import XCTest
@testable import ZhiYu

final class LLMProviderValidationTests: XCTestCase {

    // MARK: - 空键

    func testEmptyKeyIsInvalid() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("")
        XCTAssertFalse(result.isValid, "空键应无效")
        XCTAssertNotNil(result.message, "应返回错误提示")
    }

    func testWhitespaceOnlyKeyIsInvalid() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("   \n\t  ")
        XCTAssertFalse(result.isValid, "纯空白键应无效")
    }

    // MARK: - 前缀校验

    func testDeepSeekCorrectPrefix() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("sk-123456789012345678901234567890")
        XCTAssertTrue(result.isValid, "sk- 前缀 + 足够长度应有效")
        XCTAssertNil(result.message, "有效时 message 应为 nil")
    }

    func testDeepSeekWrongPrefix() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("invalid-prefix-123456789012345678901234567890")
        XCTAssertFalse(result.isValid, "错误前缀应无效")
        XCTAssertNotNil(result.message, "应返回前缀提示")
    }

    func testKimiCorrectPrefix() {
        let result = LLMProvider.kimi.validateAPIKeyFormat("sk-123456789012345678901234567890")
        XCTAssertTrue(result.isValid, "Kimi sk- 前缀应有效")
    }

    func testQwenCorrectPrefix() {
        let result = LLMProvider.qwen.validateAPIKeyFormat("sk-1234567890123456789012345")
        XCTAssertTrue(result.isValid, "Qwen sk- 前缀应有效")
    }

    // MARK: - 无前缀要求提供商

    func testZhipuNoPrefixRequirement() {
        let result = LLMProvider.zhipu.validateAPIKeyFormat("12345678901234567890123")
        XCTAssertTrue(result.isValid, "Zhipu 无前缀要求，足够长度应有效")
    }

    func testZhipuShortKeyInvalid() {
        let result = LLMProvider.zhipu.validateAPIKeyFormat("short")
        XCTAssertFalse(result.isValid, "Zhipu 短键应无效")
    }

    // MARK: - 长度校验

    func testDeepSeekShortKeyInvalid() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("sk-short")
        XCTAssertFalse(result.isValid, "DeepSeek 短键应无效")
    }

    // MARK: - custom 提供商

    func testCustomProviderValidation() {
        let result = LLMProvider.custom.validateAPIKeyFormat("any-key-format")
        // custom 提供商可能无前缀和长度要求
        if LLMProvider.custom.apiKeyPrefix.isEmpty && LLMProvider.custom.apiKeyMinLength == 0 {
            XCTAssertTrue(result.isValid, "custom 无前缀和长度要求时应有效")
        } else {
            XCTAssertFalse(result.isValid, "custom 有要求时不满足应无效")
        }
    }

    // MARK: - 前后空白修剪

    func testKeyWithWhitespaceTrimmed() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("  sk-123456789012345678901234567890  \n")
        XCTAssertTrue(result.isValid, "前后空白应被修剪，修剪后应有效")
    }

    // MARK: - 所有提供商不崩溃

    func testAllProvidersDoNotCrashOnEmpty() {
        for provider in LLMProvider.allCases {
            let result = provider.validateAPIKeyFormat("")
            XCTAssertFalse(result.isValid, "\(provider.displayName) 空键应无效")
        }
    }

    func testAllProvidersDoNotCrashOnLongKey() {
        let longKey = String(repeating: "a", count: 1000)
        for provider in LLMProvider.allCases {
            let result = provider.validateAPIKeyFormat(longKey)
            // 长键应有效（除非有前缀要求且不匹配）
            if !provider.apiKeyPrefix.isEmpty && !longKey.hasPrefix(provider.apiKeyPrefix) {
                XCTAssertFalse(result.isValid, "\(provider.displayName) 长键但错误前缀应无效")
            } else {
                XCTAssertTrue(result.isValid, "\(provider.displayName) 长键应有效")
            }
        }
    }

    // MARK: - displayName 非空

    func testAllProvidersHaveDisplayName() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty, "\(provider.rawValue) 应有非空 displayName")
        }
    }

    // MARK: - defaultBaseURL 非空（custom 除外）

    func testOfficialProvidersHaveDefaultBaseURL() {
        for provider in LLMProvider.allCases where provider != .custom {
            XCTAssertFalse(provider.defaultBaseURL.isEmpty, "\(provider.displayName) 应有非空 defaultBaseURL")
        }
    }

    // MARK: - defaultModel 非空（custom 除外）

    func testOfficialProvidersHaveDefaultModel() {
        for provider in LLMProvider.allCases where provider != .custom {
            XCTAssertFalse(provider.defaultModel.isEmpty, "\(provider.displayName) 应有非空 defaultModel")
        }
    }

    // MARK: - apiKeyPlaceholder

    func testApiKeyPlaceholderNonEmpty() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.apiKeyPlaceholder.isEmpty, "\(provider.displayName) 应有非空 apiKeyPlaceholder")
        }
    }

    // MARK: - icon 非空

    func testIconNonEmpty() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.icon.isEmpty, "\(provider.displayName) 应有非空 icon")
        }
    }
}
