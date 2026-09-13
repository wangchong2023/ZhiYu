//
//  LLMServiceSupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 测试层
//  核心职责：补盲 Infrastructure/LLM LLMService 属性降级与 LLMChatService streamChat
//           的未覆盖分支与边界条件（configManager 缺失时 getter/setter 安全降级、
//           SSE 流式解析、错误传播、历史消息传递）。
//           包含共享 Mock：StreamableMockLLMClient、TestLogger。
//

import XCTest
import UFPCore
import Dependencies
import Combine
@testable import ZhiYu

// MARK: - LLMService 属性降级测试

@MainActor
final class LLMServiceDegradationPropertyTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
    }

    override func tearDown() async throws {
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testProviderReturnsDeepSeekWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.provider, .deepSeek, "configManager 为 nil 时 provider 应降级返回 .deepSeek")
    }

    func testApiKeyReturnsEmptyWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.apiKey, "", "configManager 为 nil 时 apiKey 应降级返回空字符串")
    }

    func testBaseURLReturnsEmptyWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.baseURL, "", "configManager 为 nil 时 baseURL 应降级返回空字符串")
    }

    func testModelReturnsEmptyWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertEqual(service.model, "", "configManager 为 nil 时 model 应降级返回空字符串")
    }

    func testIsEnabledReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.isEnabled, "configManager 为 nil 时 isEnabled 应降级返回 false")
    }

    func testAutoScanReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.autoScan, "configManager 为 nil 时 autoScan 应降级返回 false")
    }

    func testAutoRefactorReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.autoRefactor, "configManager 为 nil 时 autoRefactor 应降级返回 false")
    }

    func testIsReadyReturnsFalseWhenConfigManagerMissing() {
        let service = LLMService()
        XCTAssertFalse(service.isReady, "configManager 为 nil 时 isReady 应降级返回 false")
    }

    func testSetterNoCrashWhenConfigManagerMissing() {
        let service = LLMService()
        service.provider = .zhipu
        service.apiKey = "sk-test"
        service.baseURL = "https://test.com"
        service.model = "test-model"
        service.isEnabled = true
        service.autoScan = true
        service.autoRefactor = true
        XCTAssertEqual(service.baseURL, "", "configManager 缺失时 getter 应安全返回默认值")
        XCTAssertEqual(service.provider, .deepSeek, "configManager 缺失时 provider 应为默认 deepSeek")
    }
}

// MARK: - LLMChatService streamChat 补盲测试

@MainActor
final class LLMChatServiceStreamSupplementTests: XCTestCase {

    func testStreamChatWithLoggerDoesNotCrash() async throws {
        let mockClient = StreamableMockLLMClient(sseText: "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\ndata: [DONE]\n\n")
        let logger = TestLogger()
        let service = LLMChatService(client: mockClient, model: "test", logger: logger)

        let stream = service.streamChat(systemPrompt: "sys", query: "hi", history: [])
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["Hello"], "应从 SSE 流中提取一个 chunk")
        XCTAssertGreaterThan(logger.debugMessages.count, 0, "logger 应记录调试消息")
    }

    func testStreamChatWithoutLoggerDoesNotCrash() async throws {
        let mockClient = StreamableMockLLMClient(sseText: "data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\ndata: [DONE]\n\n")
        let service = LLMChatService(client: mockClient, model: "test")

        let stream = service.streamChat(systemPrompt: "sys", query: "hi", history: [])
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["Hi"])
    }

    func testStreamChatPropagatesClientError() async {
        let mockClient = StreamableMockLLMClient(error: LLMError.apiError("stream error"))
        let service = LLMChatService(client: mockClient, model: "test")

        let stream = service.streamChat(systemPrompt: "sys", query: "hi", history: [])
        do {
            for try await _ in stream {
            }
            XCTFail("应抛出错误")
        } catch {
            if let llmError = error as? LLMError, case .apiError = llmError {
            } else {
                XCTFail("错误类型不匹配: \(error)")
            }
        }
    }

    func testStreamChatWithHistoryPassesMessages() async throws {
        let mockClient = StreamableMockLLMClient(sseText: "data: {\"choices\":[{\"delta\":{\"content\":\"OK\"}}]}\n\ndata: [DONE]\n\n")
        let service = LLMChatService(client: mockClient, model: "test")

        let history = [
            ChatMessageDTO(role: .user, content: "之前的问题"),
            ChatMessageDTO(role: .assistant, content: "之前的回答")
        ]
        let stream = service.streamChat(systemPrompt: "sys", query: "新问题", history: history)
        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        XCTAssertEqual(chunks, ["OK"])
        XCTAssertGreaterThan(mockClient.lastBodyMessagesCount, 2, "请求体应包含历史消息")
    }
}

// MARK: - 测试辅助

/// 支持 SSE 流式请求的 Mock LLM Client
private final class StreamableMockLLMClient: LLMClientProtocol, @unchecked Sendable {
    private let sseText: String
    private let mockError: Error?
    private(set) var lastBodyMessagesCount: Int = 0

    init(sseText: String) {
        self.sseText = sseText
        self.mockError = nil
    }

    init(error: Error) {
        self.sseText = ""
        self.mockError = error
    }

    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        [:]
    }

    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
        if let error = mockError { throw error }
        lastBodyMessagesCount = (body["messages"] as? [[String: Any]])?.count ?? 0
        SSEMockURLProtocol.reset()
        SSEMockURLProtocol.responseBody = sseText
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SSEMockURLProtocol.self]
        let session = URLSession(configuration: config)
        let url = URL(string: "https://sse.mock.local/sse")!
        let (bytes, _) = try await session.bytes(from: url)
        return bytes
    }
}

/// 测试用 Logger（记录 debug 消息用于断言）
private final class TestLogger: LoggerProtocol, @unchecked Sendable {
    var debugMessages: [String] = []

    func addLog(_ entry: LogEntry) {}

    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?,
                startTime: Date?, endTime: Date?, module: String?, status: LogStatus?, failureReason: String?) {}

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debugMessages.append(message)
    }
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {}
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {}
    func error(_ message: String, error: Error?, file: String = #file, function: String = #function, line: Int = #line) {}

    func logTimed<T>(action: LogAction, target: String, module: String?, details: String, operation: () throws -> T) rethrows -> T {
        try operation()
    }

    func saveToDisk() async {}
    func loadFromDisk() async {}
    func clearAllLogs() async {}
    func getLogEntries() async -> [LogEntry] { [] }

    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> {
        Just([]).eraseToAnyPublisher()
    }
}
