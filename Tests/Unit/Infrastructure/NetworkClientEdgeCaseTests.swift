//
//  NetworkClientEdgeCaseTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 NetworkClient 的边界分支：invalidURL、uploadFile 业务 code 非 0、requiresAuth=false 组合、40101 重试防死循环、并发刷新复用等。
//

import XCTest
import UFPCore
@testable import ZhiYu

// MARK: - NetworkClient 边界分支测试

final class NetworkClientEdgeCaseTests: XCTestCase {

    // MARK: - 测试夹具

    override func setUp() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        // 注册 KeyStoreProtocol 降级回退：模拟器无 Keychain entitlements 时，
        // store/retrieve 走 UserDefaults 缓存（errSecMissingEntitlement -34018 回退），
        // 否则 refreshToken 静默丢失导致测试误报 missingRefreshToken
        guard let testDefaults = UserDefaults(suiteName: "NetworkClientEdgeCaseTests-\(UUID().uuidString)") else {
            XCTFail("无法创建测试用 UserDefaults")
            return
        }
        ServiceContainer.shared.register(
            UserDefaultsKeyStore(defaults: testDefaults) as any KeyStoreProtocol,
            for: (any KeyStoreProtocol).self
        )
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

    // MARK: - uploadFile CRLF 注入防护（Bug #40）

    /// 验证 uploadFile 对含 CRLF 换行符的 fileName 直接拒绝，防止 HTTP header 注入
    func testUploadFile_rejectsCRLFInjection() async throws {
        let maliciousFileName = "test.txt\u{000D}\u{000A}X-Injected: evil"
        XCTAssertTrue(
            maliciousFileName.unicodeScalars.contains { $0.value == 13 || $0.value == 10 },
            "测试夹具应包含真实 CR/LF 字节"
        )

        do {
            _ = try await NetworkClient.shared.uploadFile(
                path: "/api/v1/upload",
                fileData: Data("hello".utf8),
                fileName: maliciousFileName,
                mimeType: "text/plain"
            )
            XCTFail("含 CRLF 的 fileName 应抛出 invalidFileName 而非发起请求")
        } catch NetworkError.invalidFileName {
            // 预期：CRLF 注入被拒绝
        }
    }

    // MARK: - 刷新接口自身解码失败（错误链兜底）

    /// 验证刷新接口返回无法解码的载荷时，错误链应传播失败而不崩溃、不死循环、不误判为成功
    func testTokenRefreshDecodeFailure_propagatesError() async throws {
        struct Item: Codable { let name: String }
        try KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: "valid-refresh")

        // 第一次 40101 → 触发刷新 → 刷新接口返回非法 JSON（解码失败）
        NetworkClientEdgeMockURLProtocol.responseSequence = [
            makeSequenceEntry(code: 40101, message: "token expired", data: NSNull()),
            (Data("not-a-valid-json".utf8), 200)
        ]

