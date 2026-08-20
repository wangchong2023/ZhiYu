//
//  NetworkClientTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 NetworkClient actor 的请求构造、响应解码、Token 刷新、文件上传等核心逻辑。
//

import XCTest
@testable import ZhiYu

// MARK: - NetworkClient 单元测试

final class NetworkClientCoverageTests: XCTestCase {

    // MARK: - 测试夹具

    override func setUp() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        // 清理 Keychain 残留
        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
        try? KeychainService.shared.delete(key: "refresh_token")
    }

    override func tearDown() async throws {
        await NetworkClient.shared.setTestSession(nil)
        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
        try? KeychainService.shared.delete(key: "refresh_token")
        NetworkClientMockURLProtocol.reset()
    }

    /// 构造拦截所有请求的 URLSession
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [NetworkClientMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// 构造标准成功响应 JSON
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

    /// 构造业务错误响应 JSON
    private func errorResponse(code: Int, message: String) -> Data {
        let body: [String: Any] = [
            "code": code,
            "message": message,
            "data": NSNull(),
            "requestId": "req-456",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return jsonData(from: body)
    }

    /// 安全序列化 JSON 字典
    private func jsonData(from dict: [String: Any]) -> Data {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else {
            return Data()
        }
        return data
    }

    // MARK: - GET 请求测试

    func testGetRequestDecodesSuccessResponse() async throws {
        struct Item: Codable, Equatable { let name: String }
        NetworkClientMockURLProtocol.responseBody = successResponse(payload: ["name": "hello"])
        NetworkClientMockURLProtocol.statusCode = 200

        let result: Item = try await NetworkClient.shared.request(path: "/api/v1/test")
        XCTAssertEqual(result.name, "hello")
    }

    func testGetRequestThrowsServerErrorOnNonZeroCode() async throws {
        struct Item: Codable { let name: String }
        NetworkClientMockURLProtocol.responseBody = errorResponse(code: 500, message: "internal error")
        NetworkClientMockURLProtocol.statusCode = 200

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/test")
            XCTFail("应抛出 serverError")
        } catch let NetworkError.serverError(code, msg) {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(msg, "internal error")
        }
    }

    func testGetRequestThrowsDecodeFailedOnInvalidJSON() async throws {
        struct Item: Codable { let name: String }
        NetworkClientMockURLProtocol.responseBody = Data("not json".utf8)
        NetworkClientMockURLProtocol.statusCode = 200

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/test")
            XCTFail("应抛出 decodeFailed")
        } catch NetworkError.decodeFailed {
            // 预期
        }
    }

    // MARK: - POST 请求测试

    func testPostRequestSendsBodyAndDecodesResponse() async throws {
        struct Result: Codable, Equatable { let id: Int }
        struct Body: Codable, Equatable { let value: String }

        NetworkClientMockURLProtocol.responseBody = successResponse(payload: ["id": 42])
        NetworkClientMockURLProtocol.statusCode = 200

        let result: Result = try await NetworkClient.shared.request(
            path: "/api/v1/create",
            method: "POST",
            body: Body(value: "test")
        )
        XCTAssertEqual(result.id, 42)

        // 验证请求体被发送
        let sentBody = NetworkClientMockURLProtocol.lastRequestBody
        XCTAssertNotNil(sentBody)
        guard let bodyData = sentBody else { return }
        let decoded = try JSONDecoder().decode(Body.self, from: bodyData)
        XCTAssertEqual(decoded, Body(value: "test"))
    }

    // MARK: - Auth Token 注入测试

    func testRequestInjectsBearerTokenWhenRequiresAuth() async throws {
        struct Item: Codable { let name: String }
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "test-jwt-token")

        NetworkClientMockURLProtocol.responseBody = successResponse(payload: ["name": "ok"])
        NetworkClientMockURLProtocol.statusCode = 200

        let _: Item = try await NetworkClient.shared.request(path: "/api/v1/secure", requiresAuth: true)

        let auth = NetworkClientMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(auth, "Bearer test-jwt-token")
    }

    func testRequestOmitsAuthorizationHeaderWhenNotRequired() async throws {
        struct Item: Codable { let name: String }
        NetworkClientMockURLProtocol.responseBody = successResponse(payload: ["name": "ok"])
        NetworkClientMockURLProtocol.statusCode = 200

        let _: Item = try await NetworkClient.shared.request(path: "/api/v1/public", requiresAuth: false)

        let auth = NetworkClientMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertNil(auth)
    }

    // MARK: - EmptyData 占位测试

    func testEmptyDataRequestSucceedsWithNullPayload() async throws {
        // data 为 null 时，ApiResponse<EmptyData> 解码，data 字段为 nil，extractPayload 返回 EmptyData()
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": NSNull(),
            "requestId": "req-empty",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        NetworkClientMockURLProtocol.responseBody = jsonData(from: body)
        NetworkClientMockURLProtocol.statusCode = 200

        let result: EmptyData = try await NetworkClient.shared.request(path: "/api/v1/noop", method: "POST")
        XCTAssertNotNil(result)
    }

    // MARK: - Payload 缺失测试

    func testRequestThrowsUnexpectedWhenPayloadMissing() async throws {
        struct Item: Codable, Equatable { let name: String }
        NetworkClientMockURLProtocol.responseBody = errorResponse(code: 0, message: "ok")
        // data 为 null，但 T 不是 EmptyData
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": NSNull(),
            "requestId": "req-789",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        NetworkClientMockURLProtocol.responseBody = jsonData(from: body)
        NetworkClientMockURLProtocol.statusCode = 200

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/test")
            XCTFail("应抛出 missingDataPayload")
        } catch NetworkError.missingDataPayload {
            // 预期：payload 缺失
        }
    }

    // MARK: - 非 HTTPURLResponse 响应测试

    func testRequestThrowsUnexpectedOnNonHTTPResponse() async throws {
        struct Item: Codable { let name: String }
        NetworkClientMockURLProtocol.responseBody = Data()
        NetworkClientMockURLProtocol.statusCode = 200
        NetworkClientMockURLProtocol.returnNonHTTPResponse = true

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/test")
            XCTFail("应抛出 invalidHTTPResponse")
        } catch NetworkError.invalidHTTPResponse {
            // 预期
        }
        NetworkClientMockURLProtocol.returnNonHTTPResponse = false
    }

    // MARK: - 文件上传测试

    func testUploadFileReturnsPayloadString() async throws {
        NetworkClientMockURLProtocol.responseBody = successResponse(payload: "https://cdn.example.com/file.png")
        NetworkClientMockURLProtocol.statusCode = 200

        let result = try await NetworkClient.shared.uploadFile(
            path: "/api/v1/upload",
            fileData: Data([0x89, 0x50, 0x4E, 0x47]),
            fileName: "test.png",
            mimeType: "image/png"
        )
        XCTAssertEqual(result, "https://cdn.example.com/file.png")
    }

    func testUploadFileThrowsOnNon200Status() async throws {
        NetworkClientMockURLProtocol.responseBody = Data()
        NetworkClientMockURLProtocol.statusCode = 500

        do {
            _ = try await NetworkClient.shared.uploadFile(
                path: "/api/v1/upload",
                fileData: Data([0x00]),
                fileName: "test.png",
                mimeType: "image/png"
            )
            XCTFail("应抛出错误")
        } catch {
            // 预期：非 200 状态码
        }
    }

    func testUploadFileInjectsBearerToken() async throws {
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "upload-token")
        NetworkClientMockURLProtocol.responseBody = successResponse(payload: "url")
        NetworkClientMockURLProtocol.statusCode = 200

        _ = try await NetworkClient.shared.uploadFile(
            path: "/api/v1/upload",
            fileData: Data([0x00]),
            fileName: "test.png",
            mimeType: "image/png",
            requiresAuth: true
        )

        let auth = NetworkClientMockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(auth, "Bearer upload-token")
    }

    // MARK: - Token 刷新重试测试

    func testTokenRefreshAndRetrySucceeds() async throws {
        struct Item: Codable, Equatable { let value: String }

        // 存入 refresh_token
        try KeychainService.shared.store(key: "refresh_token", value: "valid-refresh-token")

        // 第一次返回 40101（token 过期），刷新后重试返回成功
        NetworkClientMockURLProtocol.responseSequence = [
            makeSequenceEntry(code: 40101, message: "token expired", data: NSNull()),
            makeRefreshSuccessEntry(accessToken: "new-jwt", refreshToken: "new-refresh"),
            makeSequenceEntry(code: 0, message: "ok", data: ["value": "refreshed"])
        ]

        let result: Item = try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
        XCTAssertEqual(result.value, "refreshed")

        // 验证 Keychain 已更新
        let newToken = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        XCTAssertEqual(newToken, "new-jwt")
    }

    func testTokenRefreshFailsWhenNoRefreshToken() async throws {
        struct Item: Codable { let name: String }

        // 不存 refresh_token
        NetworkClientMockURLProtocol.responseSequence = [
            makeSequenceEntry(code: 40101, message: "token expired", data: NSNull())
        ]

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
            XCTFail("应抛出 missingRefreshToken")
        } catch NetworkError.missingRefreshToken {
            // 预期：无 refresh_token
        }
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

    private func makeRefreshSuccessEntry(accessToken: String, refreshToken: String) -> (Data, Int) {
        let loginData: [String: Any] = [
            "accessToken": accessToken,
            "refreshToken": refreshToken
        ]
        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": loginData,
            "requestId": "req-refresh",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return (jsonData(from: body), 200)
    }
}

