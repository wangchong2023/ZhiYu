//
//  ChatHistoryStoreTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 ChatHistoryStore 的追加、批量追加、清除、持久化与最近消息查询
//

import XCTest
@testable import ZhiYu

final class ChatHistoryStorePersistenceTests: XCTestCase {

    private let historyKey = LLMConstants.ChatHistory.storageKey

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: historyKey)
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
        XCTAssertTrue(UserDefaults.standard.data(forKey: historyKey) != nil)
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
        UserDefaults.standard.removeObject(forKey: historyKey)
        let store = ChatHistoryStore()
        XCTAssertTrue(store.messages.isEmpty)
    }

    // MARK: - persistToDisk

    func testPersistToDiskWritesValidJSON() {
        let store = ChatHistoryStore()
        store.clear()
        store.append(ChatMessageDTO(role: .user, content: "JSON test"))
        guard let data = UserDefaults.standard.data(forKey: historyKey) else {
            XCTFail("应写入 UserDefaults")
            return
        }
        let decoded = try? JSONDecoder().decode([ChatMessageDTO].self, from: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.count, 1)
        XCTAssertEqual(decoded?.first?.content, "JSON test")
    }
}
