//
//  ApiResponseTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 ApiResponse 泛型封装的编解码往返、isSuccess 判定、EmptyData 占位以及 NetworkError 各 case 的 errorDescription 本地化文案。
//

import XCTest
@testable import ZhiYu

// MARK: - ApiResponse 单元测试

final class ApiResponseTests: XCTestCase {

    // MARK: - isSuccess 判定测试

    /// 验证 code == 0 时 isSuccess 为 true
    func testIsSuccessReturnsTrueForCodeZero() throws {
        let response = ApiResponse<EmptyData>(
            code: 0,
            message: "ok",
            data: EmptyData(),
            requestId: "req-1",
            timestamp: 1_700_000_000_000
        )
        XCTAssertTrue(response.isSuccess, "code == 0 时 isSuccess 应为 true")
    }

    /// 验证非 0 code 时 isSuccess 为 false（覆盖正数、负数、大数）
    func testIsSuccessReturnsFalseForNonZeroCode() throws {
        let positive = makeResponse(code: 500)
        XCTAssertFalse(positive.isSuccess, "code=500 时 isSuccess 应为 false")

        let negative = makeResponse(code: -1)
        XCTAssertFalse(negative.isSuccess, "code=-1 时 isSuccess 应为 false")

        let large = makeResponse(code: 999_999)
        XCTAssertFalse(large.isSuccess, "code=999999 时 isSuccess 应为 false")
    }

    // MARK: - Codable 编解码往返测试

    /// 验证 ApiResponse<String> 编解码往返一致性
    func testCodableRoundTripForStringPayload() throws {
        let original = ApiResponse<String>(
            code: 0,
            message: "ok",
            data: "https://cdn.example.com/file.png",
            requestId: "req-roundtrip-123",
            timestamp: 1_700_000_000_000
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ApiResponse<String>.self, from: data)

        XCTAssertEqual(decoded.code, original.code)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertEqual(decoded.data, original.data)
        XCTAssertEqual(decoded.requestId, original.requestId)
        XCTAssertEqual(decoded.timestamp, original.timestamp)
    }

    /// 验证 data 字段为 null 时解码为 nil
    func testDecodesWithNullData() throws {
        let json = Data("{\"code\":0,\"message\":\"ok\",\"data\":null,\"requestId\":\"req-null\",\"timestamp\":1700000000000}".utf8)

        let decoded = try JSONDecoder().decode(ApiResponse<EmptyData>.self, from: json)
        XCTAssertEqual(decoded.code, 0)
        XCTAssertNil(decoded.data, "data 为 null 时应解码为 nil")
    }

    /// 验证复杂嵌套 payload 的编解码
    func testCodableRoundTripForComplexPayload() throws {
        struct Nested: Codable, Equatable {
            let id: Int
            let name: String
            let tags: [String]
        }

        let original = ApiResponse<Nested>(
            code: 0,
            message: "ok",
            data: Nested(id: 42, name: "test", tags: ["a", "b", "c"]),
            requestId: "req-nested",
            timestamp: 1_700_000_000_000
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ApiResponse<Nested>.self, from: data)

        XCTAssertEqual(decoded.data, original.data)
    }

    // MARK: - EmptyData 测试

