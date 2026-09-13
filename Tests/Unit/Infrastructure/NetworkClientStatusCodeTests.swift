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
@testable import ZhiYu

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

    static func reset() {
        responseBody = Data()
        statusCode = 200
        lastRequest = nil
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

        let response = HTTPURLResponse(
            url: url,
            statusCode: NetworkMockURLProtocol.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        if let response = response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: NetworkMockURLProtocol.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
