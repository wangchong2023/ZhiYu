//
//  LLMAdaptersChatStreamTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 OpenAICompatibleAdapter.chatStream 流式响应解析、SSEParser 静态方法、OllamaAdapter 行为
//

import XCTest
@testable import ZhiYu

final class LLMAdaptersChatStreamTests: XCTestCase {

    private var config: LLMConfigStore!

    override func setUp() {
        super.setUp()
        config = LLMConfigStore()
        config.baseURL = "https://sse.mock.local/v1"
        config.apiKey = "sk-stream-key"
        config.model = "stream-model"
        SSEStreamMockURLProtocol.reset()
        URLProtocol.registerClass(SSEStreamMockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(SSEStreamMockURLProtocol.self)
        SSEStreamMockURLProtocol.reset()
        config = nil
        super.tearDown()
    }

    // MARK: - SSEParser 静态方法

    func testExtractDataStringWithSpacePrefix() {
        let result = SSEParser.extractDataString(from: "data: {\"key\":\"value\"}")
        XCTAssertEqual(result, "{\"key\":\"value\"}")
    }

    func testExtractDataStringWithoutSpacePrefix() {
        let result = SSEParser.extractDataString(from: "data:{\"key\":\"value\"}")
        XCTAssertEqual(result, "{\"key\":\"value\"}")
    }

    func testExtractDataStringReturnsNilForNonDataLine() {
        XCTAssertNil(SSEParser.extractDataString(from: ": comment"))
        XCTAssertNil(SSEParser.extractDataString(from: "event: message"))
        XCTAssertNil(SSEParser.extractDataString(from: ""))
    }

    func testParseJSONLineReturnsNilForNonJSON() {
        XCTAssertNil(SSEParser.parseJSONLine("not json", logger: nil))
        XCTAssertNil(SSEParser.parseJSONLine("", logger: nil))
    }

    func testParseJSONLineReturnsDictForValidJSON() {
        let result = SSEParser.parseJSONLine("{\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}", logger: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["choices"] != nil, true)
    }

    func testExtractContentFromDelta() {
        let json: [String: Any] = ["choices": [["delta": ["content": "hello"]]]]
        XCTAssertEqual(SSEParser.extractContent(from: json), "hello")
    }

    func testExtractContentFromDeltaReasoningContent() {
        let json: [String: Any] = ["choices": [["delta": ["reasoning_content": "thinking"]]]]
        XCTAssertEqual(SSEParser.extractContent(from: json), "thinking")
    }

    func testExtractContentFromMessage() {
        let json: [String: Any] = ["choices": [["message": ["content": "response"]]]]
        XCTAssertEqual(SSEParser.extractContent(from: json), "response")
    }

    func testExtractContentReturnsNilForEmptyChoices() {
        let json: [String: Any] = ["choices": []]
        XCTAssertNil(SSEParser.extractContent(from: json))
    }

    func testExtractContentReturnsNilForEmptyContent() {
        let json: [String: Any] = ["choices": [["delta": ["content": ""]]]]
        XCTAssertNil(SSEParser.extractContent(from: json))
    }

    func testExtractContentReturnsNilForNoChoices() {
        let json: [String: Any] = ["error": "bad"]
        XCTAssertNil(SSEParser.extractContent(from: json))
    }

    // MARK: - OpenAICompatibleAdapter.chatStream

    func testChatStreamYieldsContentChunks() async throws {
        SSEStreamMockURLProtocol.responseBody = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}

        data: {"choices":[{"delta":{"content":" world"}}]}

        data: [DONE]

        """
        SSEStreamMockURLProtocol.statusCode = 200

        let adapter = OpenAICompatibleAdapter(
            id: "stream",
            displayName: "Stream",
            config: config
        )

        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hi"]
        ]

        var chunks: [String] = []
        do {
            for try await chunk in adapter.chatStream(messages: messages) {
                chunks.append(chunk)
            }
        } catch {
            XCTFail("chatStream 不应抛出错误：\(error)")
        }

        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0], "Hello")
        XCTAssertEqual(chunks[1], " world")
    }

    func testChatStreamFinishesOnDoneMarker() async throws {
        SSEStreamMockURLProtocol.responseBody = """
        data: {"choices":[{"delta":{"content":"A"}}]}

        data: [DONE]

        data: {"choices":[{"delta":{"content":"B"}}]}

        """
        SSEStreamMockURLProtocol.statusCode = 200

        let adapter = OpenAICompatibleAdapter(
            id: "stream",
            displayName: "Stream",
            config: config
        )

        var chunks: [String] = []
        for try await chunk in adapter.chatStream(messages: []) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["A"])
    }

    func testChatStreamSkipsNonDataLines() async throws {
        SSEStreamMockURLProtocol.responseBody = """
        : keepalive

        event: message

        data: {"choices":[{"delta":{"content":"X"}}]}

        data: [DONE]

        """
        SSEStreamMockURLProtocol.statusCode = 200

        let adapter = OpenAICompatibleAdapter(
            id: "stream",
            displayName: "Stream",
            config: config
        )

        var chunks: [String] = []
        for try await chunk in adapter.chatStream(messages: []) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["X"])
    }

    func testChatStreamThrowsOnHttpError() async {
        SSEStreamMockURLProtocol.responseBody = ""
        SSEStreamMockURLProtocol.statusCode = 500

        let adapter = OpenAICompatibleAdapter(
            id: "stream",
            displayName: "Stream",
            config: config
        )

        do {
            for try await _ in adapter.chatStream(messages: []) {}
            XCTFail("HTTP 500 应抛出错误")
        } catch {
            // 预期
        }
    }

    // MARK: - OllamaAdapter

    func testOllamaAdapterGenerateReturnsPlaceholder() async throws {
        let adapter = OllamaAdapter(model: "llama3", baseURL: "http://localhost:11434")
        let result = try await adapter.generate(prompt: "Hi", systemPrompt: "System")
        XCTAssertEqual(result, "Ollama Result")
    }

    func testOllamaAdapterChatStreamCompletesImmediately() async throws {
        let adapter = OllamaAdapter(model: "llama3", baseURL: "http://localhost:11434")
        var chunks: [String] = []
        let collectTask = Task {
            for try await chunk in adapter.chatStream(messages: []) {
                chunks.append(chunk)
            }
        }
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            collectTask.cancel()
        }
        try await collectTask.value
        timeoutTask.cancel()
        XCTAssertTrue(chunks.isEmpty)
    }

    func testOllamaAdapterHasFixedId() {
        let adapter = OllamaAdapter(model: "llama3", baseURL: "http://localhost:11434")
        XCTAssertEqual(adapter.id, "ollama")
        XCTAssertEqual(adapter.displayName, "Ollama (Local)")
    }
}

// MARK: - SSE Stream Mock URLProtocol

final class SSEStreamMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: String = ""
    nonisolated(unsafe) static var statusCode: Int = 200

    static func reset() {
        responseBody = ""
        statusCode = 200
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host.contains("sse.mock.local")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
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
