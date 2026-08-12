//
//  ChatRunnerIntegrationTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：通过 URLProtocol 拦截验证 ChatRunner 的脱敏/还原/错误处理/预检失败等核心分支。
//

import XCTest
import UFPStorage
import UFPCore
@testable import ZhiYu

// MARK: - ChatRunner 专用 URLProtocol 拦截器

/// 拦截 ChatRunner 内部 LLMClient 发起的 URLSession.shared 请求，返回预设响应。
/// 用于在无真实 API 密钥的环境下验证 ChatRunner 的脱敏、还原、错误处理等核心逻辑。
final class ChatRunnerMockURLProtocol: URLProtocol {
    /// 预设的 JSON 响应体（非流式请求使用）
    nonisolated(unsafe) static var jsonBody: Data?
    /// 预设的 HTTP 状态码
    nonisolated(unsafe) static var statusCode: Int = 200
    /// 预设的错误（非 nil 时请求直接失败）
    nonisolated(unsafe) static var errorToThrow: Error?
    /// 拦截的请求计数（用于验证预检 + 正式请求的调用次数）
    nonisolated(unsafe) static var requestCount: Int = 0
    /// SSE 流式响应体（流式请求使用）
    nonisolated(unsafe) static var sseBody: String = ""

    static func reset() {
        jsonBody = nil
        statusCode = 200
        errorToThrow = nil
        requestCount = 0
        sseBody = ""
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host == "chatrunner.mock.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        ChatRunnerMockURLProtocol.requestCount += 1

        if let error = ChatRunnerMockURLProtocol.errorToThrow {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        // 判断是否为流式请求（通过 Accept header 或 stream 字段）
        let isStreamingRequest = (request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
        let useSSE = isStreamingRequest && !ChatRunnerMockURLProtocol.sseBody.isEmpty

        if useSSE {
            let body = ChatRunnerMockURLProtocol.sseBody.data(using: .utf8) ?? Data()
            let response = HTTPURLResponse(
                url: url,
                statusCode: ChatRunnerMockURLProtocol.statusCode,
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
            let body = ChatRunnerMockURLProtocol.jsonBody ?? Data()
            let response = HTTPURLResponse(
                url: url,
                statusCode: ChatRunnerMockURLProtocol.statusCode,
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
}

// MARK: - ChatRunner 集成测试

/// 验证 ChatRunner 在 URLProtocol 拦截下的核心行为：脱敏/还原、错误处理、预检失败、流式还原。
@MainActor
final class ChatRunnerIntegrationTests: XCTestCase {

    private var config: LLMConfigManager!
    private var runner: ChatRunner!

    private let mockHost = "chatrunner.mock.local"

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        ChatRunnerMockURLProtocol.reset()

        // 注册 ChatRunner 的 4 个 @Inject 依赖
        config = LLMConfigManager()
        config.baseURL = "https://\(mockHost)/v1"
        config.apiKey = "test-api-key"
        config.isEnabled = true
        config.model = "test-model"
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)

        let logger = MockLogger()
        ServiceContainer.shared.register(logger as any LoggerProtocol, for: (any LoggerProtocol).self)

        // 注册 AIAnalyticsService 所需依赖
        let governanceRepo = RAGGovernanceSQLiteStore()
        ServiceContainer.shared.register(governanceRepo as any RAGGovernanceRepository, for: (any RAGGovernanceRepository).self)
        let mockLLM = MockLLMService()
        ServiceContainer.shared.register(mockLLM as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        let evaluationService = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceRepo)
        ServiceContainer.shared.register(evaluationService, for: RAGEvaluationService.self)
        let analytics = AIAnalyticsService()
        ServiceContainer.shared.register(analytics, for: AIAnalyticsService.self)

        // 注册 Reranker（ChatRunner.chat 会调用 reranker.rerank）
        ServiceContainer.shared.register(QueryReranker(), for: (any LLMRetrievalServiceProtocol).self)

        // 注册 KnowledgePageRepository（buildRelevantContext 会调用）
        guard let dbQueue = try? DatabaseQueue() else { fatalError("无法创建测试数据库") }
        let knowledgeRepo = KnowledgePageRepository(dbWriter: dbQueue)
        ServiceContainer.shared.register(knowledgeRepo as any KnowledgeRepository, for: (any KnowledgeRepository).self)
        ServiceContainer.shared.register(knowledgeRepo, for: KnowledgePageRepository.self)

        // 注册 EmbeddingProvider（buildRelevantContext 会调用 multiQuerySearch）
        let vectorRepo = MockVectorRepository()
        let embeddingManager = EmbeddingManager(repository: vectorRepo)
        ServiceContainer.shared.register(embeddingManager as any EmbeddingProvider, for: (any EmbeddingProvider).self)

        // 注册 PromptSanitizer 依赖的 KeyStore（避免 Keychain 调用）
        // P2-1 迁移：创建独立 UserDefaults 实例，避免 .shared 跨测试残留
        guard let testDefaults = UserDefaults(suiteName: "ChatRunnerIntegrationTests-\(UUID().uuidString)") else {
            XCTFail("无法创建测试用 UserDefaults")
            return
        }
        ServiceContainer.shared.register(UserDefaultsKeyStore(defaults: testDefaults) as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)
        if KeychainService.testOverride == nil {
            KeychainService.testOverride = MockKeychainService()
        }

        // 全局注册 URLProtocol 拦截（URLSession.shared 需通过 registerClass 全局注册）
        URLProtocol.registerClass(ChatRunnerMockURLProtocol.self)

        runner = ChatRunner()
    }

    override func tearDown() async throws {
        runner = nil
        config = nil
        ChatRunnerMockURLProtocol.reset()
        URLProtocol.unregisterClass(ChatRunnerMockURLProtocol.self)
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - notConfigured 分支

    /// generate 在 apiKey 为空时应抛出 notConfigured
    func testGenerateThrowsNotConfiguredWhenAPIKeyEmpty() async {
        config.apiKey = ""
        do {
            _ = try await runner.generate(prompt: "测试", systemPrompt: "系统")
            XCTFail("apiKey 为空时应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    /// generate 在 isEnabled=false 时应抛出 notConfigured
    func testGenerateThrowsNotConfiguredWhenDisabled() async {
        config.isEnabled = false
        do {
            _ = try await runner.generate(prompt: "测试", systemPrompt: "系统")
            XCTFail("isEnabled=false 时应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    /// chat 在 isEnabled=false 时应抛出 notConfigured
    func testChatThrowsNotConfiguredWhenDisabled() async {
        config.isEnabled = false
        do {
            _ = try await runner.chat(query: "测试", history: [], pages: [])
            XCTFail("isEnabled=false 时应抛出 notConfigured")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    /// chatStream 在 isEnabled=false 时应以 notConfigured 错误结束
    func testChatStreamFinishesWithErrorWhenDisabled() async {
        config.isEnabled = false
        let stream = runner.chatStream(query: "测试", history: [], pages: [])
        do {
            for try await _ in stream {
                XCTFail("未配置时流不应产出 chunk")
            }
            XCTFail("未配置时流应抛出错误")
        } catch LLMError.notConfigured {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
        }
    }

    // MARK: - generate 正常流程 + 脱敏还原

    /// generate 成功时应返回 deanonymize 后的内容
    func testGenerateReturnsDeanonymizedContent() async throws {
        let responseJSON: [String: Any] = [
            "choices": [["message": ["content": "Hello [ENTITY_A]"]]]
        ]
        ChatRunnerMockURLProtocol.jsonBody = try JSONSerialization.data(withJSONObject: responseJSON)
        ChatRunnerMockURLProtocol.statusCode = 200

        // 使用包含人名的 prompt 触发脱敏
        let result = try await runner.generate(prompt: "请介绍张三的背景", systemPrompt: "你是助手")
        // [ENTITY_A] 应被还原为 "张三"
        XCTAssertEqual(result, "Hello 张三")
    }

    /// generate 在响应缺少 choices 时应抛出 invalidResponse
    func testGenerateThrowsInvalidResponseOnMalformedResponse() async throws {
        let responseJSON: [String: Any] = ["error": "bad request"]
        ChatRunnerMockURLProtocol.jsonBody = try JSONSerialization.data(withJSONObject: responseJSON)
        ChatRunnerMockURLProtocol.statusCode = 200

        do {
            _ = try await runner.generate(prompt: "测试", systemPrompt: "系统")
            XCTFail("响应缺少 choices 时应抛出 invalidResponse")
        } catch LLMError.invalidResponse {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.invalidResponse，实际：\(error)")
        }
    }

    /// generate 在 API 返回 401 时应抛出 unauthorized
    func testGenerateThrowsUnauthorizedOn401() async throws {
        ChatRunnerMockURLProtocol.jsonBody = Data("{}".utf8)
        ChatRunnerMockURLProtocol.statusCode = 401

        do {
            _ = try await runner.generate(prompt: "测试", systemPrompt: "系统")
            XCTFail("401 时应抛出 unauthorized")
        } catch LLMError.unauthorized {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.unauthorized，实际：\(error)")
        }
    }

    // MARK: - chat 正常流程 + 脱敏还原

    /// chat 成功时应返回 deanonymize 后的 ChatMessageDTO
    func testChatReturnsDeanonymizedContent() async throws {
        let responseJSON: [String: Any] = [
            "choices": [["message": ["content": "你好 [ENTITY_A]"]]]
        ]
        ChatRunnerMockURLProtocol.jsonBody = try JSONSerialization.data(withJSONObject: responseJSON)
        ChatRunnerMockURLProtocol.statusCode = 200

        let result = try await runner.chat(query: "李四是谁", history: [], pages: [])
        XCTAssertEqual(result.role, .assistant)
        // [ENTITY_A] 应被还原为 "李四"
        XCTAssertEqual(result.content, "你好 李四")
    }

    // MARK: - chatStream 预检失败

    /// chatStream 在预检失败时应以 apiError 结束
    func testChatStreamThrowsAPIErrorOnPreflightFailure() async {
        ChatRunnerMockURLProtocol.errorToThrow = URLError(.notConnectedToInternet)

        let stream = runner.chatStream(query: "测试", history: [], pages: [])
        do {
            for try await _ in stream {
                // 预检失败不应产出 chunk
            }
            XCTFail("预检失败时流应抛出错误")
        } catch LLMError.apiError {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.apiError，实际：\(error)")
        }
    }
}
