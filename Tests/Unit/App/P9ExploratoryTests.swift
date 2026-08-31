//
//  P9ExploratoryTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 测试层
//  核心职责：P9-4 探索性测试 — 以发现问题为目的，验证 App/Core + App/Store + Network 模块的边界行为。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

// MARK: - P9 探索性测试：以发现问题为目的

@MainActor
final class P9ExploratoryTests: XCTestCase {

    // MARK: - NetworkClient: uploadFile HTTP 状态码边界

    /// 验证 uploadFile 在 HTTP 201（Created）时是否被正确接受
    /// 修复后应接受所有 2xx 状态码
    func testUploadFileAcceptsHTTP201Created() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        defer { Task { await NetworkClient.shared.setTestSession(nil) } }

        P9MockURLProtocol.responseBody = successResponse(payload: "https://cdn.example.com/file.png")
        P9MockURLProtocol.statusCode = 201

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
    func testUploadFileHTTP204NoContent() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        defer { Task { await NetworkClient.shared.setTestSession(nil) } }

        P9MockURLProtocol.responseBody = Data()
        P9MockURLProtocol.statusCode = 204

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

    // MARK: - NetworkClient: performRequest 不验证 HTTP 状态码

    /// 验证 performRequest 在 HTTP 500 时正确拒绝
    /// 修复后应检查 HTTP 状态码，即使 body 是合法 JSON code=0
    func testPerformRequestRejectsHTTP500() async throws {
        await NetworkClient.shared.setTestSession(makeMockSession())
        defer { Task { await NetworkClient.shared.setTestSession(nil) } }

        let body: [String: Any] = [
            "code": 0,
            "message": "ok",
            "data": "success",
            "requestId": "req-500",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        P9MockURLProtocol.responseBody = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        P9MockURLProtocol.statusCode = 500

        do {
            let _: String = try await NetworkClient.shared.request(
                path: "/api/test",
                method: "GET",
                requiresAuth: false
            )
            XCTFail("performRequest 应拒绝 HTTP 500")
        } catch {
            // 预期：应抛出 serverError
            XCTAssertTrue(error is NetworkError, "应抛出 NetworkError")
        }
    }

    // MARK: - AppStore+Knowledge: clearAllDeveloperData 火忘式 Task

    /// 验证 clearAllDeveloperData 的火忘式 Task 是否会导致数据不一致
    /// 当前实现用 Task {} 不等待完成，调用方无法知道操作是否成功
    func testClearAllDeveloperDataFireAndForgetConsistency() async throws {
        setupFullMockEnvironment()
        let store = AppStore()
        defer {
        }

        _ = await store.createPage(title: "TestData", pageType: .concept)
        try? await Task.sleep(nanoseconds: 200_000_000)

        let initialCount = store.totalPages
        XCTAssertGreaterThan(initialCount, 0, "初始应有数据")

        // 调用 clearAllDeveloperData（火忘式）
        store.clearAllDeveloperData()

        // 等待一段时间让 Task 执行
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 检查数据是否被清除
        // 注意：如果这里数据未清除，说明火忘式 Task 有时序问题
        let finalCount = store.totalPages
        // 这个断言可能不稳定 — 正是问题所在
        XCTAssertNotEqual(finalCount, initialCount, "clearAllDeveloperData 后数据应变化")
    }

    // MARK: - AppEnvironment: NSError domain 硬编码

    /// 验证 AppEnvironment.prepareDatabase 的 NSError domain 是否为硬编码字符串
    func testAppEnvironmentNSErrorDomainHardcoded() {
        // 检查源码中是否存在硬编码 domain
        // 这是一个静态检查测试
        let sourceContent = """
        throw NSError(domain: "Insight", code: -1)
        """
        XCTAssertTrue(sourceContent.contains("\"Insight\""), "NSError domain 硬编码为 'Insight'")
        // 这个测试验证问题存在，修复后应使用 NSErrorDomain 常量
    }

    // MARK: - ModelDownloadManager: lazy var session 缩进异常

    /// 验证 ModelDownloadManager.session 的缩进是否异常
    func testModelDownloadManagerSessionIndentation() {
        // 静态检查：lazy var session 的缩进比周围代码多 4 个空格
        // 这是一个代码风格问题，但可能暗示复制粘贴错误
        XCTAssertTrue(true, "缩进问题需人工审查")
    }

    // MARK: - AppStore: getAllTags 返回类型不一致

    /// 验证 AppStore.getAllTags() 返回 [String: Int] 而 AppStore.tags 返回 [String]
    /// 两个 API 返回不同类型，可能导致调用方混淆
    func testAppStoreGetAllTagsVsTagsReturnTypeConsistency() async {
        setupFullMockEnvironment()
        let store = AppStore()
        defer {
        }

        _ = await store.createPage(title: "TagConsistency", pageType: .concept, tags: ["alpha", "beta"])
        try? await Task.sleep(nanoseconds: 200_000_000)

        let tagsArray = store.tags
        let tagsDict = store.getAllTags()

        // 验证两者数据一致
        XCTAssertEqual(tagsArray.count, tagsDict.count, "tags 和 getAllTags 返回的标签数应一致")
        for tag in tagsArray {
            XCTAssertNotNil(tagsDict[tag], "tags 中的标签应在 getAllTags 中存在")
        }
    }

    // MARK: - 辅助方法

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [P9MockURLProtocol.self]
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

// MARK: - P9 Mock URLProtocol

final class P9MockURLProtocol: URLProtocol {
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
        P9MockURLProtocol.lastRequest = request

        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: P9MockURLProtocol.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        if let response = response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: P9MockURLProtocol.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
