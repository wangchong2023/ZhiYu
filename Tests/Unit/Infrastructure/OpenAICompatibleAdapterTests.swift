//
//  OpenAICompatibleAdapterTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 OpenAICompatibleAdapter.generate 的请求构造、响应解析与错误处理
//

import XCTest
@testable import ZhiYu

final class OpenAICompatibleAdapterTests: XCTestCase {

    private var config: LLMConfigStore!

    override func setUp() {
        super.setUp()
        config = LLMConfigStore()
        config.baseURL = "https://adapter.mock.local/v1"
        config.apiKey = "sk-test-key"
        config.model = "test-model"
        OpenAICompatibleAdapterMockURLProtocol.reset()
        URLProtocol.registerClass(OpenAICompatibleAdapterMockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(OpenAICompatibleAdapterMockURLProtocol.self)
        OpenAICompatibleAdapterMockURLProtocol.reset()
        config = nil
        super.tearDown()
    }

    // MARK: - generate 正常流程

    func testGenerateReturnsContentOnValidResponse() async throws {
        OpenAICompatibleAdapterMockURLProtocol.responseBody = """
        {"choices":[{"message":{"content":"Hello from LLM"}}]}
        """
        OpenAICompatibleAdapterMockURLProtocol.statusCode = 200

        let adapter = OpenAICompatibleAdapter(
            id: "test",
            displayName: "Test",
            config: config
        )

        let result = try await adapter.generate(prompt: "Hi", systemPrompt: "You are helpful")
        XCTAssertEqual(result, "Hello from LLM")
    }

    // MARK: - generate 错误流程

    func testGenerateThrowsInvalidResponseWhenNoChoices() async {
        OpenAICompatibleAdapterMockURLProtocol.responseBody = """
        {"error":"bad request"}
        """
        OpenAICompatibleAdapterMockURLProtocol.statusCode = 200

        let adapter = OpenAICompatibleAdapter(
            id: "test",
            displayName: "Test",
            config: config
        )

        do {
            _ = try await adapter.generate(prompt: "Hi", systemPrompt: "System")
            XCTFail("缺少 choices 应抛出 invalidResponse")
        } catch LLMError.invalidResponse {
            // 预期
        } catch {
            XCTFail("应抛出 LLMError.invalidResponse，实际：\(error)")
        }
    }

    func testGenerateThrowsInvalidResponseWhenNoMessageContent() async {
        OpenAICompatibleAdapterMockURLProtocol.responseBody = """
        {"choices":[{"message":{"role":"assistant"}}]}
        """
        OpenAICompatibleAdapterMockURLProtocol.statusCode = 200

        let adapter = OpenAICompatibleAdapter(
            id: "test",
            displayName: "Test",
            config: config
        )

        do {
            _ = try await adapter.generate(prompt: "Hi", systemPrompt: "System")
            XCTFail("缺少 content 应抛出 invalidResponse")
        } catch LLMError.invalidResponse {
            // 预期
        } catch {
            XCTFail("应抛出 LLMError.invalidResponse，实际：\(error)")
        }
    }
}

// MARK: - Mock URLProtocol

final class OpenAICompatibleAdapterMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: String = ""
    nonisolated(unsafe) static var statusCode: Int = 200

    nonisolated(unsafe) private static var requestCount = 0

    static func reset() {
        responseBody = ""
        statusCode = 200
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host.contains("adapter.mock.local")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Self.requestCount += 1
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        guard let httpResponse = response else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        let data = Data(Self.responseBody.utf8)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
