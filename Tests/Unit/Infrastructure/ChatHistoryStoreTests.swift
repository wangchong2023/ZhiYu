//
//  ChatHistoryStoreTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 ChatHistoryStore 的追加、批量追加、清除、持久化与最近消息查询
//

import XCTest
import UFPCore
@testable import ZhiYu

final class ChatHistoryStoreLifecycleTests: XCTestCase {

    private let historyKey = LLMConstants.ChatHistory.storageKey

    /// 与 ChatHistoryStore 的 @Dependency(\.keyStore) 使用同一存储实例，
    /// 避免穿透抽象层直接读 UserDefaults.standard 导致存储实例不一致
    private var keyStore: (any KeyStoreProtocol)? {
        ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) ?? UserDefaultsKeyStore.shared
    }

    override func setUp() {
        super.setUp()
        keyStore?.removeObject(forKey: historyKey)
    }

    override func tearDown() {
        keyStore?.removeObject(forKey: historyKey)
        super.tearDown()
    }

    // MARK: - append

    func testAppendAddsMessageToList() {
        let store = ChatHistoryStore()
        store.clear()
        let message = ChatMessageDTO(role: .user, content: "Hello")
        store.append(message)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages.first?.content, "Hello")
    }

    func testAppendPersistsToDisk() {
        let store = ChatHistoryStore()
        store.clear()
        store.append(ChatMessageDTO(role: .user, content: "Persisted"))
        XCTAssertNotNil(keyStore?.data(forKey: historyKey))
    }

    // MARK: - appendBatch

    func testAppendBatchAddsMultipleMessages() {
        let store = ChatHistoryStore()
        store.clear()
        let batch = [
            ChatMessageDTO(role: .user, content: "Q1"),
            ChatMessageDTO(role: .assistant, content: "A1"),
            ChatMessageDTO(role: .user, content: "Q2")
        ]
        store.appendBatch(batch)
        XCTAssertEqual(store.messages.count, 3)
        XCTAssertEqual(store.messages[0].content, "Q1")
        XCTAssertEqual(store.messages[1].content, "A1")
        XCTAssertEqual(store.messages[2].content, "Q2")
    }

    // MARK: - clear

    func testClearRemovesAllMessages() {
        let store = ChatHistoryStore()
        store.append(ChatMessageDTO(role: .user, content: "X"))
        store.append(ChatMessageDTO(role: .user, content: "Y"))
        store.clear()
        XCTAssertTrue(store.messages.isEmpty)
    }

    // MARK: - recent

    func testRecentReturnsLastNMessages() {
        let store = ChatHistoryStore()
        store.clear()
        for i in 0..<5 {
            store.append(ChatMessageDTO(role: .user, content: "Msg\(i)"))
        }
        let recent = store.recent(3)
        XCTAssertEqual(recent.count, 3)
        let contents = recent.map(\.content)
        XCTAssertEqual(contents, ["Msg2", "Msg3", "Msg4"])
    }

    func testRecentReturnsAllWhenCountExceedsSize() {
        let store = ChatHistoryStore()
        store.clear()
        store.append(ChatMessageDTO(role: .user, content: "Only"))
        let recent = store.recent(10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.content, "Only")
    }

    // MARK: - 持久化往返

    func testLoadRestoresPersistedMessages() {
        let store1 = ChatHistoryStore()
        store1.clear()
        store1.append(ChatMessageDTO(role: .user, content: "Saved"))
        store1.append(ChatMessageDTO(role: .assistant, content: "Reply"))

        let store2 = ChatHistoryStore()
        XCTAssertEqual(store2.messages.count, 2)
        XCTAssertEqual(store2.messages[0].content, "Saved")
        XCTAssertEqual(store2.messages[1].content, "Reply")
    }

    func testLoadWithEmptyStorageReturnsEmpty() {
        keyStore?.removeObject(forKey: historyKey)
        let store = ChatHistoryStore()
        XCTAssertTrue(store.messages.isEmpty)
    }

    // MARK: - persistToDisk

    func testPersistToDiskWritesValidJSON() {
        let store = ChatHistoryStore()
        store.clear()
        store.append(ChatMessageDTO(role: .user, content: "JSON test"))
        guard let data = keyStore?.data(forKey: historyKey) else {
            XCTFail("应写入 keyStore")
            return
        }
        let decoded = try? JSONDecoder().decode([ChatMessageDTO].self, from: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 1)
        XCTAssertEqual(decoded?.first?.content, "JSON test")
    }
}
