//
//  NetworkClientStatusCodeTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试
//  核心职责：验证 NetworkClient 对各 HTTP 状态码（201, 204, 500 等）的响应与错误分发行为。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYuUnitTestHost

@MainActor
final class NetworkClientStatusCodeTests: XCTestCase {

    // MARK: - uploadFile HTTP 状态码边界

    /// 验证 uploadFile 在 HTTP 201（Created）时是否被正确接受
    func testUploadFile_http201Created_isAccepted() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        defer { Task { await NetworkClient.shared.setTestSession(nil) } }

        NetworkMockURLProtocol.responseBody = successResponse(payload: "https://cdn.example.com/file.png")
        NetworkMockURLProtocol.statusCode = 201

        do {
            let result = try await NetworkClient.shared.uploadFile(
                path: "/api/v1/upload",
                fileData: Data([0x00]),
                fileName: "test.png",
                mimeType: "image/png",
                requiresAuth: false
            )
            XCTAssertEqual(result, "https://cdn.example.com/file.png", "uploadFile 应接受 HTTP 201 Created")
        } catch {
            XCTFail("uploadFile 应接受 HTTP 201 Created，但抛出: \(error)")
        }
    }

    /// 验证 uploadFile 在 HTTP 204（No Content）时的行为
    func testUploadFile_http204NoContent_failsDecode() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        defer { Task { await NetworkClient.shared.setTestSession(nil) } }

        NetworkMockURLProtocol.responseBody = Data()
        NetworkMockURLProtocol.statusCode = 204

        do {
            _ = try await NetworkClient.shared.uploadFile(
                path: "/api/v1/upload",
                fileData: Data([0x00]),
                fileName: "test.png",
                mimeType: "image/png",
                requiresAuth: false
            )
            XCTFail("204 No Content 应抛出 decodeFailed（无响应体）")
        } catch NetworkError.decodeFailed {
            // 预期：204 无 body，解码失败
        } catch {
            // 其他错误也可接受
        }
    }

    // MARK: - performRequest HTTP 状态码校验

    /// 验证 performRequest 在 HTTP 500 时正确拒绝
    func testPerformRequest_http500_rejectsWithServerError() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        defer { Task { await NetworkClient.shared.setTestSession(nil) } }

        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": "success",
            "requestId": "req-500",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        NetworkMockURLProtocol.responseBody = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        NetworkMockURLProtocol.statusCode = 500

        do {
            let _: String = try await NetworkClient.shared.request(
                path: "/api/test",
                method: "GET",
                requiresAuth: false
            )
            XCTFail("performRequest 应拒绝 HTTP 500")
        } catch {
            XCTAssertTrue(error is NetworkError, "应抛出 NetworkError")
        }
    }

    // MARK: - 缺陷 #216 回归：刷新令牌遇到 5xx 服务端抖动不得误删本地令牌

    func testTokenRefresh_http503DoesNotDeleteKeychainTokens() async throws {
        let originalAccess = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        let originalRefresh = try? KeychainService.shared.retrieve(key: AppConstants.Network.refreshTokenKey)
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "expired_access_token")
        try KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: "valid_refresh_token")

        var callIndex = 0
        NetworkMockURLProtocol.requestHandler = { _ in
            callIndex += 1
            if callIndex == 1 {
                let expiredBody: [String: Any] = [
                    "code": AppConstants.Network.BusinessCode.tokenExpired,
                    "message": "token expired",
                    "requestId": "req-40101",
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                ]
                return (200, (try? JSONSerialization.data(withJSONObject: expiredBody)) ?? Data())
            }
            let gatewayErrorBody: [String: Any] = [
                "code": 503,
                "message": "service unavailable",
                "requestId": "req-503",
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            return (503, (try? JSONSerialization.data(withJSONObject: gatewayErrorBody)) ?? Data())
        }

        await NetworkClient.shared.setTestSession(makeMockSession())
        defer {
            NetworkMockURLProtocol.reset()
            Task { await NetworkClient.shared.setTestSession(nil) }
            if let originalAccess {
                try? KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: originalAccess)
            } else {
                try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
            }
            if let originalRefresh {
                try? KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: originalRefresh)
            } else {
                try? KeychainService.shared.delete(key: AppConstants.Network.refreshTokenKey)
            }
        }

        do {
            let _: String = try await NetworkClient.shared.request(
                path: "/api/protected",
                method: "GET",
                requiresAuth: true
            )
            XCTFail("503 刷新失败应向上抛出 NetworkError.serverError")
        } catch NetworkError.serverError(let code, _) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("期望 NetworkError.serverError(503)，实际为: \(error)")
        }

        let remainingRefresh = try? KeychainService.shared.retrieve(key: AppConstants.Network.refreshTokenKey)
        XCTAssertEqual(remainingRefresh, "valid_refresh_token", "5xx 临时故障绝不得误删用户 Keychain 中的 refreshToken")
    }

    // MARK: - 辅助方法

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [NetworkMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func successResponse<T: Encodable>(payload: T) -> Data {
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": payload,
            "requestId": "req-123",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }
}

// MARK: - Network Mock URLProtocol

final class NetworkMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: Data = Data()
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var requestHandler: ((URLRequest) -> (Int, Data))?

    static func reset() {
        responseBody = Data()
        statusCode = 200
        lastRequest = nil
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        NetworkMockURLProtocol.lastRequest = request

        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let resolvedStatus: Int
        let resolvedBody: Data
        if let handler = NetworkMockURLProtocol.requestHandler {
            (resolvedStatus, resolvedBody) = handler(request)
        } else {
            resolvedStatus = NetworkMockURLProtocol.statusCode
            resolvedBody = NetworkMockURLProtocol.responseBody
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: resolvedStatus,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        if let response = response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: resolvedBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
