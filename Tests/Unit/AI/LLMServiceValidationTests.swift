//
//  LLMServiceValidationTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMService.validateAPIKey 的连通性检测结果映射与错误码分类。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class LLMServiceValidationTests: XCTestCase {

    private var config: LLMConfigManager!
    private var mockChat: MockChatLLMService!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        config = LLMConfigManager()
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)
        mockChat = MockChatLLMService()
        ServiceContainer.shared.register(mockChat as any LLMChatServiceProtocol, for: (any LLMChatServiceProtocol).self)
    }

    override func tearDown() async throws {
        config = nil
        mockChat = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 成功路径

    func testValidateAPIKeySuccessReturnsIsSuccessTrue() async throws {
        let service = LLMService()
        let result = try await service.validateAPIKey()
        XCTAssertTrue(result.isSuccess, "Mock 返回成功时 isSuccess 应为 true")
        XCTAssertNil(result.errorCode, "成功时 errorCode 应为 nil")
        XCTAssertNil(result.errorMessage, "成功时 errorMessage 应为 nil")
        XCTAssertGreaterThanOrEqual(result.latencyMS, 0, "延迟应为非负数")
    }

    // MARK: - 失败路径：unauthorized

    func testValidateAPIKeyUnauthorizedReturns401() async {
        mockChat.stubGenerateError = LLMError.unauthorized
        let service = LLMService()
        let result = try? await service.validateAPIKey()
        XCTAssertEqual(result?.isSuccess, false, "unauthorized 时 isSuccess 应为 false")
        XCTAssertEqual(result?.errorCode, "401", "unauthorized 应映射为 401")
    }

    // MARK: - 失败路径：rateLimited

    func testValidateAPIKeyRateLimitedReturns429() async {
        mockChat.stubGenerateError = LLMError.rateLimited
        let service = LLMService()
        let result = try? await service.validateAPIKey()
        XCTAssertEqual(result?.isSuccess, false)
        XCTAssertEqual(result?.errorCode, "429", "rateLimited 应映射为 429")
    }

    // MARK: - 失败路径：httpError

    func testValidateAPIKeyHttpErrorReturnsStatusCode() async {
        mockChat.stubGenerateError = LLMError.httpError(500)
        let service = LLMService()
        let result = try? await service.validateAPIKey()
        XCTAssertEqual(result?.isSuccess, false)
        XCTAssertEqual(result?.errorCode, "500", "httpError(500) 应映射为 500")
    }

    // MARK: - 失败路径：其他错误

    func testValidateAPIKeyOtherErrorReturnsERR() async {
        mockChat.stubGenerateError = LLMError.invalidResponse
        let service = LLMService()
        let result = try? await service.validateAPIKey()
        XCTAssertEqual(result?.isSuccess, false)
        XCTAssertEqual(result?.errorCode, "ERR", "未分类错误应映射为 ERR")
    }

    // MARK: - ValidationResult 结构

    func testValidationResultStoresAllFields() {
        let result = LLMService.ValidationResult(
            isSuccess: true,
            latencyMS: 150,
            streamTested: true,
            streamOK: true,
            errorCode: nil,
            errorMessage: nil
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.latencyMS, 150)
        XCTAssertTrue(result.streamTested)
        XCTAssertTrue(result.streamOK)
    }
}