    /// 验证 EmptyData 编解码往返
    func testEmptyDataCodableRoundTrip() throws {
        let original = EmptyData()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EmptyData.self, from: data)
        XCTAssertNotNil(decoded, "EmptyData 编解码往返应成功")
    }

    // MARK: - NetworkError.errorDescription 本地化文案测试

    /// 验证 .invalidURL 的 errorDescription 非空
    func testNetworkErrorInvalidURLDescription() {
        let error = NetworkError.invalidURL
        XCTAssertNotNil(error.errorDescription, ".invalidURL 应有 errorDescription")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true, ".invalidURL 的 errorDescription 不应为空字符串")
    }

    /// 验证 .tokenExpired 的 errorDescription 非空
    func testNetworkErrorTokenExpiredDescription() {
        let error = NetworkError.tokenExpired
        XCTAssertNotNil(error.errorDescription, ".tokenExpired 应有 errorDescription")
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true, ".tokenExpired 的 errorDescription 不应为空字符串")
    }

    /// 验证 .unauthorized 的 errorDescription 包含原始消息
    func testNetworkErrorUnauthorizedDescription() {
        let msg = "token revoked by user"
        let error = NetworkError.unauthorized(msg)
        XCTAssertNotNil(error.errorDescription, ".unauthorized 应有 errorDescription")
        XCTAssertTrue(error.errorDescription?.contains(msg) ?? false, ".unauthorized 的 errorDescription 应包含原始消息")
    }

    /// 验证 .serverError 的 errorDescription 包含 code 和 message
    func testNetworkErrorServerErrorDescription() {
        let code = 500
        let msg = "internal server error"
        let error = NetworkError.serverError(code, msg)
        XCTAssertNotNil(error.errorDescription, ".serverError 应有 errorDescription")
        let description = error.errorDescription ?? ""
        XCTAssertTrue(description.contains(String(code)), ".serverError 的 errorDescription 应包含 code")
        XCTAssertTrue(description.contains(msg), ".serverError 的 errorDescription 应包含 message")
    }

    /// 验证 .decodeFailed 的 errorDescription 包含底层错误描述
    func testNetworkErrorDecodeFailedDescription() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "decode boom"])
        let error = NetworkError.decodeFailed(underlying)
        XCTAssertNotNil(error.errorDescription, ".decodeFailed 应有 errorDescription")
        XCTAssertTrue(error.errorDescription?.contains("decode boom") ?? false, ".decodeFailed 的 errorDescription 应包含底层错误描述")
    }

    /// 验证 .httpError 的 errorDescription 包含 code
    func testNetworkErrorHTTPErrorDescription() {
        let code = 503
        let error = NetworkError.httpError(code)
        XCTAssertNotNil(error.errorDescription, ".httpError 应有 errorDescription")
        XCTAssertTrue(error.errorDescription?.contains(String(code)) ?? false, ".httpError 的 errorDescription 应包含 code")
    }

    /// 验证 .unexpected 的 errorDescription 包含原始消息
    func testNetworkErrorUnexpectedDescription() {
        let msg = "something went wrong"
        let error = NetworkError.unexpected(msg)
        XCTAssertNotNil(error.errorDescription, ".unexpected 应有 errorDescription")
        XCTAssertTrue(error.errorDescription?.contains(msg) ?? false, ".unexpected 的 errorDescription 应包含原始消息")
    }

    /// 验证 NetworkError 遵循 LocalizedError 协议
    func testNetworkErrorConformsToLocalizedError() {
        let errors: [NetworkError] = [
            .invalidURL,
            .tokenExpired,
            .unauthorized("msg"),
            .serverError(500, "msg"),
            .decodeFailed(NSError(domain: "x", code: 1)),
            .httpError(404),
            .unexpected("msg"),
            .invalidHTTPResponse,
            .missingDataPayload,
            .missingRefreshToken,
            .sessionInvalidated
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "所有 NetworkError case 都应有 errorDescription: \(error)")
        }
    }

    // MARK: - 纯错误码 case 测试（不携带本地化字符串）

    /// 验证 .invalidHTTPResponse 的 errorDescription 为英文调试描述
    func testNetworkErrorInvalidHTTPResponseDescription() {
        let error = NetworkError.invalidHTTPResponse
        XCTAssertEqual(error.errorDescription, "Invalid HTTP response.")
    }

    /// 验证 .missingDataPayload 的 errorDescription 为英文调试描述
    func testNetworkErrorMissingDataPayloadDescription() {
        let error = NetworkError.missingDataPayload
        XCTAssertEqual(error.errorDescription, "Missing data payload.")
    }

    /// 验证 .missingRefreshToken 的 errorDescription 为英文调试描述
    func testNetworkErrorMissingRefreshTokenDescription() {
        let error = NetworkError.missingRefreshToken
        XCTAssertEqual(error.errorDescription, "Missing refresh token.")
    }

    /// 验证 .sessionInvalidated 的 errorDescription 为英文调试描述
    func testNetworkErrorSessionInvalidatedDescription() {
        let error = NetworkError.sessionInvalidated
        XCTAssertEqual(error.errorDescription, "Session invalidated.")
    }

    /// 验证 NetworkError 不混入 L10n（工具类纯错误码原则）
    /// errorDescription 应为英文调试描述，不是本地化文案
    func testNetworkErrorErrorDescriptionIsDebugDescriptionNotLocalized() {
        let error = NetworkError.invalidHTTPResponse
        XCTAssertEqual(error.errorDescription, "Invalid HTTP response.")
        XCTAssertNotEqual(error.errorDescription, L10n.Network.invalidHTTPResponse,
                          "工具类 errorDescription 应为英文调试描述，不应等于本地化文案")
    }

    // MARK: - 辅助方法

    private func makeResponse(code: Int) -> ApiResponse<EmptyData> {
        return ApiResponse<EmptyData>(
            code: code,
            message: "test",
            data: nil,
            requestId: "req-\(code)",
            timestamp: 1_700_000_000_000
        )
    }
}
