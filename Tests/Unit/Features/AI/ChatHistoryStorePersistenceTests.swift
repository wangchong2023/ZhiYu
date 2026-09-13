//
//  ChatHistoryStorePersistenceTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - AI
//  核心职责：验证 ChatHistoryStore 追加消息与清空会话在 UserDefaults 中的持久化与跨实例恢复。
//

import XCTest
@testable import ZhiYu

final class ChatHistoryStorePersistenceTests: XCTestCase {

    /// 验证 ChatHistoryStore.append 持久化到 UserDefaults 并在重载后正确恢复
    func testAppend_newMessage_persistsToUserDefaults() {
        let key = LLMConstants.ChatHistory.storageKey

        UserDefaults.standard.removeObject(forKey: key)
        let freshStore = ChatHistoryStore()
        freshStore.clear()
        XCTAssertTrue(freshStore.messages.isEmpty, "清空后应无消息")

        let message = ChatMessageDTO(
            id: UUID(),
            role: .user,
            content: "Persistence test message"
        )
        freshStore.append(message)

        let data = UserDefaults.standard.data(forKey: key)
        XCTAssertNotNil(data, "append 后应持久化到 UserDefaults")

        let reloadStore = ChatHistoryStore()
        XCTAssertEqual(reloadStore.messages.count, 1, "重新加载应能恢复 1 条消息")
        XCTAssertEqual(reloadStore.messages.first?.content, "Persistence test message")

        UserDefaults.standard.removeObject(forKey: key)
    }

    /// 验证 ChatHistoryStore.clear 正确持久化空状态到 UserDefaults
    func testClear_messages_persistsEmptyStateToUserDefaults() {
        let key = LLMConstants.ChatHistory.storageKey
        UserDefaults.standard.removeObject(forKey: key)

        let store = ChatHistoryStore()
        store.append(ChatMessageDTO(role: .user, content: "msg1"))
        XCTAssertEqual(store.messages.count, 1)

        store.clear()
        let data = UserDefaults.standard.data(forKey: key)
        XCTAssertNotNil(data, "clear 后应持久化空数组到 UserDefaults")

        let reloadStore = ChatHistoryStore()
        XCTAssertTrue(reloadStore.messages.isEmpty, "clear 后重新加载应为空")

        UserDefaults.standard.removeObject(forKey: key)
    }
}
