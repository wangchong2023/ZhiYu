//
//  LLMModelsTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 LLM 错误类型、提供商枚举、配置仓储的语义与边界行为。
//

import XCTest
@testable import ZhiYu

@MainActor
final class LLMModelsTests: XCTestCase {

    // MARK: - LLMError errorDescription

    func testLLMError_notConfigured_hasDescription() {
        XCTAssertNotNil(LLMError.notConfigured.errorDescription)
    }

    func testLLMError_invalidURL_hasDescription() {
        XCTAssertNotNil(LLMError.invalidURL.errorDescription)
    }

    func testLLMError_invalidResponse_hasDescription() {
        XCTAssertNotNil(LLMError.invalidResponse.errorDescription)
    }

    func testLLMError_unauthorized_hasDescription() {
        XCTAssertNotNil(LLMError.unauthorized.errorDescription)
    }

    func testLLMError_rateLimited_hasDescription() {
        XCTAssertNotNil(LLMError.rateLimited.errorDescription)
    }

    func testLLMError_httpError_containsCode() {
        let desc = LLMError.httpError(500).errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("500") == true, "应包含 HTTP 状态码")
    }

    func testLLMError_apiError_containsMessage() {
        let desc = LLMError.apiError("timeout").errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("timeout") == true, "应包含错误消息")
    }

    func testLLMError_cancelled_hasDescription() {
        XCTAssertNotNil(LLMError.cancelled.errorDescription)
    }

    // MARK: - LLMProvider 枚举

    func testLLMProvider_allCases_containsSevenProviders() {
        XCTAssertEqual(LLMProvider.allCases.count, 7, "应有 7 个提供商")
    }

    func testLLMProvider_deepSeek_rawValue() {
        XCTAssertEqual(LLMProvider.deepSeek.rawValue, "deepseek")
    }

    func testLLMProvider_custom_rawValue() {
        XCTAssertEqual(LLMProvider.custom.rawValue, "custom")
    }

    func testLLMProvider_id_equalsRawValue() {
        for provider in LLMProvider.allCases {
            XCTAssertEqual(provider.id, provider.rawValue, "id 应等于 rawValue")
        }
    }

    func testLLMProvider_deepSeek_hasDefaultBaseURL() {
        XCTAssertFalse(LLMProvider.deepSeek.defaultBaseURL.isEmpty, "DeepSeek 应有默认 baseURL")
    }

    func testLLMProvider_custom_defaultBaseURLEmpty() {
        XCTAssertEqual(LLMProvider.custom.defaultBaseURL, "", "custom 默认 baseURL 为空")
    }

    func testLLMProvider_deepSeek_hasDefaultModel() {
        XCTAssertFalse(LLMProvider.deepSeek.defaultModel.isEmpty, "DeepSeek 应有默认模型")
    }

    func testLLMProvider_deepSeek_hasSuggestedModels() {
        XCTAssertFalse(LLMProvider.deepSeek.suggestedModels.isEmpty, "DeepSeek 应有建议模型列表")
    }

    func testLLMProvider_custom_suggestedModelsEmpty() {
        XCTAssertTrue(LLMProvider.custom.suggestedModels.isEmpty, "custom 建议模型列表为空")
    }

    func testLLMProvider_deepSeek_apiKeyPrefixIsSk() {
        XCTAssertEqual(LLMProvider.deepSeek.apiKeyPrefix, "sk-", "DeepSeek API Key 前缀为 sk-")
    }

    func testLLMProvider_custom_apiKeyPrefixEmpty() {
        XCTAssertEqual(LLMProvider.custom.apiKeyPrefix, "", "custom 无前缀要求")
    }

    func testLLMProvider_deepSeek_apiKeyMinLengthPositive() {
        XCTAssertGreaterThan(LLMProvider.deepSeek.apiKeyMinLength, 0, "DeepSeek 应有最小长度要求")
    }

    func testLLMProvider_custom_apiKeyMinLengthZero() {
        XCTAssertEqual(LLMProvider.custom.apiKeyMinLength, 0, "custom 无最小长度要求")
    }

    func testLLMProvider_icon_notEmpty() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.icon.isEmpty, "\(provider.rawValue) 图标不应为空")
        }
    }

    // MARK: - LLMProvider.validateAPIKeyFormat

    func testValidateAPIKeyFormat_emptyKey_isInvalid() {
        let (isValid, _) = LLMProvider.deepSeek.validateAPIKeyFormat("")
        XCTAssertFalse(isValid, "空 Key 应无效")
    }

    func testValidateAPIKeyFormat_whitespaceOnly_isInvalid() {
        let (isValid, _) = LLMProvider.deepSeek.validateAPIKeyFormat("   ")
        XCTAssertFalse(isValid, "纯空白 Key 应无效")
    }

    func testValidateAPIKeyFormat_deepSeek_correctPrefix_isValid() {
        let (isValid, _) = LLMProvider.deepSeek.validateAPIKeyFormat("sk-123456789012345678901234567890")
        XCTAssertTrue(isValid, "正确前缀且长度足够应有效")
    }

    func testValidateAPIKeyFormat_deepSeek_wrongPrefix_isInvalid() {
        let (isValid, _) = LLMProvider.deepSeek.validateAPIKeyFormat("wrong-prefix-123456789012345678901234567890")
        XCTAssertFalse(isValid, "错误前缀应无效")
    }

    func testValidateAPIKeyFormat_deepSeek_tooShort_isInvalid() {
        let (isValid, _) = LLMProvider.deepSeek.validateAPIKeyFormat("sk-short")
        XCTAssertFalse(isValid, "过短 Key 应无效")
    }

    func testValidateAPIKeyFormat_custom_anyKey_isValid() {
        let (isValid, _) = LLMProvider.custom.validateAPIKeyFormat("any-key")
        XCTAssertTrue(isValid, "custom 无前缀和长度要求，任意非空 Key 应有效")
    }

    func testValidateAPIKeyFormat_zhipu_noPrefixRequirement() {
        let (isValid, _) = LLMProvider.zhipu.validateAPIKeyFormat("any-zhipu-key-long-enough")
        XCTAssertTrue(isValid, "zhipu 无前缀要求，长度足够应有效")
    }

    // MARK: - LLMProviderMetadata Codable

    func testLLMProviderMetadata_codableRoundTrip() throws {
        let original = LLMProviderMetadata(
            id: "test",
            nameKey: "test.key",
            baseURL: "https://test.com",
            defaultModel: "test-model",
            suggestedModels: ["m1", "m2"],
            apiKeyPrefix: "sk-",
            apiKeyMinLength: 10,
            apiKeyPlaceholder: "sk-...",
            icon: "icon"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMProviderMetadata.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.nameKey, original.nameKey)
        XCTAssertEqual(decoded.baseURL, original.baseURL)
        XCTAssertEqual(decoded.defaultModel, original.defaultModel)
        XCTAssertEqual(decoded.suggestedModels, original.suggestedModels)
        XCTAssertEqual(decoded.apiKeyPrefix, original.apiKeyPrefix)
        XCTAssertEqual(decoded.apiKeyMinLength, original.apiKeyMinLength)
        XCTAssertEqual(decoded.apiKeyPlaceholder, original.apiKeyPlaceholder)
        XCTAssertEqual(decoded.icon, original.icon)
    }

    // MARK: - LLMRegistry

    func testLLMRegistry_shared_returnsMetadataForDeepSeek() {
        let metadata = LLMRegistry.shared.metadata(for: "deepseek")
        XCTAssertNotNil(metadata, "应返回 DeepSeek 元数据")
        XCTAssertEqual(metadata?.id, "deepseek")
    }

    func testLLMRegistry_shared_returnsNilForUnknownProvider() {
        let metadata = LLMRegistry.shared.metadata(for: "unknown-provider")
        XCTAssertNil(metadata, "未知提供商应返回 nil")
    }

    func testLLMRegistry_shared_returnsAllSevenProviders() {
        for provider in LLMProvider.allCases {
            let metadata = LLMRegistry.shared.metadata(for: provider.rawValue)
            XCTAssertNotNil(metadata, "\(provider.rawValue) 应有元数据")
        }
    }
}