// MARK: - NetworkClient Mock URLProtocol

final class NetworkClientMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: Data = Data()
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastRequestBody: Data?
    nonisolated(unsafe) static var returnNonHTTPResponse = false
    /// 响应序列：按顺序返回不同的 (body, status)。用完后回退到 responseBody。
    nonisolated(unsafe) static var responseSequence: [(Data, Int)] = []
    private static var sequenceIndex = 0

    static func reset() {
        responseBody = Data()
        statusCode = 200
        lastRequest = nil
        lastRequestBody = nil
        returnNonHTTPResponse = false
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
        NetworkClientMockURLProtocol.lastRequest = request

        // 读取请求体
        if let bodyStream = request.httpBodyStream {
            bodyStream.open()
            let bufferSize = 1024
            var data = Data()
            while bodyStream.hasBytesAvailable {
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                let bytesRead = bodyStream.read(&buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    data.append(buffer, count: bytesRead)
                } else {
                    break
                }
            }
            bodyStream.close()
            NetworkClientMockURLProtocol.lastRequestBody = data
        } else {
            NetworkClientMockURLProtocol.lastRequestBody = request.httpBody
        }

        // 选择响应
        var body: Data
        var status: Int
        if NetworkClientMockURLProtocol.sequenceIndex < NetworkClientMockURLProtocol.responseSequence.count {
            let entry = NetworkClientMockURLProtocol.responseSequence[NetworkClientMockURLProtocol.sequenceIndex]
            body = entry.0
            status = entry.1
            NetworkClientMockURLProtocol.sequenceIndex += 1
        } else {
            body = NetworkClientMockURLProtocol.responseBody
            status = NetworkClientMockURLProtocol.statusCode
        }

        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        if NetworkClientMockURLProtocol.returnNonHTTPResponse {
            // 返回非 HTTPURLResponse（用 URLResponse 而非 HTTPURLResponse）
            client?.urlProtocol(self, didReceive: URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), cacheStoragePolicy: .notAllowed)
        } else {
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else {
                client?.urlProtocolDidFinishLoading(self)
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
