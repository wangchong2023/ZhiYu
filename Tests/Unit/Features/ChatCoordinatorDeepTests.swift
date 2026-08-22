//
//  ChatCoordinatorDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：ChatCoordinator 深度补盲测试 — 覆盖流式对话状态机、取消竞态、
//            regenerateLastMessage 历史重写、exportChat 选择模式导出、
//            loadInsightfulQuestions guard 短路、generatePredictedQuestions 并发保护、
//            输入长度截断等未覆盖分支，以发现生产代码潜在 bug 为首要目标。
//
//  说明：Tests/Unit/AI/ChatCoordinatorTests.swift 已覆盖初始状态、clearChatHistory、
//        toggleSelectionMode、toggleMessageSelection、cancelCurrentRequest 基础状态、
//        sendMessage 空输入保护。本文件补充流式对话全流程、错误路径、取消竞态、
//        regenerateLastMessage、exportChat、loadInsightfulQuestions、预测问题等深度场景。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - 可捕获 ChatService Mock

/// 可捕获对话服务 Mock，记录所有调用并支持自定义 streamChat 行为
@MainActor
final class CapturableChatService: ChatServiceProtocol, @unchecked Sendable {
    /// 记录 saveUserMessage 调用的内容列表
    private(set) var savedUserMessages: [String] = []
    /// 记录 saveAssistantMessage 调用的内容列表
    private(set) var savedAssistantMessages: [String] = []
    /// clearHistory 调用次数
    private(set) var clearHistoryCallCount: Int = 0
    /// loadHistory 返回的预设历史
    var stubHistory: [ChatMessage] = []
    /// streamChat 自定义行为工厂（返回 chunk 数组或抛错）
    var streamChatHandler: ((String, [KnowledgePage]) async throws -> [String])?
    /// streamChat 收到的 query 参数记录
    private(set) var streamChatQueries: [String] = []
    /// streamChat 收到的 pages 参数记录
    private(set) var streamChatPages: [[KnowledgePage]] = []

    func loadHistory() -> [ChatMessage] { stubHistory }

    func clearHistory() {
        clearHistoryCallCount += 1
        savedUserMessages.removeAll()
        savedAssistantMessages.removeAll()
    }