        do {
            let _: Item = try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
            XCTFail("刷新接口解码失败应抛出错误")
        } catch is DecodingError {
            // 预期：刷新接口解码失败应传播 DecodingError，而非误判成功/死循环
        } catch let error as NetworkError {
            XCTFail("刷新接口解码失败应抛 DecodingError，却抛 NetworkError: \(error)")
        } catch {
            XCTFail("刷新接口解码失败应抛 DecodingError，却抛其他错误: \(error)")
        }
    }

    // MARK: - 并发刷新复用测试

    /// 验证刷新进行中，第二个请求复用同一 refreshTask 而非重复触发刷新
    func testConcurrentRequestReusesInFlightRefresh() async throws {
        struct Item: Codable, Equatable { let value: String }
        try KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: "valid-refresh")

        let refreshStarted = DispatchSemaphore(value: 0)
        let refreshRelease = DispatchSemaphore(value: 0)
        ConcurrentRefreshMockURLProtocol.resetState()
        ConcurrentRefreshMockURLProtocol.refreshStarted = refreshStarted
        ConcurrentRefreshMockURLProtocol.refreshRelease = refreshRelease
        ConcurrentRefreshMockURLProtocol.newAccessToken = "new-jwt"

        await NetworkClient.shared.setTestSession(makeConcurrentSession())

        // 请求 A：触发刷新（刷新请求阻塞在 refreshRelease 上，模拟慢刷新）
        let taskA = Task { () -> Item in
            try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
        }

        // 等待刷新请求真正开始（此时 isRefreshing=true、refreshTask 已赋值）
        XCTAssertEqual(
            refreshStarted.wait(timeout: .now() + 5),
            .success,
            "刷新请求应已开始"
        )

        // 请求 B：刷新进行中到达，应走 waitForTokenRefreshIfNeeded 等待同一 refreshTask
        let taskB = Task { () -> Item in
            try await NetworkClient.shared.request(path: "/api/v1/protected", requiresAuth: true)
        }

        // 稍等让 B 进入并发等待路径，再放行刷新
        try await Task.sleep(nanoseconds: 300_000_000)
        refreshRelease.signal()

        let valueA = try await taskA.value
        let valueB = try await taskB.value
        XCTAssertEqual(valueA.value, "ok", "请求 A 应刷新后重试成功")
        XCTAssertEqual(valueB.value, "ok", "请求 B 应复用刷新后成功")

        // 核心断言：刷新接口只被调用一次（B 复用 A 的刷新，未重复触发）
        XCTAssertEqual(
            ConcurrentRefreshMockURLProtocol.refreshCallCount,
            1,
            "并发刷新应只触发一次，而非每个请求各自刷新"
        )
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

    private func makeConcurrentSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [ConcurrentRefreshMockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - NetworkClient Edge Mock URLProtocol

final class NetworkClientEdgeMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: Data = Data()
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var responseSequence: [(Data, Int)] = []
    nonisolated(unsafe) private static var sequenceIndex = 0

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

// MARK: - NetworkClient 并发刷新 Mock URLProtocol
//
// path-aware mock：refresh 请求可被信号量挂起，用于验证刷新进行中第二个请求
// 复用同一 refreshTask（不重复触发刷新）。非 refresh 请求：携带新 access token
// （即刷新后的重试）返回成功，否则返回 40101 触发刷新。

final class ConcurrentRefreshMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var refreshStarted: DispatchSemaphore?
    nonisolated(unsafe) static var refreshRelease: DispatchSemaphore?
    nonisolated(unsafe) static var newAccessToken: String = "new-jwt"
    nonisolated(unsafe) static var refreshCallCount = 0

    static func resetState() {
        refreshStarted = nil
        refreshRelease = nil
        newAccessToken = "new-jwt"
        refreshCallCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        if url.absoluteString.contains("subscriber/refresh") {
            // 刷新请求：计数 + 通知已开始 + 阻塞直到测试放行（超时兜底防死锁）
            Self.refreshCallCount += 1
            Self.refreshStarted?.signal()
            _ = Self.refreshRelease?.wait(timeout: .now() + 5)
            let body = Self.jsonBody(code: 0, data: ["accessToken": Self.newAccessToken, "refreshToken": "new-refresh"])
            Self.respond(self, url: url, body: body, status: 200)
            return
        }

        // 非刷新请求：携带新 access token（刷新后的重试）→ 成功；否则 → 40101 触发刷新
        let auth = request.value(forHTTPHeaderField: "Authorization")
        if let auth, auth.contains(Self.newAccessToken) {
            let body = Self.jsonBody(code: 0, data: ["value": "ok"])
            Self.respond(self, url: url, body: body, status: 200)
        } else {
            let body = Self.jsonBody(code: 40101, message: "token expired", data: NSNull())
            Self.respond(self, url: url, body: body, status: 200)
        }
    }

    private static func jsonBody(code: Int, message: String = "ok", data: Any) -> Data {
        let dict: [String: Any] = [
            "code": code,
            "message": message,
            "data": data,
            "requestId": "req-\(UUID().uuidString.prefix(8))",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    private static func respond(_ protocolSelf: URLProtocol, url: URL, body: Data, status: Int) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        if let response = response {
            protocolSelf.client?.urlProtocol(protocolSelf, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        protocolSelf.client?.urlProtocol(protocolSelf, didLoad: body)
        protocolSelf.client?.urlProtocolDidFinishLoading(protocolSelf)
    }

    override func stopLoading() {}
}
