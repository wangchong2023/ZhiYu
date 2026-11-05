//
//  SSEParserTests.swift
//  UFPCoreTests
//
//  系统层级：[L0] 测试层
//  核心职责：验证 SSEParser 对多种 LLM 提供商流式响应格式的解析正确性。
//

import XCTest
@testable import UFPCore

final class SSEParserTests: XCTestCase {

    // MARK: - 辅助：通过 URLProtocol mock 构造 AsyncBytes

    private func makeBytes(from sseText: String) async throws -> URLSession.AsyncBytes {
        SSEMockURLProtocol.reset()
        SSEMockURLProtocol.responseBody = sseText
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SSEMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let url = URL(string: "https://sse.mock.local/sse") ?? URL(fileURLWithPath: "/dev/null")
        let (bytes, response) = try await session.bytes(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        return bytes
    }

    // MARK: - 标准 SSE 格式

    func testParseStandardSSEWithSpacePrefix() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}

        data: {"choices":[{"delta":{"content":" World"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["Hello", " World"])
    }

    func testParseStandardSSEWithoutSpacePrefix() async throws {
        let sse = """
        data:{"choices":[{"delta":{"content":"Hi"}}]}

        data:[DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["Hi"])
    }

    // MARK: - reasoning_content 兼容

    func testParseReasoningContent() async throws {
        let sse = """
        data: {"choices":[{"delta":{"reasoning_content":"思考中"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["思考中"])
    }

    // MARK: - message 结构兼容（非流式 SSE）

    func testParseMessageStructure() async throws {
        let sse = """
        data: {"choices":[{"message":{"content":"完整回复"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["完整回复"])
    }

    // MARK: - 空内容跳过

    func testParseEmptyContentSkipped() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":""}}]}

        data: {"choices":[{"delta":{"content":"有效"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["有效"])
    }

    // MARK: - 非 data 行跳过

    func testParseNonDataLinesSkipped() async throws {
        let sse = """
        : comment line

        event: ping

        data: {"choices":[{"delta":{"content":"OK"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["OK"])
    }

    // MARK: - 非 JSON 行跳过

    func testParseNonJSONDataLineSkipped() async throws {
        let sse = """
        data: not json

        data: {"choices":[{"delta":{"content":"有效"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["有效"])
    }

    // MARK: - [DONE] 终止

    func testParseDoneTerminatesStream() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"A"}}]}

        data: [DONE]

        data: {"choices":[{"delta":{"content":"B"}}]}

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["A"], "[DONE] 后的内容不应被解析")
    }

    // MARK: - 空 choices 跳过

    func testParseEmptyChoicesSkipped() async throws {
        let sse = """
        data: {"choices":[]}

        data: {"choices":[{"delta":{"content":"有效"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["有效"])
    }

    // MARK: - 无 choices 字段跳过

    func testParseNoChoicesFieldSkipped() async throws {
        let sse = """
        data: {"model":"gpt-4"}

        data: {"choices":[{"delta":{"content":"有效"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["有效"])
    }

    // MARK: - delta 和 message 都不存在

    func testParseNoDeltaOrMessageSkipped() async throws {
        let sse = """
        data: {"choices":[{"other":"value"}]}

        data: {"choices":[{"delta":{"content":"有效"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["有效"])
    }

    // MARK: - 空流

    func testParseEmptyStream() async throws {
        let chunks = try await collectChunks(from: "")
        XCTAssertTrue(chunks.isEmpty)
    }

    // MARK: - 只有 [DONE]

    func testParseOnlyDone() async throws {
        let sse = "data: [DONE]\n\n"
        let chunks = try await collectChunks(from: sse)
        XCTAssertTrue(chunks.isEmpty)
    }

    // MARK: - content 优先于 reasoning_content

    func testParseContentPrioritizedOverReasoning() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"标准","reasoning_content":"推理"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["标准"])
    }

    // MARK: - 多 chunk 连续

    func testParseMultipleChunks() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"A"}}]}

        data: {"choices":[{"delta":{"content":"B"}}]}

        data: {"choices":[{"delta":{"content":"C"}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["A", "B", "C"])
    }

    // MARK: - content 为空字符串时的 reasoning_content 提取

    func testParseReasoningContentWhenContentIsEmptyString() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"","reasoning_content":"深度推理分析中..."}}]}

        data: [DONE]

        """
        let chunks = try await collectChunks(from: sse)
        XCTAssertEqual(chunks, ["深度推理分析中..."], "当 content 为空字符串时，应成功降级提取 reasoning_content 而不是丢失")
    }

    // MARK: - 带诊断 logger 的分支覆盖

    /// 验证传入非 nil logger 时，正常流结束会记录结束日志（覆盖 logger 非空分支）
    func testParse_WithLogger_LogsStreamEnd() async throws {
        let logger = CapturingLogger()
        let sse = "data: {\"choices\":[{\"delta\":{\"content\":\"A\"}}]}\n\ndata: [DONE]\n\n"
        var chunks: [String] = []
        for try await chunk in SSEParser.parse(bytes: try await makeBytes(from: sse), logger: logger) {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["A"])
        XCTAssertTrue(logger.debugMessages.contains { $0.contains("流结束") }, "应记录流结束诊断日志")
    }

    /// 验证 logger 非空且前 15 行内时记录原始行（覆盖 logDiagnosticLine 非空分支）
    func testParse_WithLogger_RecordsRawLinesWithinLimit() async throws {
        let logger = CapturingLogger()
        let sse = "data: {\"choices\":[{\"delta\":{\"content\":\"A\"}}]}\n\ndata: [DONE]\n\n"
        var chunks: [String] = []
        for try await chunk in SSEParser.parse(bytes: try await makeBytes(from: sse), logger: logger) {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["A"])
        XCTAssertTrue(logger.debugMessages.contains { $0.contains("[SSE] L") }, "应记录前 15 行原始行诊断")
    }

    /// 验证 logger 非空时非 JSON 数据行被记录（覆盖 parseJSONLine 内 logger 分支）
    func testParse_WithLogger_LogsNonJSONLine() async throws {
        let logger = CapturingLogger()
        let sse = "data: not json\n\ndata: [DONE]\n\n"
        var chunks: [String] = []
        for try await chunk in SSEParser.parse(bytes: try await makeBytes(from: sse), logger: logger) {
            chunks.append(chunk)
        }
        XCTAssertTrue(chunks.isEmpty)
        XCTAssertTrue(logger.debugMessages.contains { $0.contains("跳过非 JSON 行") }, "应记录非 JSON 行诊断")
    }

    // MARK: - 辅助方法

    private func collectChunks(from sseText: String) async throws -> [String] {
        let bytes = try await makeBytes(from: sseText)
        var chunks: [String] = []
        for try await chunk in SSEParser.parse(bytes: bytes) {
            chunks.append(chunk)
        }
        return chunks
    }
}

// MARK: - 诊断日志捕获替身（测试专用）

/// 捕获 debug/error 消息的 UFPLogging 替身，验证 SSEParser 诊断分支。
private final class CapturingLogger: UFPLogging, @unchecked Sendable {
    private(set) var debugMessages: [String] = []
    private(set) var errorMessages: [String] = []

    func debug(_ message: String, file: String, function: String, line: Int) {
        debugMessages.append(message)
    }

    func info(_ message: String, file: String, function: String, line: Int) {
        // 不关心 info
    }

    func warning(_ message: String, file: String, function: String, line: Int) {
        // 不关心 warning
    }

    func error(_ message: String, error: Error?, file: String, function: String, line: Int) {
        errorMessages.append(message)
    }
}

// MARK: - URLProtocol mock 拦截 URLSession 请求

/// 通过 URLProtocol 拦截 URLSession 请求，返回预设的 SSE 响应体。
/// 相比 NWListener 本地服务器，URLProtocol mock 在模拟器中更稳定可靠。
final class SSEMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: String = ""

    static func reset() {
        responseBody = ""
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "sse.mock.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = Self.responseBody.data(using: .utf8) ?? Data()
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/event-stream",
                "Content-Length": "\(body.count)",
                "Connection": "close"
            ]
        )
        guard let httpResponse = response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // 无需清理
    }
}