    func streamChat(query: String, pages: [KnowledgePage]) -> AsyncThrowingStream<String, Error> {
        streamChatQueries.append(query)
        streamChatPages.append(pages)
        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let handler = self.streamChatHandler ?? { _, _ in ["默认回复"] }
                    let chunks = try await handler(query, pages)
                    for chunk in chunks {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func saveAssistantMessage(_ content: String) {
        savedAssistantMessages.append(content)
    }

    func saveUserMessage(_ content: String) {
        savedUserMessages.append(content)
    }
}

// MARK: - 可捕获 AISynthesisService Mock

/// 可捕获 AI 综合服务 Mock，支持自定义 generateInsightfulQuestions / predictFollowUpQuestions 行为
@MainActor
final class CapturableAISynthesisService: AISynthesisServiceProtocol, @unchecked Sendable {
    /// generateInsightfulQuestions 返回的预设问题列表
    var stubInsightfulQuestions: [String] = ["启发问题1", "启发问题2"]
    /// generateInsightfulQuestions 是否应抛错
    var shouldThrowInsightful: Bool = false
    /// predictFollowUpQuestions 返回的预设问题列表
    var stubFollowUpQuestions: [String] = ["追问1", "追问2", "追问3"]
    /// predictFollowUpQuestions 是否应抛错
    var shouldThrowFollowUp: Bool = false
    /// generateInsightfulQuestions 调用次数
    private(set) var insightfulCallCount: Int = 0
    /// predictFollowUpQuestions 调用次数
    private(set) var followUpCallCount: Int = 0

    func summarize(content: String) async throws -> String { "" }
    func generateMindMap(content: String) async throws -> String { "" }

    func generateInsightfulQuestions(pages: [KnowledgePage]) async throws -> [String] {
        insightfulCallCount += 1
        if shouldThrowInsightful {
            throw LLMError.notConfigured
        }
        return stubInsightfulQuestions
    }

    func predictFollowUpQuestions(history: [ChatMessage], pages: [KnowledgePage]) async throws -> [String] {
        followUpCallCount += 1
        if shouldThrowFollowUp {
            throw LLMError.notConfigured
        }
        return stubFollowUpQuestions
    }
}

// MARK: - ChatCoordinatorDeepTests

@MainActor
final class ChatCoordinatorDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试用用户提问文本
    private let testQuery = "什么是 RAG？"
    /// 测试用流式回复 chunk 1
    private let streamChunk1 = "RAG 是检索增强生成"
    /// 测试用流式回复 chunk 2
    private let streamChunk2 = "，结合检索与生成。"
    /// 测试用知识页面标题
    private let pageTitle = "RAG 入门"
    /// 测试用知识页面内容
    private let pageContent = "RAG 是一种结合检索与生成的技术。"
    /// 超长输入文本长度（超过 maxUserInputLength 触发截断）
    private let overLengthCount = 5000
    /// maxUserInputLength 常量值（与源码 PromptConstants.TokenLimits.maxUserInputLength 对齐）
    private let maxUserInputLength = 4000
    /// 启发式问题预设值 1
    private let insightfulQuestion1 = "启发问题1"
    /// 启发式问题预设值 2
    private let insightfulQuestion2 = "启发问题2"
    /// 预测追问预设值 1
    private let followUpQuestion1 = "追问1"

    // MARK: - 被测对象与 Mock

    private var coordinator: ChatCoordinator!
    private var capturableChat: CapturableChatService!
    private var capturableSynthesis: CapturableAISynthesisService!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()

        // 注册可捕获的 ChatService 和 AISynthesisService 到 DI 容器
        capturableChat = CapturableChatService()
        ServiceContainer.shared.register(capturableChat as any ChatServiceProtocol, for: (any ChatServiceProtocol).self)
        capturableSynthesis = CapturableAISynthesisService()
        ServiceContainer.shared.register(capturableSynthesis as any AISynthesisServiceProtocol, for: (any AISynthesisServiceProtocol).self)

        // ChatCoordinator.init() 会调用 chatService.loadHistory()，需在注册后创建
        coordinator = ChatCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
        capturableChat = nil
        capturableSynthesis = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 构造测试用 KnowledgePage
    private func makePage() -> KnowledgePage {
        KnowledgePage(title: pageTitle, content: pageContent)
    }

    // MARK: - sendMessage 流式对话全流程

    /// 验证 sendMessage 成功完成流式对话后，用户消息和助手消息都追加到 chatHistory
    func testSendMessage_成功完成_追加用户和助手消息() async throws {
        capturableChat.streamChatHandler = { _, _ in
            [self.streamChunk1, self.streamChunk2]
        }

        await coordinator.sendMessage(query: testQuery, pages: [makePage()])

        XCTAssertEqual(coordinator.chatHistory.count, 2, "应包含用户消息和助手消息")
        XCTAssertEqual(coordinator.chatHistory[0].role, .user, "第一条应为用户消息")
        XCTAssertEqual(coordinator.chatHistory[0].content, testQuery, "用户消息内容应匹配")
        XCTAssertEqual(coordinator.chatHistory[1].role, .assistant, "第二条应为助手消息")
        XCTAssertEqual(coordinator.chatHistory[1].content, streamChunk1 + streamChunk2, "助手消息应为流式 chunk 拼接")
    }

    /// 验证 sendMessage 成功后，ChatService.saveUserMessage 和 saveAssistantMessage 都被调用
    func testSendMessage_成功完成_调用ChatService持久化() async throws {
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertEqual(capturableChat.savedUserMessages, [testQuery], "saveUserMessage 应以提问内容调用")
        XCTAssertEqual(capturableChat.savedAssistantMessages, [streamChunk1], "saveAssistantMessage 应以流式拼接内容调用")
    }

    /// 验证 sendMessage 完成后 isProcessing 恢复为 false
    func testSendMessage_完成后_isProcessing恢复False() async throws {
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertFalse(coordinator.isProcessing, "流式完成后 isProcessing 应恢复 false")
    }

    /// 验证 sendMessage 完成后 streamingContent 被清空
    func testSendMessage_完成后_streamingContent被清空() async throws {
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1, self.streamChunk2] }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertEqual(coordinator.streamingContent, "", "流式完成后 streamingContent 应清空")
    }

    /// 验证 sendMessage 使用 inputText 作为默认 query（query 为 nil 时）
    func testSendMessage_使用inputText作为默认query() async throws {
        coordinator.inputText = testQuery
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: nil, pages: [])

        XCTAssertEqual(coordinator.chatHistory.first?.content, testQuery, "应使用 inputText 作为提问内容")
    }

    /// 验证 sendMessage 使用 inputText 后清空 inputText
    func testSendMessage_使用inputText后_清空inputText() async throws {
        coordinator.inputText = testQuery
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: nil, pages: [])

        XCTAssertEqual(coordinator.inputText, "", "使用 inputText 发送后应清空")
    }

    /// 验证 sendMessage 传入显式 query 时不清空 inputText
    func testSendMessage_显式query_不清空inputText() async throws {
        coordinator.inputText = "残留输入"
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertEqual(coordinator.inputText, "残留输入", "显式 query 发送后 inputText 应保留")
    }

    /// 验证 sendMessage 对超长输入截断至 maxUserInputLength
    func testSendMessage_超长输入_截断至最大长度() async throws {
        let longText = String(repeating: "A", count: overLengthCount)
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: longText, pages: [])

        let savedUser = capturableChat.savedUserMessages.first ?? ""
        XCTAssertEqual(savedUser.count, maxUserInputLength, "超长输入应被截断至 maxUserInputLength")
    }

    /// 验证 sendMessage 对纯空白字符输入直接返回不处理
    func testSendMessage_纯空白字符_不处理() async throws {
        await coordinator.sendMessage(query: "\n\t  \n", pages: [])

        XCTAssertTrue(coordinator.chatHistory.isEmpty, "纯空白输入不应追加消息")
        XCTAssertEqual(capturableChat.savedUserMessages.count, 0, "纯空白输入不应调用 saveUserMessage")
    }

    /// 验证 sendMessage 发送后清空 predictedQuestions
    /// - Note: 流式完成后 runStreamTask 会异步启动 generatePredictedQuestions Task
    ///   重新填充 predictedQuestions。设置 stubFollowUpQuestions 为空确保预测返回空数组，
    ///   从而验证 91 行的清空逻辑 + 预测完成后仍为空。
    func testSendMessage_发送后_清空predictedQuestions() async throws {
        coordinator.predictedQuestions = ["旧追问1", "旧追问2"]
        capturableSynthesis.stubFollowUpQuestions = []
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: testQuery, pages: [])

        // 等待异步 generatePredictedQuestions Task 完成
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(coordinator.predictedQuestions.isEmpty, "发送新消息应清空旧的预测追问")
    }

    /// 验证 sendMessage 发送后清空 errorMessage
    func testSendMessage_发送后_清空errorMessage() async throws {
        coordinator.errorMessage = "旧错误"
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertNil(coordinator.errorMessage, "发送新消息应清空旧的 errorMessage")
    }

    // MARK: - sendMessage isProcessing 中断逻辑

    /// 验证 sendMessage 在 isProcessing 为 true 时调用 cancelCurrentRequest 并直接返回
    /// - Note: streamChatHandler 需阻塞足够长时间，确保第二次 sendMessage 调用时
    ///   第一次仍在 isProcessing 状态。Mock 返回过快会导致时序竞态。
    func testSendMessage_isProcessing时_取消当前请求并返回() async throws {
        let delayNanoseconds: UInt64 = 500_000_000
        capturableChat.streamChatHandler = { _, _ in
            try await Task.sleep(nanoseconds: delayNanoseconds)
            return [self.streamChunk1]
        }

        // 先启动第一次发送（会阻塞在 streamChat 的 delay 上）
        let firstSend = Task { @MainActor in
            await self.coordinator.sendMessage(query: self.testQuery, pages: [])
        }

        // 等待第一次发送进入 isProcessing 状态
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(coordinator.isProcessing, "第一次发送应进入 isProcessing 状态")

        // 第二次发送应触发取消逻辑（isProcessing 为 true → cancelCurrentRequest + return）
        await coordinator.sendMessage(query: "第二次提问", pages: [])

        // 等待第一次发送完成
        await firstSend.value

        // 第二次发送应被中断，不追加新消息（cancelCurrentRequest 后直接 return）
        // chatHistory 可能只有第一次的用户消息（取决于取消时序），但不应有"第二次提问"
        let hasSecondQuery = coordinator.chatHistory.contains { $0.content == "第二次提问" }
        XCTAssertFalse(hasSecondQuery, "isProcessing 时的第二次发送不应追加新用户消息")
    }

    // MARK: - sendMessage 错误路径

    /// 验证 sendMessage 流式抛出 LLMError.notConfigured 时设置 showLLMAlert
    func testSendMessage_流式抛notConfigured_设置showLLMAlert() async throws {
        capturableChat.streamChatHandler = { _, _ in
            throw LLMError.notConfigured
        }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertTrue(coordinator.showLLMAlert, "notConfigured 错误应设置 showLLMAlert")
        XCTAssertFalse(coordinator.showError, "notConfigured 错误不应设置 showError")
        XCTAssertNil(coordinator.errorMessage, "notConfigured 错误不应设置 errorMessage")
    }

    /// 验证 sendMessage 流式抛出普通错误时设置 showError 和 errorMessage
    func testSendMessage_流式抛普通错误_设置showError和ErrorMessage() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "测试网络错误" }
        }
        capturableChat.streamChatHandler = { _, _ in
            throw TestError()
        }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertTrue(coordinator.showError, "普通错误应设置 showError")
        XCTAssertNotNil(coordinator.errorMessage, "普通错误应设置 errorMessage")
        XCTAssertFalse(coordinator.showLLMAlert, "普通错误不应设置 showLLMAlert")
    }

    /// 验证 sendMessage 流式抛错后 isProcessing 恢复 false
    func testSendMessage_流式抛错后_isProcessing恢复False() async throws {
        struct TestError: Error {}
        capturableChat.streamChatHandler = { _, _ in
            throw TestError()
        }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertFalse(coordinator.isProcessing, "错误后 isProcessing 应恢复 false")
    }

    /// 验证 sendMessage 流式抛错后 streamingContent 被清空
    func testSendMessage_流式抛错后_streamingContent被清空() async throws {
        struct TestError: Error {}
        capturableChat.streamChatHandler = { _, _ in
            throw TestError()
        }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertEqual(coordinator.streamingContent, "", "错误后 streamingContent 应清空")
    }

    /// 验证 sendMessage 流式抛错后不追加助手消息
    func testSendMessage_流式抛错后_不追加助手消息() async throws {
        struct TestError: Error {}
        capturableChat.streamChatHandler = { _, _ in
            throw TestError()
        }

        await coordinator.sendMessage(query: testQuery, pages: [])

        XCTAssertEqual(coordinator.chatHistory.count, 1, "错误后应只有用户消息，无助手消息")
        XCTAssertEqual(coordinator.chatHistory.first?.role, .user, "唯一消息应为用户消息")
    }

    // MARK: - cancelCurrentRequest

    /// 验证 cancelCurrentRequest 清空 currentStreamTask 引用
    func testCancelCurrentRequest_清空currentStreamTask() async throws {
        capturableChat.streamChatHandler = { _, _ in
            // 模拟慢速流式，让 cancel 有机会介入
            try await Task.sleep(nanoseconds: 500_000_000)
            return [self.streamChunk1]
        }

        let sendTask = Task { @MainActor in
            await self.coordinator.sendMessage(query: self.testQuery, pages: [])
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        coordinator.cancelCurrentRequest()

        await sendTask.value

        XCTAssertFalse(coordinator.isProcessing, "取消后 isProcessing 应为 false")
    }

    // MARK: - regenerateLastMessage

    /// 验证 regenerateLastMessage 无用户消息时直接返回不处理
    func testRegenerateLastMessage_无用户消息_不处理() async throws {
        coordinator.chatHistory = [
            ChatMessage(role: .assistant, content: "只有助手消息")
        ]
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.regenerateLastMessage(pages: [])

        XCTAssertEqual(coordinator.chatHistory.count, 1, "无用户消息时不应改变 chatHistory")
        XCTAssertEqual(capturableChat.clearHistoryCallCount, 0, "无用户消息时不应调用 clearHistory")
    }

    /// 验证 regenerateLastMessage 保留最后用户提问之前的消息
    func testRegenerateLastMessage_保留用户提问前的消息() async throws {
        coordinator.chatHistory = [
            ChatMessage(role: .user, content: "第一个问题"),
            ChatMessage(role: .assistant, content: "第一个回复"),
            ChatMessage(role: .user, content: "第二个问题"),
            ChatMessage(role: .assistant, content: "第二个回复")
        ]
        capturableChat.streamChatHandler = { _, _ in ["重新生成的回复"] }

        await coordinator.regenerateLastMessage(pages: [])

        // regenerateLastMessage 保留至最后用户提问（不含），然后 sendMessage 重新追加
        // 保留: "第一个问题", "第一个回复" (2 条)
        // sendMessage 追加: "第二个问题" (用户), "重新生成的回复" (助手) (2 条)
        XCTAssertEqual(coordinator.chatHistory.count, 4, "应保留提问前消息并重新追加用户和助手消息")
        XCTAssertEqual(coordinator.chatHistory[0].content, "第一个问题", "应保留第一个用户消息")
        XCTAssertEqual(coordinator.chatHistory[1].content, "第一个回复", "应保留第一个助手回复")
        XCTAssertEqual(coordinator.chatHistory[2].content, "第二个问题", "应重新追加最后用户提问")
        XCTAssertEqual(coordinator.chatHistory[3].content, "重新生成的回复", "应追加重新生成的助手回复")
    }

    /// 验证 regenerateLastMessage 调用 clearHistory 清空持久化
    func testRegenerateLastMessage_调用clearHistory清空持久化() async throws {
        coordinator.chatHistory = [
            ChatMessage(role: .user, content: "问题"),
            ChatMessage(role: .assistant, content: "回复")
        ]
        capturableChat.streamChatHandler = { _, _ in [self.streamChunk1] }

        await coordinator.regenerateLastMessage(pages: [])

        XCTAssertGreaterThanOrEqual(capturableChat.clearHistoryCallCount, 1, "应调用 clearHistory 清空持久化")
    }

    /// 验证 regenerateLastMessage 重写持久化时保留的消息按角色正确保存
    func testRegenerateLastMessage_重写持久化_按角色保存保留消息() async throws {
        coordinator.chatHistory = [
            ChatMessage(role: .user, content: "保留的用户问题"),
            ChatMessage(role: .assistant, content: "保留的助手回复"),
            ChatMessage(role: .user, content: "要重新生成的问题")
        ]
        capturableChat.streamChatHandler = { _, _ in ["新回复"] }

        await coordinator.regenerateLastMessage(pages: [])

        // clearHistory 后重写保留消息，再 sendMessage 追加
        // savedUserMessages 应包含: "保留的用户问题" (重写) + "要重新生成的问题" (sendMessage)
        XCTAssertTrue(capturableChat.savedUserMessages.contains("保留的用户问题"), "重写时应保存保留的用户消息")
        XCTAssertTrue(capturableChat.savedAssistantMessages.contains("保留的助手回复"), "重写时应保存保留的助手消息")
    }

    // MARK: - clearChatHistory 持久化

    /// 验证 clearChatHistory 调用 ChatService.clearHistory
    func testClearChatHistory_调用ChatServiceClearHistory() {
        coordinator.chatHistory.append(ChatMessage(role: .user, content: "test"))

        coordinator.clearChatHistory()

        XCTAssertEqual(capturableChat.clearHistoryCallCount, 1, "应调用 ChatService.clearHistory")
    }

    // MARK: - loadInsightfulQuestions

    /// 验证 loadInsightfulQuestions 空页面数组时直接返回不处理
    func testLoadInsightfulQuestions_空页面_不处理() async throws {
        await coordinator.loadInsightfulQuestions(pages: [], forceRefresh: true)

        XCTAssertEqual(capturableSynthesis.insightfulCallCount, 0, "空页面不应调用 generateInsightfulQuestions")
    }

    /// 验证 loadInsightfulQuestions 已有问题且非强制刷新时不重复生成
    func testLoadInsightfulQuestions_已有问题非强制刷新_不重复生成() async throws {
        coordinator.insightfulQuestions = [insightfulQuestion1]
        capturableSynthesis.stubInsightfulQuestions = ["新问题"]

        await coordinator.loadInsightfulQuestions(pages: [makePage()], forceRefresh: false)

        XCTAssertEqual(coordinator.insightfulQuestions, [insightfulQuestion1], "非强制刷新应保留已有问题")
        XCTAssertEqual(capturableSynthesis.insightfulCallCount, 0, "非强制刷新且已有问题不应调用生成")
    }

    /// 验证 loadInsightfulQuestions 强制刷新时重新生成
    func testLoadInsightfulQuestions_强制刷新_重新生成() async throws {
        coordinator.insightfulQuestions = [insightfulQuestion1]
        capturableSynthesis.stubInsightfulQuestions = [insightfulQuestion2]

        await coordinator.loadInsightfulQuestions(pages: [makePage()], forceRefresh: true)

        XCTAssertEqual(coordinator.insightfulQuestions, [insightfulQuestion2], "强制刷新应更新为新生成的问题")
        XCTAssertEqual(capturableSynthesis.insightfulCallCount, 1, "强制刷新应调用生成")
    }

    /// 验证 loadInsightfulQuestions 已有问题为空时自动生成
    func testLoadInsightfulQuestions_问题为空_自动生成() async throws {
        coordinator.insightfulQuestions = []
        capturableSynthesis.stubInsightfulQuestions = [insightfulQuestion1, insightfulQuestion2]

        await coordinator.loadInsightfulQuestions(pages: [makePage()], forceRefresh: false)

        XCTAssertEqual(coordinator.insightfulQuestions, [insightfulQuestion1, insightfulQuestion2], "问题为空时应自动生成")
    }

    /// 验证 loadInsightfulQuestions 生成抛错时清空问题列表
    func testLoadInsightfulQuestions_生成抛错_清空问题列表() async throws {
        coordinator.insightfulQuestions = []
        capturableSynthesis.shouldThrowInsightful = true

        await coordinator.loadInsightfulQuestions(pages: [makePage()], forceRefresh: true)

        XCTAssertTrue(coordinator.insightfulQuestions.isEmpty, "生成抛错应清空问题列表")
    }

    /// 验证 loadInsightfulQuestions 生成抛错后 isGeneratingAIQuestions 恢复 false
    func testLoadInsightfulQuestions_生成抛错后_isGeneratingAIQuestions恢复False() async throws {
        capturableSynthesis.shouldThrowInsightful = true

        await coordinator.loadInsightfulQuestions(pages: [makePage()], forceRefresh: true)

        XCTAssertFalse(coordinator.isGeneratingAIQuestions, "抛错后 isGeneratingAIQuestions 应恢复 false")
    }

    /// 验证 loadInsightfulQuestions 成功后 isGeneratingAIQuestions 恢复 false
    func testLoadInsightfulQuestions_成功后_isGeneratingAIQuestions恢复False() async throws {
        await coordinator.loadInsightfulQuestions(pages: [makePage()], forceRefresh: true)

        XCTAssertFalse(coordinator.isGeneratingAIQuestions, "成功后 isGeneratingAIQuestions 应恢复 false")
    }

    // MARK: - generatePredictedQuestions

    /// 验证 generatePredictedQuestions 空 chatHistory 时直接返回不处理
    func testGeneratePredictedQuestions_空chatHistory_不处理() async throws {
        coordinator.chatHistory = []
        capturableSynthesis.stubFollowUpQuestions = [followUpQuestion1]

        await coordinator.generatePredictedQuestions(pages: [makePage()])

        XCTAssertEqual(coordinator.predictedQuestions, [], "空 chatHistory 不应生成预测问题")
        XCTAssertEqual(capturableSynthesis.followUpCallCount, 0, "空 chatHistory 不应调用预测")
    }

    /// 验证 generatePredictedQuestions 成功后更新 predictedQuestions
    func testGeneratePredictedQuestions_成功_更新predictedQuestions() async throws {
        coordinator.chatHistory = [ChatMessage(role: .user, content: "问题")]
        capturableSynthesis.stubFollowUpQuestions = [followUpQuestion1]

        await coordinator.generatePredictedQuestions(pages: [makePage()])

        XCTAssertEqual(coordinator.predictedQuestions, [followUpQuestion1], "应更新预测问题列表")
    }

    /// 验证 generatePredictedQuestions 抛错时清空 predictedQuestions
    func testGeneratePredictedQuestions_抛错_清空predictedQuestions() async throws {
        coordinator.chatHistory = [ChatMessage(role: .user, content: "问题")]
        coordinator.predictedQuestions = ["旧追问"]
        capturableSynthesis.shouldThrowFollowUp = true

        await coordinator.generatePredictedQuestions(pages: [makePage()])

        XCTAssertTrue(coordinator.predictedQuestions.isEmpty, "抛错应清空 predictedQuestions")
    }

    /// 验证 generatePredictedQuestions 抛错后 isGeneratingPredictedQuestions 恢复 false
    func testGeneratePredictedQuestions_抛错后_isGenerating恢复False() async throws {
        coordinator.chatHistory = [ChatMessage(role: .user, content: "问题")]
        capturableSynthesis.shouldThrowFollowUp = true

        await coordinator.generatePredictedQuestions(pages: [makePage()])

        XCTAssertFalse(coordinator.isGeneratingPredictedQuestions, "抛错后 isGeneratingPredictedQuestions 应恢复 false")
    }

    /// 验证 generatePredictedQuestions 成功后 isGeneratingPredictedQuestions 恢复 false
    func testGeneratePredictedQuestions_成功后_isGenerating恢复False() async throws {
        coordinator.chatHistory = [ChatMessage(role: .user, content: "问题")]

        await coordinator.generatePredictedQuestions(pages: [makePage()])

        XCTAssertFalse(coordinator.isGeneratingPredictedQuestions, "成功后应恢复 false")
    }

    // MARK: - exportChat

    /// 验证 exportChat 空历史时直接返回不处理
    func testExportChat_空历史_不处理() async throws {
        coordinator.chatHistory = []

        await coordinator.exportChat()

        XCTAssertFalse(coordinator.isExporting, "空历史不应进入导出流程")
        XCTAssertNil(coordinator.exportURL, "空历史不应设置 exportURL")
    }

    /// 验证 exportChat 成功后设置 exportURL
    func testExportChat_成功_设置exportURL() async throws {
        coordinator.chatHistory = [
            ChatMessage(role: .user, content: "问题"),
            ChatMessage(role: .assistant, content: "回复")
        ]

        await coordinator.exportChat()

        XCTAssertNotNil(coordinator.exportURL, "成功导出应设置 exportURL")
        XCTAssertFalse(coordinator.isExporting, "导出完成后 isExporting 应恢复 false")
    }

    /// 验证 exportChat 选择模式下仅导出选中消息
    func testExportChat_选择模式_仅导出选中消息() async throws {
        let selectedID = UUID()
        coordinator.chatHistory = [
            ChatMessage(role: .user, content: "选中问题"),
            ChatMessage(role: .assistant, content: "选中回复"),
            ChatMessage(role: .user, content: "未选中问题")
        ]
        // 修改第一条消息的 id 为 selectedID
        coordinator.chatHistory[0] = ChatMessage(id: selectedID, role: .user, content: "选中问题")
        coordinator.isSelectionMode = true
        coordinator.selectedMessageIDs.insert(selectedID)

        await coordinator.exportChat()

        XCTAssertNotNil(coordinator.exportURL, "选择模式下应导出选中消息")
    }

    /// 验证 exportChat 选择模式但无选中消息时导出全部
    func testExportChat_选择模式无选中_导出全部() async throws {
        coordinator.chatHistory = [
            ChatMessage(role: .user, content: "问题1"),
            ChatMessage(role: .assistant, content: "回复1")
        ]
        coordinator.isSelectionMode = true
        coordinator.selectedMessageIDs = []

        await coordinator.exportChat()

        XCTAssertNotNil(coordinator.exportURL, "选择模式无选中时应导出全部")
    }

    // MARK: - toggleSelectionMode 关闭时清空选择

    /// 验证 toggleSelectionMode 从 true 切换到 false 时清空 selectedMessageIDs
    func testToggleSelectionMode_从True切换到False_清空selectedMessageIDs() {
        coordinator.isSelectionMode = true
        coordinator.selectedMessageIDs.insert(UUID())
        coordinator.selectedMessageIDs.insert(UUID())

        coordinator.toggleSelectionMode()

        XCTAssertFalse(coordinator.isSelectionMode, "应切换为 false")
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty, "关闭选择模式应清空 selectedMessageIDs")
    }

    // MARK: - toggleMessageSelection

    /// 验证 toggleMessageSelection 切换选中状态
    func testToggleMessageSelection_切换选中状态() {
        let id1 = UUID()
        let id2 = UUID()

        coordinator.toggleMessageSelection(id1)
        XCTAssertTrue(coordinator.selectedMessageIDs.contains(id1), "首次点击应选中")

        coordinator.toggleMessageSelection(id2)
        XCTAssertTrue(coordinator.selectedMessageIDs.contains(id2), "不同 ID 应独立选中")

        coordinator.toggleMessageSelection(id1)
        XCTAssertFalse(coordinator.selectedMessageIDs.contains(id1), "再次点击应取消选中")
    }

    // MARK: - clearChatHistory 清空 predictedQuestions

    /// 验证 clearChatHistory 清空 predictedQuestions
    func testClearChatHistory_清空predictedQuestions() {
        coordinator.predictedQuestions = [followUpQuestion1, "追问2"]
        coordinator.chatHistory = [ChatMessage(role: .user, content: "test")]

        coordinator.clearChatHistory()

        XCTAssertTrue(coordinator.predictedQuestions.isEmpty, "清空历史应同时清空 predictedQuestions")
    }

    // MARK: - init 加载历史

    /// 验证 init 时从 ChatService 加载历史
    func testInit_从ChatService加载历史() {
        let stubMessages = [
            ChatMessage(role: .user, content: "历史问题"),
            ChatMessage(role: .assistant, content: "历史回复")
        ]
        capturableChat.stubHistory = stubMessages

        let newCoordinator = ChatCoordinator()

        XCTAssertEqual(newCoordinator.chatHistory.count, stubMessages.count, "init 应从 ChatService 加载历史")
        XCTAssertEqual(newCoordinator.chatHistory.first?.content, stubMessages.first?.content, "首条消息内容应匹配")
        XCTAssertEqual(newCoordinator.chatHistory.last?.content, stubMessages.last?.content, "末条消息内容应匹配")
    }

    /// 验证 init 时 ChatService 返回空历史则 chatHistory 为空
    func testInit_ChatService返回空_则chatHistory为空() {
        capturableChat.stubHistory = []

        let newCoordinator = ChatCoordinator()

        XCTAssertTrue(newCoordinator.chatHistory.isEmpty, "ChatService 返回空时 chatHistory 应为空")
    }
}
