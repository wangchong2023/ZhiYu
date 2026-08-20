//
//  NetworkClientTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 NetworkClient 开展无感刷新与 Token 过期踢出重试机制的自动化单元测试。
//

import XCTest
@testable import ZhiYu

@MainActor
final class NetworkClientTests: XCTestCase {
    
    private var testSession: URLSession!

    override func setUp() async throws {
        try await super.setUp()
        // 注入 Mock Keychain，绕过模拟器 errSecMissingEntitlement -34018 限制
        KeychainService.testOverride = MockKeychainService()
        // 注入 TestMockURLProtocol 测试 Session
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestMockURLProtocol.self]
        testSession = URLSession(configuration: config)
        await NetworkClient.shared.setTestSession(testSession)

        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
        try? KeychainService.shared.delete(key: "refresh_token")
    }

    override func tearDown() async throws {
        await NetworkClient.shared.setTestSession(nil)
        TestMockURLProtocol.requestHandler = nil
        try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
        try? KeychainService.shared.delete(key: "refresh_token")
        KeychainService.testOverride = nil
        try await super.tearDown()
    }

    func testNetworkClientBasicRequest() async throws {
        XCTAssertNotNil(NetworkClient.shared)
        
        let req = GuestLoginRequest(deviceId: "test-device")
        XCTAssertEqual(req.deviceId, "test-device")
    }
    
    func testTokenStorage() throws {
        // Mock Keychain 已由 setUp 注入，模拟器环境安全
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "fake_jwt")
        let token = try KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        XCTAssertEqual(token, "fake_jwt")
    }

    // MARK: - 无感刷新与失效退登测试

    /// 测试：当 Access Token 过期 (401) 时，NetworkClient 能自动通过 refresh_token 触发无感刷新，并自动携带新 Token 重试原请求
    func testTokenRefreshSuccess() async throws {
        // 1. 初始化写入旧 token（Mock Keychain 已由 setUp 注入，模拟器环境安全）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "expired_access_token")
        try KeychainService.shared.store(key: "refresh_token", value: "valid_refresh_token")

        // 2. 编写拦截器，处理三次网络交互：
        //   - 交互A：第一次请求主 API，携带 expired_access_token -> 返回 40101 Code
        //   - 交互B：自动触发 /api/v1/auth/refresh 刷新，携带 valid_refresh_token -> 返回 200 (包含新 Token "new_access_token")
        //   - 交互C：第二次重试主 API，携带 new_access_token -> 返回 200 (成功数据)
        var callCount = 0
        TestMockURLProtocol.requestHandler = { request in
            callCount += 1
            let url = try XCTUnwrap(request.url)
            if url.path == "/api/v1/auth/refresh" {
                XCTAssertEqual(request.httpMethod, "POST")
                if let bodyData = request.httpBodyStreamData() ?? request.httpBody,
                   let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                   let token = json["refreshToken"] as? String {
                    XCTAssertEqual(token, "valid_refresh_token")
                }
                
                let responseDTO = LoginResponse(
                    accessToken: "new_access_token",
                    refreshToken: "new_refresh_token",
                    expiresIn: 3600,
                    tokenType: "Bearer",
                    isNewUser: false,
                    totpRequired: false
                )
                let apiResponse = ApiResponse(code: 0, message: "success", data: responseDTO, requestId: "test_req_id", timestamp: 123456789)
                let data = try JSONEncoder().encode(apiResponse)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
                return (response, data)
            } else if url.path == "/api/v1/test/resource" {
                if callCount == 1 {
                    XCTAssertEqual(request.value(forHTTPHeaderField: AppConstants.Network.headerAuthorization), "Bearer expired_access_token")
                    let apiResponse: ApiResponse<String> = ApiResponse(code: 40101, message: "Token Expired", data: nil, requestId: "test_req_id", timestamp: 123456789)
                    let data = try JSONEncoder().encode(apiResponse)
                    let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
                    return (response, data)
                } else {
                    XCTAssertEqual(request.value(forHTTPHeaderField: AppConstants.Network.headerAuthorization), "Bearer new_access_token")
                    let apiResponse = ApiResponse(code: 0, message: "success", data: "test_data_payload", requestId: "test_req_id", timestamp: 123456789)
                    let data = try JSONEncoder().encode(apiResponse)
                    let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
                    return (response, data)
                }
            }
            
            XCTFail("非预期的网络请求: \(url.absoluteString)")
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        // 3. 执行请求
        let payload: String = try await NetworkClient.shared.request(
            path: "/api/v1/test/resource",
            method: "GET",
            requiresAuth: true
        )

        // 4. 验证
        XCTAssertEqual(payload, "test_data_payload", "无感刷新重试后，应返回正确响应")
        XCTAssertEqual(callCount, 3, "共应发生 3 次 HTTP 交互：请求A(401) -> 刷新B(200) -> 重试C(200)")
        
        let savedAccess = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        let savedRefresh = try? KeychainService.shared.retrieve(key: "refresh_token")
        XCTAssertEqual(savedAccess, "new_access_token", "Keychain 中的 Access Token 应被成功更新")
        XCTAssertEqual(savedRefresh, "new_refresh_token", "Keychain 中的 Refresh Token 应被成功更新")
    }

    /// 测试：当 Access Token 过期 (401) 且 Refresh Token 也失效时，NetworkClient 能自动清空 Keychain 物理凭证，并发出全局强制退登广播
    func testTokenRefreshFailureAndLogoutBroadcast() async throws {
        // 1. 初始化写入旧 token（Mock Keychain 已由 setUp 注入，模拟器环境安全）
        try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: "expired_access_token")
        try KeychainService.shared.store(key: "refresh_token", value: "expired_refresh_token")

        // 2. 模拟广播拦截
        let expectation = XCTestExpectation(description: "必须向全局广播 .userAuthExpired 踢人通知")
        let observer = NotificationCenter.default.addObserver(
            forName: .userAuthExpired,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // 3. 拦截请求：
        //   - 交互A：第一次请求主 API，返回 40101 Code
        //   - 交互B：自动触发 /api/v1/auth/refresh 刷新 -> 返回 401 失败或 Code == 40103
        TestMockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == "/api/v1/auth/refresh" {
                let apiResponse: ApiResponse<LoginResponse> = ApiResponse(code: 40103, message: "Refresh Token Expired", data: nil, requestId: "test_req_id", timestamp: 123456789)
                let data = try JSONEncoder().encode(apiResponse)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
                return (response, data)
            } else if url.path == "/api/v1/test/resource" {
                let apiResponse: ApiResponse<String> = ApiResponse(code: 40101, message: "Token Expired", data: nil, requestId: "test_req_id", timestamp: 123456789)
                let data = try JSONEncoder().encode(apiResponse)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
                return (response, data)
            }
            
            XCTFail("非预期的网络请求: \(url.absoluteString)")
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil))
            return (response, nil)
        }

        // 4. 执行请求并期望抛出会话失效错误
        do {
            let _: String = try await NetworkClient.shared.request(
                path: "/api/v1/test/resource",
                method: "GET",
                requiresAuth: true
            )
            XCTFail("刷新失败应抛出 sessionInvalidated 异常，不应执行成功")
        } catch NetworkError.sessionInvalidated {
            // 预期错误
        } catch {
            XCTFail("抛出了非预期的错误: \(error)")
        }

        // 5. 等待广播完成，并移除监听
        await fulfillment(of: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)

        // 6. 验证 Keychain 被物理擦除以防残留会话
        let savedAccess = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)
        let savedRefresh = try? KeychainService.shared.retrieve(key: "refresh_token")
        XCTAssertNil(savedAccess, "登出后 Access Token 必须被物理清除")
        XCTAssertNil(savedRefresh, "登出后 Refresh Token 必须被物理清除")
    }
}

// MARK: - URLRequest 扩展辅助测试
fileprivate extension URLRequest {
    /// 单元测试专用：读取 httpBodyStream 中的二进制流数据，解决 URLSession 发送时 body 格式化为流导致 httpBody 为空的问题
    func httpBodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
