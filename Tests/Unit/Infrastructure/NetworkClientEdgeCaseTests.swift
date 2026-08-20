//
//  NetworkClientEdgeCaseTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 NetworkClient 的边界分支：invalidURL、uploadFile 业务 code 非 0、requiresAuth=false 组合、40101 重试防死循环、并发刷新复用等。
//

import XCTest
@testable import ZhiYu

// MARK: - NetworkClient 边界分支测试

final class NetworkClientEdgeCaseTests: XCTestCase {

    // MARK: - 测试夹具

    override func setUp() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
        try? KeychainService.shared.delete(key: AppConstants.Network.refreshTokenKey)
    }

    override func tearDown() async throws {
        await NetworkClient.shared.setTestSession(nil)
        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
        try? KeychainService.shared.delete(key: AppConstants.Network.refreshTokenKey)
        NetworkClientEdgeMockURLProtocol.reset()
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [NetworkClientEdgeMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func jsonData(from dict: [String: Any]) -> Data {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return Data()
        }
        return data
    }

    private func successResponse<T: Encodable>(payload: T) -> Data {
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": payload,
            "requestId": "req-123",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return jsonData(from: body)
    }

    private func errorResponse(code: Int, message: String) -> Data {
        let body: [String: Any] = [
            "code": code,
            "message": message,
            "data": NSNull(),
            "requestId": "req-err",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return jsonData(from: body)
    }

    // MARK: - uploadFile 业务 code 非 0 测试

    /// 验证 uploadFile 在 HTTP 200 但业务 code 非 0 时抛 serverError
    func testUploadFileThrowsServerErrorOnNonZeroCode() async throws {
        NetworkClientEdgeMockURLProtocol.responseBody = errorResponse(code: 4001, message: "file too large")
        NetworkClientEdgeMockURLProtocol.statusCode = 200

        do {
            _ = try await NetworkClient.shared.uploadFile(
                path: "/api/v1/upload",
                fileData: Data([0x00]),
                fileName: "test.png",
                mimeType: "image/png"
            )
            XCTFail("应抛出 serverError")
        } catch let NetworkError.serverError(code, msg) {
            XCTAssertEqual(code, 4001)
            XCTAssertEqual(msg, "file too large")
        }
    }

    /// 验证 uploadFile 在响应非合法 JSON 时抛 decodeFailed
    func testUploadFileThrowsDecodeFailedOnInvalidJSON() async throws {
        NetworkClientEdgeMockURLProtocol.responseBody = Data("not json".utf8)
        NetworkClientEdgeMockURLProtocol.statusCode = 200

        do {
            _ = try await NetworkClient.shared.uploadFile(
                path: "/api/v1/upload",
                fileData: Data([0x00]),
                fileName: "test.png",
                mimeType: "image/png"
            )
            XCTFail("应抛出 decodeFailed")
        } catch NetworkError.decodeFailed {
            // 预期
        }
    }

    /// 验证 uploadFile 在 payload 缺失时抛 missingDataPayload
    func testUploadFileThrowsUnexpectedWhenPayloadMissing() async throws {
        // code==0 但 data 为 null，String 类型无法解码
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": NSNull(),
            "requestId": "req-null",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        NetworkClientEdgeMockURLProtocol.responseBody = jsonData(from: body)
        NetworkClientEdgeMockURLProtocol.statusCode = 200

        do {
            _ = try await NetworkClient.shared.uploadFile(
                path: "/api/v1/upload",
                fileData: Data([0x00]),
                fileName: "test.png",
                mimeType: "image/png"
            )
            XCTFail("应抛出 missingDataPayload")
        } catch NetworkError.missingDataPayload {
            // 预期：payload 缺失
        }
    }

    // MARK: - requiresAuth=false 组合测试

    /// 验证 uploadFile(requiresAuth: false) 不携带 Authorization 头
    func testUploadFileOmitsAuthHeaderWhenNotRequired() async throws {
        NetworkClientEdgeMockURLProtocol.responseBody = successResponse(payload: "url")
        NetworkClientEdgeMockURLProtocol.statusCode = 200

        _ = try await NetworkClient.shared.uploadFile(
            path: "/api/v1/upload",
            fileData: Data([0x00]),
            fileName: "test.png",
            mimeType: "image/png",
            requiresAuth: false
        )

        let auth = NetworkClientEdgeMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertNil(auth, "requiresAuth=false 时不应携带 Authorization 头")
    }

    /// 验证 POST + body + requiresAuth=false 组合不携带 auth 头
    func testPostRequestWithRequiresAuthFalseOmitsAuthHeader() async throws {
        struct Result: Codable { let id: Int }
        struct Body: Codable { let value: String }

        NetworkClientEdgeMockURLProtocol.responseBody = successResponse(payload: ["id": 1])
        NetworkClientEdgeMockURLProtocol.statusCode = 200

        let _: Result = try await NetworkClient.shared.request(
            path: "/api/v1/public",
            method: "POST",
            body: Body(value: "test"),
            requiresAuth: false
        )

        let auth = NetworkClientEdgeMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertNil(auth, "POST + requiresAuth=false 时不应携带 Authorization 头")
    }

    // MARK: - 40101 重试防死循环测试

    /// 验证重试时再次收到 40101 直接抛 serverError（防死循环）
    func testRetryOn40101DoesNotLoopInfinitely() async throws {
        struct Item: Codable { let name: String }
        try KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: "valid-refresh")

        // 第一次 40101 → 触发刷新 → 刷新成功 → 重试 → 再次 40101 → 应直接抛 serverError
        NetworkClientEdgeMockURLProtocol.responseSequence = [
            makeSequenceEntry(code: 40101, message: "token expired", data: NSNull()),
            makeRefreshSuccessEntry(accessToken: "new-jwt", refreshToken: "new-refresh"),
            makeSequenceEntry(code: 40101, message: "token still expired", data: NSNull())
        ]

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
            XCTFail("重试时再次 40101 应抛 serverError，不应死循环")
        } catch let NetworkError.serverError(code, _) {
            XCTAssertEqual(code, 40101, "重试时再次 40101 应抛 serverError(40101)")
        }
    }

    /// 验证 requiresAuth=false 请求收到 40101 直接抛 serverError（不触发刷新）
    func test40101OnNonAuthRequestThrowsServerError() async throws {
        struct Item: Codable { let name: String }

        NetworkClientEdgeMockURLProtocol.responseSequence = [
            makeSequenceEntry(code: 40101, message: "token expired", data: NSNull())
        ]

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/public", requiresAuth: false)
            XCTFail("requiresAuth=false 收到 40101 应抛 serverError")
        } catch let NetworkError.serverError(code, _) {
            XCTAssertEqual(code, 40101, "requiresAuth=false 收到 40101 应抛 serverError(40101)")
        }
    }

    // MARK: - Token 刷新边界测试

    /// 验证刷新接口 code==0 但 data 为 nil 时退登并抛 sessionInvalidated
    func testTokenRefreshFailsWhenResponseDataNil() async throws {
        struct Item: Codable { let name: String }
        try KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: "valid-refresh")

        // 第一次 40101 → 触发刷新 → 刷新接口 code==0 但 data 为 null
        NetworkClientEdgeMockURLProtocol.responseSequence = [
            makeSequenceEntry(code: 40101, message: "token expired", data: NSNull()),
            makeRefreshResponseWithNilData()
        ]

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
            XCTFail("刷新 data 为 nil 应抛 sessionInvalidated")
        } catch NetworkError.sessionInvalidated {
            // 预期：退登
        }
    }

    /// 验证刷新成功但新 refresh token 为 nil 时跳过存储 refresh token
    func testTokenRefreshSucceedsWithoutNewRefreshToken() async throws {
        struct Item: Codable, Equatable { let value: String }
        try KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: "old-refresh")

        // 第一次 40101 → 触发刷新 → 刷新成功但 refreshToken 为 nil → 重试成功
        NetworkClientEdgeMockURLProtocol.responseSequence = [
            makeSequenceEntry(code: 40101, message: "token expired", data: NSNull()),
            makeRefreshSuccessEntry(accessToken: "new-jwt", refreshToken: nil),
            makeSequenceEntry(code: 0, message: "ok", data: ["value": "refreshed"])
        ]

        let result: Item = try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
        XCTAssertEqual(result.value, "refreshed")

        // access token 应已更新
        let newAccess = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        XCTAssertEqual(newAccess, "new-jwt", "access token 应已更新")
    }

    // MARK: - 辅助方法

    private func makeSequenceEntry(code: Int, message: String, data: Any) -> (Data, Int) {
        let body: [String: Any] = [
            "code": code,
            "message": message,
            "data": data,
            "requestId": "req-\(UUID().uuidString.prefix(8))",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return (jsonData(from: body), 200)
    }

    private func makeRefreshSuccessEntry(accessToken: String, refreshToken: String?) -> (Data, Int) {
        var loginData: [String: Any] = ["accessToken": accessToken]
        if let rt = refreshToken {
            loginData["refreshToken"] = rt
        }
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": loginData,
            "requestId": "req-refresh",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return (jsonData(from: body), 200)
    }

    private func makeRefreshResponseWithNilData() -> (Data, Int) {
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": NSNull(),
            "requestId": "req-refresh-nil",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return (jsonData(from: body), 200)
    }
}

// MARK: - NetworkClient Edge Mock URLProtocol

final class NetworkClientEdgeMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: Data = Data()
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var responseSequence: [(Data, Int)] = []
    private static var sequenceIndex = 0

    static func reset() {
        responseBody = Data()
        statusCode = 200
        lastRequest = nil
        responseSequence = []
        sequenceIndex = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        NetworkClientEdgeMockURLProtocol.lastRequest = request

        var body: Data
        var status: Int
        if NetworkClientEdgeMockURLProtocol.sequenceIndex < NetworkClientEdgeMockURLProtocol.responseSequence.count {
            let entry = NetworkClientEdgeMockURLProtocol.responseSequence[NetworkClientEdgeMockURLProtocol.sequenceIndex]
            body = entry.0
            status = entry.1
            NetworkClientEdgeMockURLProtocol.sequenceIndex += 1
        } else {
            body = NetworkClientEdgeMockURLProtocol.responseBody
            status = NetworkClientEdgeMockURLProtocol.statusCode
        }

        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        if let response = response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
