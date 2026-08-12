//
//  ChatLLMServiceIntegrationTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：通过 URLProtocol 拦截验证 ChatLLMService 的 generate/chat/chatStream 脱敏/还原/错误处理等核心分支。
//

import XCTest
import UFPStorage
import UFPCore
@testable import ZhiYu

// MARK: - ChatLLMService 专用 URLProtocol 拦截器

/// 拦截 ChatLLMService 内部 LLMClient 发起的 URLSession.shared 请求，返回预设响应。
final class ChatLLMServiceMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var jsonBody: Data?
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var errorToThrow: Error?
    nonisolated(unsafe) static var requestCount: Int = 0
    nonisolated(unsafe) static var sseBody: String = ""
    nonisolated(unsafe) static var capturedRequestBody: Data?

    static func reset() {
        jsonBody = nil
        statusCode = 200
        errorToThrow = nil
        requestCount = 0
        sseBody = ""
        capturedRequestBody = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host == "chatllmservice.mock.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        ChatLLMServiceMockURLProtocol.requestCount += 1
        // URLSession 可能将 body 转为 httpBodyStream，需兼容两种形式
        if let body = request.httpBody {
            ChatLLMServiceMockURLProtocol.capturedRequestBody = body
        } else if let stream = request.httpBodyStream {
            ChatLLMServiceMockURLProtocol.capturedRequestBody = readStream(stream)
        }

        if let error = ChatLLMServiceMockURLProtocol.errorToThrow {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        // 判断是否为流式请求：LLMClient.sendStreamingRequest 不设置 Accept header，
        // 需通过请求体中的 "stream": true 字段判断
        var isStreamingRequest = false
        if let body = ChatLLMServiceMockURLProtocol.capturedRequestBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            isStreamingRequest = (json["stream"] as? Bool) == true
        }
        let useSSE = isStreamingRequest && !ChatLLMServiceMockURLProtocol.sseBody.isEmpty

        if useSSE {
            let body = ChatLLMServiceMockURLProtocol.sseBody.data(using: .utf8) ?? Data()
            let response = HTTPURLResponse(
                url: url,
                statusCode: ChatLLMServiceMockURLProtocol.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream", "Content-Length": "\(body.count)"]
            )
            guard let httpResponse = response else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let body = ChatLLMServiceMockURLProtocol.jsonBody ?? Data()
            let response = HTTPURLResponse(
                url: url,
                statusCode: ChatLLMServiceMockURLProtocol.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json", "Content-Length": "\(body.count)"]
            )
            guard let httpResponse = response else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private func readStream(_ stream: InputStream) -> Data {
        var data = Data()
        stream.open()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        stream.close()
        return data
    }
}

// MARK: - ChatLLMService 集成测试

@MainActor
final class ChatLLMServiceIntegrationTests: XCTestCase {

    private var config: LLMConfigManager!
    private var service: ChatLLMService!

    private let mockHost = "chatllmservice.mock.local"

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        ChatLLMServiceMockURLProtocol.reset()

        config = LLMConfigManager()
        config.baseURL = "https://\(mockHost)/v1"
        config.apiKey = "test-api-key"
        config.isEnabled = true
        config.model = "test-model"
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)

        let governanceRepo = RAGGovernanceSQLiteStore()
        ServiceContainer.shared.register(governanceRepo as any RAGGovernanceRepository, for: (any RAGGovernanceRepository).self)
        let mockLLM = MockLLMService()
        ServiceContainer.shared.register(mockLLM as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        let evaluationService = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceRepo)
        ServiceContainer.shared.register(evaluationService, for: RAGEvaluationService.self)
        let analytics = AIAnalyticsService()
        ServiceContainer.shared.register(analytics, for: AIAnalyticsService.self)

        ServiceContainer.shared.register(QueryReranker(), for: (any LLMRetrievalServiceProtocol).self)

        guard let dbQueue = try? DatabaseQueue() else { fatalError("无法创建测试数据库") }
        let knowledgeRepo = KnowledgePageRepository(dbWriter: dbQueue)
        ServiceContainer.shared.register(knowledgeRepo as any KnowledgeRepository, for: (any KnowledgeRepository).self)
        ServiceContainer.shared.register(knowledgeRepo, for: KnowledgePageRepository.self)

        let vectorRepo = MockVectorRepository()
        let embeddingManager = EmbeddingManager(repository: vectorRepo)
        ServiceContainer.shared.register(embeddingManager as any EmbeddingProvider, for: (any EmbeddingProvider).self)

        // P2-1 迁移：创建独立 UserDefaults 实例，避免 .shared 跨测试残留
        guard let testDefaults = UserDefaults(suiteName: "ChatLLMServiceIntegrationTests-\(UUID().uuidString)") else {
            XCTFail("无法创建测试用 UserDefaults")
            return
        }
        ServiceContainer.shared.register(UserDefaultsKeyStore(defaults: testDefaults) as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)
        if KeychainService.testOverride == nil {
            KeychainService.testOverride = MockKeychainService()
        }

        URLProtocol.registerClass(ChatLLMServiceMockURLProtocol.self)

        service = ChatLLMService()
    }

    override func tearDown() async throws {
        service = nil
        config = nil
        ChatLLMServiceMockURLProtocol.reset()
        URLProtocol.unregisterClass(ChatLLMServiceMockURLProtocol.self)
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    private func makeChoicesResponse(content: String) -> Data {
        let escaped = content.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let json = #"{"choices":[{"message":{"content":"\#(escaped)"}}]}"#
        return Data(json.utf8)
    }

    private func makeErrorResponse(message: String) -> Data {
        let escaped = message.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let json = #"{"error":{"message":"\#(escaped)"}}"#
        return Data(json.utf8)
    }

    // MARK: - generate 正常流程

    func testGenerateReturnsContentOnValidResponse() async throws {
        ChatLLMServiceMockURLProtocol.jsonBody = makeChoicesResponse(content: "这是生成的内容")
        ChatLLMServiceMockURLProtocol.statusCode = 200

        let result = try await service.generate(prompt: "测试提示", systemPrompt: "系统设定")
        XCTAssertEqual(result, "这是生成的内容")
        XCTAssertEqual(ChatLLMServiceMockURLProtocol.requestCount, 1)
    }

    // MARK: - generate invalidResponse

    func testGenerateThrowsInvalidResponseWhenNoChoices() async {
        ChatLLMServiceMockURLProtocol.jsonBody = Data(#"{"error":"no choices"}"#.utf8)
        ChatLLMServiceMockURLProtocol.statusCode = 200

        do {
            _ = try await service.generate(prompt: "测试", systemPrompt: "系统")
            XCTFail("响应缺少 choices 时应抛出 invalidResponse")
        } catch LLMError.invalidResponse {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.invalidResponse，实际：\(error)")
        }
    }

    // MARK: - generate 401 unauthorized

    func testGenerateThrowsUnauthorizedOn401() async {
        ChatLLMServiceMockURLProtocol.jsonBody = makeErrorResponse(message: "unauthorized")
        ChatLLMServiceMockURLProtocol.statusCode = 401

        do {
            _ = try await service.generate(prompt: "测试", systemPrompt: "系统")
            XCTFail("401 时应抛出 unauthorized")
        } catch LLMError.unauthorized {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.unauthorized，实际：\(error)")
        }
    }

    // MARK: - generate maxTokens 传递

    func testGeneratePassesMaxTokensInRequestBody() async throws {
        ChatLLMServiceMockURLProtocol.jsonBody = makeChoicesResponse(content: "ok")
        ChatLLMServiceMockURLProtocol.statusCode = 200

        _ = try await service.generate(prompt: "测试", systemPrompt: "系统", maxTokens: 512)

        guard let bodyData = ChatLLMServiceMockURLProtocol.capturedRequestBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            XCTFail("应捕获请求体")
            return
        }
        XCTAssertEqual(json["max_tokens"] as? Int, 512, "请求体应包含 maxTokens=512")
    }

    // MARK: - chat 正常流程（脱敏还原）

    func testChatDeanonymizesResponse() async throws {
        ChatLLMServiceMockURLProtocol.jsonBody = makeChoicesResponse(content: "你好 [ENTITY_A]，我是助手")
        ChatLLMServiceMockURLProtocol.statusCode = 200

        let result = try await service.chat(query: "张三是谁", history: [], pages: [])

        XCTAssertFalse(result.content.contains("[ENTITY_A]"), "响应应已还原，不应包含占位符")
        XCTAssertTrue(result.content.contains("张三"), "响应应包含还原后的姓名")
    }

    // MARK: - chat history 脱敏

    func testChatAnonymizesHistoryContent() async throws {
        ChatLLMServiceMockURLProtocol.jsonBody = makeChoicesResponse(content: "好的")
        ChatLLMServiceMockURLProtocol.statusCode = 200

        // 使用 NLTagger 可识别的人名（.personalName），而非手机号（NLTagger 不识别为命名实体）
        let history: [ChatMessageDTO] = [
            ChatMessageDTO(role: .user, content: "我想了解张三丰的武功"),
            ChatMessageDTO(role: .assistant, content: "已记录")
        ]

        _ = try await service.chat(query: "继续", history: history, pages: [])

        guard let bodyData = ChatLLMServiceMockURLProtocol.capturedRequestBody,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            XCTFail("应捕获请求体并解析 messages")
            return
        }

        let historyContents = messages.compactMap { $0["content"] as? String }
        let hasRawName = historyContents.contains { $0.contains("张三丰") }
        XCTAssertFalse(hasRawName, "history 中的命名实体（张三丰）应被脱敏，不应出现在请求体")
    }

    // MARK: - chat 401

    func testChatThrowsUnauthorizedOn401() async {
        ChatLLMServiceMockURLProtocol.jsonBody = makeErrorResponse(message: "unauthorized")
        ChatLLMServiceMockURLProtocol.statusCode = 401

        do {
            _ = try await service.chat(query: "测试", history: [], pages: [])
            XCTFail("401 时应抛出 unauthorized")
        } catch LLMError.unauthorized {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.unauthorized，实际：\(error)")
        }
    }

    // MARK: - chatStream 正常流程

    func testChatStreamYieldsChunks() async throws {
        let chunk1 = #"data: {"choices":[{"delta":{"content":"你好"}}]}"#
        let chunk2 = #"data: {"choices":[{"delta":{"content":"世界"}}]}"#
        let sseBody = "\(chunk1)\n\n\(chunk2)\n\ndata: [DONE]\n\n"
        ChatLLMServiceMockURLProtocol.sseBody = sseBody
        ChatLLMServiceMockURLProtocol.statusCode = 200

        var chunks: [String] = []
        let stream = service.chatStream(query: "测试", history: [], pages: [])
        do {
            for try await chunk in stream {
                chunks.append(chunk)
            }
        } catch {
            XCTFail("流式不应抛出错误：\(error)")
        }

        XCTAssertEqual(chunks.count, 2, "应产出 2 个 chunk")
        XCTAssertEqual(chunks.joined(), "你好世界")
    }

    // MARK: - chatStream 错误流程（httpError）

    func testChatStreamFinishesWithErrorOnNon200() async {
        ChatLLMServiceMockURLProtocol.sseBody = ""
        ChatLLMServiceMockURLProtocol.statusCode = 500

        let stream = service.chatStream(query: "测试", history: [], pages: [])
        do {
            for try await _ in stream {
                // 不应产出 chunk
            }
            XCTFail("500 时流应以错误结束")
        } catch LLMError.httpError(let code) {
            XCTAssertEqual(code, 500, "应抛出 httpError(500)")
        } catch {
            XCTFail("应抛出 LLMError.httpError(500)，实际：\(error)")
        }
    }

    // MARK: - chatStream 脱敏验证（问题 #14：流式对话已修复 NER 脱敏）

    func testChatStreamAnonymizesQuery() async {
        // 问题 #14 修复后：chatStream 应脱敏 query 中的敏感实体
        let chunk = #"data: {"choices":[{"delta":{"content":"好的"}}]}"#
        ChatLLMServiceMockURLProtocol.sseBody = "\(chunk)\n\ndata: [DONE]\n\n"
        ChatLLMServiceMockURLProtocol.statusCode = 200

        // 使用 NLTagger 可识别的人名
        let stream = service.chatStream(query: "张三丰的武功如何", history: [], pages: [])
        do {
            for try await _ in stream {
                // 消费流
            }
        } catch {
            // 忽略错误，关注请求体
        }

        // 验证修复：请求体中不应包含原始敏感数据"张三丰"
        guard let bodyData = ChatLLMServiceMockURLProtocol.capturedRequestBody,
              let bodyString = String(data: bodyData, encoding: .utf8) else {
            XCTFail("应捕获请求体")
            return
        }

        XCTAssertFalse(bodyString.contains("张三丰"), "问题 #14 修复后：chatStream 应脱敏，'张三丰'不应出现在请求体")
    }

    func testChatStreamAnonymizesHistory() async {
        // 问题 #14 修复后：chatStream 应脱敏 history
        let chunk = #"data: {"choices":[{"delta":{"content":"好的"}}]}"#
        ChatLLMServiceMockURLProtocol.sseBody = "\(chunk)\n\ndata: [DONE]\n\n"
        ChatLLMServiceMockURLProtocol.statusCode = 200

        let history: [ChatMessageDTO] = [
            ChatMessageDTO(role: .user, content: "我想了解张三丰的武功"),
            ChatMessageDTO(role: .assistant, content: "已记录")
        ]

        let stream = service.chatStream(query: "继续", history: history, pages: [])
        do {
            for try await _ in stream {
                // 消费流
            }
        } catch {
            // 忽略错误
        }

        guard let bodyData = ChatLLMServiceMockURLProtocol.capturedRequestBody,
              let bodyString = String(data: bodyData, encoding: .utf8) else {
            XCTFail("应捕获请求体")
            return
        }

        XCTAssertFalse(bodyString.contains("张三丰"), "问题 #14 修复后：chatStream 应脱敏 history，'张三丰'不应出现在请求体")
    }

    func testChatAndChatStreamBothAnonymizeQuery() async {
        // 对比测试：chat 和 chatStream 都应脱敏
        ChatLLMServiceMockURLProtocol.jsonBody = makeChoicesResponse(content: "好的")
        ChatLLMServiceMockURLProtocol.statusCode = 200

        // 1. chat 路径：应脱敏
        _ = try? await service.chat(query: "张三丰的武功", history: [], pages: [])
        let chatBody = ChatLLMServiceMockURLProtocol.capturedRequestBody
        let chatBodyString = chatBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(chatBodyString.contains("张三丰"), "chat 路径应脱敏，'张三丰'不应出现在请求体")

        // 重置
        ChatLLMServiceMockURLProtocol.reset()
        let chunk = #"data: {"choices":[{"delta":{"content":"好的"}}]}"#
        ChatLLMServiceMockURLProtocol.sseBody = "\(chunk)\n\ndata: [DONE]\n\n"
        ChatLLMServiceMockURLProtocol.statusCode = 200

        // 2. chatStream 路径：修复后也应脱敏
        let stream = service.chatStream(query: "张三丰的武功", history: [], pages: [])
        do {
            for try await _ in stream {
                // 消费流
            }
        } catch {
            // 忽略
        }

        let streamBody = ChatLLMServiceMockURLProtocol.capturedRequestBody
        let streamBodyString = streamBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(streamBodyString.contains("张三丰"), "chatStream 路径修复后应脱敏，'张三丰'不应出现在请求体")
    }
}
