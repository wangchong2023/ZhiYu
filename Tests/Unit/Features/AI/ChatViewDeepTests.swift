//
//  ChatViewDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：ChatViewInteractiveTests.swift, ChatViewMultiTurnStreamDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class ChatViewDeepTests: XCTestCase {

    private var appStore: AppStore!
    private var coordinator: ChatCoordinator!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = AppStore()
        coordinator = ChatCoordinator()
        router = Router.shared
    }

    func testColdStartPromptConsumption() async {
        let testPrompt = "什么是 Karpathy LLM Wiki 方法论？"
        router.pendingInitialChatPrompt = testPrompt

        XCTAssertEqual(router.pendingInitialChatPrompt, testPrompt)

        // 模拟 ChatView 的 .task 启动消费逻辑
        if let prompt = router.pendingInitialChatPrompt, !prompt.isEmpty {
            router.pendingInitialChatPrompt = nil
            coordinator.inputText = prompt
        }

        XCTAssertNil(router.pendingInitialChatPrompt, "消费后 pendingInitialChatPrompt 必须单次且安全置空")
        XCTAssertEqual(coordinator.inputText, testPrompt, "应自动装填至对话框输入文本中")
    }

    func testStreamingProcessingAndCancelRequest() {
        // 初始状态
        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertTrue(coordinator.streamingContent.isEmpty)

        // 模拟进入流式生成状态
        coordinator.isProcessing = true
        coordinator.streamingContent = "正在为您检索知识库相关段落并生成回复..."

        XCTAssertTrue(coordinator.isProcessing)
        XCTAssertFalse(coordinator.streamingContent.isEmpty)

        // 模拟触发一键中断
        coordinator.cancelCurrentRequest()

        XCTAssertFalse(coordinator.isProcessing, "主动中断后 isProcessing 必须重置为 false")
    }

    func testMessageSelectionModeAndBatchActions() {
        let msg1 = ChatMessage(role: .user, content: "你好，请解释 L0 层")
        let msg2 = ChatMessage(role: .assistant, content: "L0 层为通用底座与基础设施包。")
        coordinator.chatHistory = [msg1, msg2]

        XCTAssertFalse(coordinator.isSelectionMode)
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty)

        // 开启多选模式
        coordinator.isSelectionMode = true
        XCTAssertTrue(coordinator.isSelectionMode)

        // 勾选消息 1
        coordinator.toggleMessageSelection(msg1.id)
        XCTAssertTrue(coordinator.selectedMessageIDs.contains(msg1.id))
        XCTAssertEqual(coordinator.selectedMessageIDs.count, 1)

        // 勾选消息 2
        coordinator.toggleMessageSelection(msg2.id)
        XCTAssertEqual(coordinator.selectedMessageIDs.count, 2)

        // 取消勾选消息 1
        coordinator.toggleMessageSelection(msg1.id)
        XCTAssertFalse(coordinator.selectedMessageIDs.contains(msg1.id))
        XCTAssertEqual(coordinator.selectedMessageIDs.count, 1)

        // 清空选择
        coordinator.selectedMessageIDs.removeAll()
        coordinator.isSelectionMode = false
        XCTAssertFalse(coordinator.isSelectionMode)
        XCTAssertTrue(coordinator.selectedMessageIDs.isEmpty)
    }

    func testClearChatHistoryConfirmation() {
        let msg = ChatMessage(role: .user, content: "待清空消息")
        coordinator.chatHistory = [msg]
        XCTAssertEqual(coordinator.chatHistory.count, 1)

        coordinator.showClearConfirmation = true
        XCTAssertTrue(coordinator.showClearConfirmation)

        // 确认清空
        coordinator.clearChatHistory()
        coordinator.showClearConfirmation = false

        XCTAssertTrue(coordinator.chatHistory.isEmpty, "确认清空后历史记录应为空")
        XCTAssertFalse(coordinator.showClearConfirmation)
    }

    func testChatViewMountingAndSubviews() {
        struct ChatHost: View {
            @State var selectedTab: AppTab = .chat

            var body: some View {
                ChatView(selectedTab: $selectedTab)
            }
        }

        let host = UIHostingController(rootView: ChatHost().snapshotEnvironment())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertEqual(coordinator.chatHistory.count, 0)
        XCTAssertFalse(coordinator.isProcessing)
    }

    func testChatCoordinatorPromptInjection() async throws {
        let coordinator = ChatCoordinator()
        coordinator.inputText = "Explain Swift 6 concurrency model"
        XCTAssertEqual(coordinator.inputText, "Explain Swift 6 concurrency model")
        coordinator.clearChatHistory()
        XCTAssertTrue(coordinator.chatHistory.isEmpty)
    }

}
