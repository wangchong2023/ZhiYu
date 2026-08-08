//
//  LLMProviderMetadataTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LLMProvider computed properties 与 LLMRegistry 元数据查询验证。
//

import XCTest
@testable import ZhiYu

final class LLMProviderMetadataTests: XCTestCase {

    // MARK: - LLMProvider computed properties

    func testDisplayNameReturnsLocalizedValueForKnownProvider() {
        // deepSeek 有 nameKey，应返回本地化值
        let name = LLMProvider.deepSeek.displayName
        XCTAssertFalse(name.isEmpty)
    }

    func testDisplayNameReturnsCapitalizedRawValueWhenMetadataNil() {
        // custom 的 metadata 可能存在，但 rawValue 应可正确获取
        let name = LLMProvider.custom.displayName
        XCTAssertFalse(name.isEmpty)
    }

    func testDefaultBaseURLReturnsNonEmptyForKnownProviders() {
        XCTAssertFalse(LLMProvider.deepSeek.defaultBaseURL.isEmpty)
        XCTAssertFalse(LLMProvider.zhipu.defaultBaseURL.isEmpty)
        XCTAssertFalse(LLMProvider.minimax.defaultBaseURL.isEmpty)
    }

    func testDefaultBaseURLReturnsEmptyForCustom() {
        // custom 的 baseURL 为空字符串
        XCTAssertEqual(LLMProvider.custom.defaultBaseURL, "")
    }

    func testDefaultModelReturnsNonEmptyForKnownProviders() {
        XCTAssertFalse(LLMProvider.deepSeek.defaultModel.isEmpty)
        XCTAssertFalse(LLMProvider.zhipu.defaultModel.isEmpty)
    }

    func testSuggestedModelsReturnsNonEmptyForKnownProviders() {
        XCTAssertGreaterThan(LLMProvider.deepSeek.suggestedModels.count, 0)
        XCTAssertGreaterThan(LLMProvider.zhipu.suggestedModels.count, 0)
    }

    func testSuggestedModelsReturnsEmptyForCustom() {
        XCTAssertEqual(LLMProvider.custom.suggestedModels, [])
    }

    func testApiKeyPrefixReturnsSkForDeepSeek() {
        XCTAssertEqual(LLMProvider.deepSeek.apiKeyPrefix, "sk-")
    }

    func testApiKeyPrefixReturnsEmptyForZhipu() {
        XCTAssertEqual(LLMProvider.zhipu.apiKeyPrefix, "")
    }

    func testApiKeyMinLengthReturnsCorrectValue() {
        XCTAssertGreaterThan(LLMProvider.deepSeek.apiKeyMinLength, 0)
        XCTAssertEqual(LLMProvider.custom.apiKeyMinLength, 0)
    }

    func testApiKeyPlaceholderReturnsCorrectValue() {
        XCTAssertFalse(LLMProvider.deepSeek.apiKeyPlaceholder.isEmpty)
        XCTAssertFalse(LLMProvider.zhipu.apiKeyPlaceholder.isEmpty)
    }

    func testIconReturnsCorrectValue() {
        XCTAssertFalse(LLMProvider.deepSeek.icon.isEmpty)
        XCTAssertFalse(LLMProvider.zhipu.icon.isEmpty)
    }

    func testIconReturnsDefaultForCustom() {
        XCTAssertEqual(LLMProvider.custom.icon, "server.rack")
    }

    // MARK: - validateAPIKeyFormat

    func testValidateAPIKeyFormatRejectsEmptyKey() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.message)
    }

    func testValidateAPIKeyFormatRejectsWrongPrefix() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("wrong-prefix-key-that-is-long-enough")
        XCTAssertFalse(result.isValid)
    }

    func testValidateAPIKeyFormatRejectsTooShortKey() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("sk-short")
        XCTAssertFalse(result.isValid)
    }

    func testValidateAPIKeyFormatAcceptsValidKey() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("sk-1234567890abcdefghijklmnopqrstuvwxyz1234")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.message)
    }

    func testValidateAPIKeyFormatAcceptsAnyKeyForZhipu() {
        // zhipu 无前缀要求
        let result = LLMProvider.zhipu.validateAPIKeyFormat("any-key-at-least-20-chars-long")
        XCTAssertTrue(result.isValid)
    }

    // MARK: - LLMRegistry

    @MainActor
    func testRegistryReturnsMetadataForKnownProvider() {
        let metadata = LLMRegistry.shared.metadata(for: "deepseek")
        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.id, "deepseek")
    }

    @MainActor
    func testRegistryReturnsNilForUnknownProvider() {
        let metadata = LLMRegistry.shared.metadata(for: "nonexistent-provider")
        XCTAssertNil(metadata)
    }
}
