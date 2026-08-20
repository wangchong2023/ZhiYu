//
//  NetworkErrorUserMessageTests.swift
//  ZhiYuTests
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 NetworkError+UserMessage 扩展将纯错误码正确映射为面向用户的本地化文案。
//

import XCTest
@testable import ZhiYu

final class NetworkErrorUserMessageTests: XCTestCase {

    // MARK: - userMessage 本地化文案测试

    /// 验证 .invalidURL 的 userMessage 返回本地化文案
    func testInvalidURLUserMessage() {
        let error = NetworkError.invalidURL
        XCTAssertFalse(error.userMessage.isEmpty, ".invalidURL 的 userMessage 不应为空")
        XCTAssertEqual(error.userMessage, L10n.Network.errorInvalidURL)
    }

    /// 验证 .tokenExpired 的 userMessage 返回本地化文案
    func testTokenExpiredUserMessage() {
        let error = NetworkError.tokenExpired
        XCTAssertFalse(error.userMessage.isEmpty, ".tokenExpired 的 userMessage 不应为空")
        XCTAssertEqual(error.userMessage, L10n.Network.errorTokenExpired)
    }

    /// 验证 .unauthorized 的 userMessage 包含原始消息
    func testUnauthorizedUserMessage() {
        let msg = "token revoked"
        let error = NetworkError.unauthorized(msg)
        XCTAssertTrue(error.userMessage.contains(msg), ".unauthorized 的 userMessage 应包含原始消息")
    }

    /// 验证 .serverError 的 userMessage 包含 code 和 message
    func testServerErrorUserMessage() {
        let error = NetworkError.serverError(500, "internal error")
        XCTAssertTrue(error.userMessage.contains("500"), ".serverError 的 userMessage 应包含 code")
        XCTAssertTrue(error.userMessage.contains("internal error"), ".serverError 的 userMessage 应包含 message")
    }

    /// 验证 .invalidHTTPResponse 的 userMessage 返回本地化文案
    func testInvalidHTTPResponseUserMessage() {
        let error = NetworkError.invalidHTTPResponse
        XCTAssertEqual(error.userMessage, L10n.Network.invalidHTTPResponse)
    }

    /// 验证 .missingDataPayload 的 userMessage 返回本地化文案
    func testMissingDataPayloadUserMessage() {
        let error = NetworkError.missingDataPayload
        XCTAssertEqual(error.userMessage, L10n.Network.missingDataPayload)
    }

    /// 验证 .missingRefreshToken 的 userMessage 返回本地化文案
    func testMissingRefreshTokenUserMessage() {
        let error = NetworkError.missingRefreshToken
        XCTAssertEqual(error.userMessage, L10n.Network.missingRefreshToken)
    }

    /// 验证 .sessionInvalidated 的 userMessage 返回本地化文案
    func testSessionInvalidatedUserMessage() {
        let error = NetworkError.sessionInvalidated
        XCTAssertEqual(error.userMessage, L10n.Network.sessionInvalidated)
    }

    // MARK: - errorDescription vs userMessage 区分测试

    /// 验证 errorDescription（英文调试描述）与 userMessage（本地化文案）不同
    /// 工具类不混入多国语言原则的核心验证
    func testErrorDescriptionDiffersFromUserMessage() {
        let error = NetworkError.invalidHTTPResponse
        XCTAssertNotEqual(error.errorDescription, error.userMessage,
                          "errorDescription（英文调试）应与 userMessage（本地化文案）不同")
        XCTAssertEqual(error.errorDescription, "Invalid HTTP response.")
        XCTAssertEqual(error.userMessage, L10n.Network.invalidHTTPResponse)
    }

    /// 验证所有纯错误码 case 的 userMessage 非空
    func testAllPureErrorCodeUserMessagesNonEmpty() {
        let errors: [NetworkError] = [
            .invalidHTTPResponse,
            .missingDataPayload,
            .missingRefreshToken,
            .sessionInvalidated
        ]
        for error in errors {
            XCTAssertFalse(error.userMessage.isEmpty, "纯错误码 case 的 userMessage 不应为空: \(error)")
        }
    }
}
