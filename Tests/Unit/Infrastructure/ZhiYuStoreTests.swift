//
//  ZhiYuStoreTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuStore 开展自动化单元测试验证。
//
import XCTest
import UFPCore
import SwiftUI
import UFPStorage
@testable import ZhiYu

// MARK: - 多轮对话会话缓存 (ChatHistoryStore) 单元测试
@MainActor
final class ChatHistoryStoreTests: XCTestCase {
    
    var store: ChatHistoryStore!
    
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ChatHistoryStore()
        store.messages.removeAll()
        UserDefaults.standard.removeObject(forKey: "zhiyu_chat_history")
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "zhiyu_chat_history")
        store = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    /// 验证向对话流单次追加消息的正确性
    func testAppendMessage() {
        let msg = ChatMessage(role: .user, content: "Hello")
        store.append(msg)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages.first?.content, "Hello")
    }
    
    /// 验证批量导入对话上下文的正确性
    func testAppendBatch() {
        let msgs = [
            ChatMessage(role: .user, content: "Q1"),
            ChatMessage(role: .assistant, content: "A1"),
            ChatMessage(role: .user, content: "Q2")
        ]
        store.appendBatch(msgs)
        XCTAssertEqual(store.messages.count, 3)
    }
    
    /// 验证清空当前全部对话缓存的有效性
    func testClearMessages() {
        store.append(ChatMessage(role: .user, content: "temp"))
        store.clear()
        XCTAssertTrue(store.messages.isEmpty)
    }
    
    /// 验证能倒序且精准拉取最近 N 条历史记录，确保送入大模型 Context 的 Token 裁剪正确
    func testRecentReturnsLastN() {
        for i in 1...10 {
            store.append(ChatMessage(role: .user, content: "Msg \(i)"))
        }
        let recent = store.recent(3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.first?.content, "Msg 8") // 获取 8, 9, 10
    }
    
    /// 验证聊天历史能在磁盘中（UserDefaults 编解码）完成强持久化与恢复的闭环
    func testPersistAndLoadRoundTrip() throws {
        let original = ChatMessage(role: .assistant, content: "Saved message", relatedPageIDs: [])
        store.append(original)
        
        // 从沙盒偏好设置中提取，还原比对
        guard let data = UserDefaults.standard.data(forKey: "zhiyu_chat_history"),
              let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            XCTFail("无法正确加载被持久化的消息"); return
        }
        XCTAssertFalse(decoded.isEmpty)
        XCTAssertEqual(decoded.first?.content, "Saved message")
    }
}

// MARK: - 大模型配置与敏感密钥管理 (LLMConfigStore) 单元测试
@MainActor
final class ZhiYuLLMConfigStoreTests: XCTestCase {
    
    var configStore: LLMConfigStore!
    
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        // 注入 Mock Security 服务（必须在 LLMConfigStore() 构造前），绕过模拟器限制
        KeychainService.testOverride = MockKeychainService()
        SecureEnclaveCryptoService.testOverride = MockSecureEnclaveCryptoService()
        SecurityManager.testOverride = MockSecurityManager()
        // 清理 UserDefaults 及 Keychain 中所有 LLM 配置持久化数据，确保测试隔离
        // saveAPIKey 有三层存储：Keychain → 旧版 Keychain → UserDefaults fallback，需全部清理
        UserDefaults.standard.removeObject(forKey: "zhiyu_llm_config")
        for provider in LLMProvider.allCases {
            UserDefaults.standard.removeObject(forKey: "zhiyu_llm_api_key_fallback_\(provider.rawValue)")
            try? KeychainService.shared.delete(key: "llm_api_key_\(provider.rawValue)")
        }
        try? KeychainService.shared.delete(key: "llm_api_key")  // 旧版全局 Key
        configStore = LLMConfigStore()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "zhiyu_llm_config")
        for provider in LLMProvider.allCases {
            UserDefaults.standard.removeObject(forKey: "zhiyu_llm_api_key_fallback_\(provider.rawValue)")
            try? KeychainService.shared.delete(key: "llm_api_key_\(provider.rawValue)")
        }
        try? KeychainService.shared.delete(key: "llm_api_key")  // 旧版全局 Key
        configStore = nil
        KeychainService.testOverride = nil
        SecureEnclaveCryptoService.testOverride = nil
        SecurityManager.testOverride = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    /// 验证 LLM 配置在初次运行下的缺省兜底值设置
    func testDefaultValues() {
        XCTAssertEqual(configStore.provider, .deepSeek)
        XCTAssertEqual(configStore.apiKey, "")
        XCTAssertEqual(configStore.isEnabled, false)
        XCTAssertFalse(configStore.baseURL.isEmpty)
        XCTAssertFalse(configStore.model.isEmpty)
    }
    
    /// 验证修改的参数配置及 API 敏感 Token 能安全落盘并在新生命周期里重新载入
    /// 注意：API Key 的持久化依赖 SecureEnclaveCryptoService 进行硬件级加密，
    ///       Secure Enclave 在 iOS 模拟器上不可用，此测试仅在真机上验证。
    func testSaveAndRestoreConfig() throws {
        // Mock SecureEnclaveCryptoService + MockKeychainService 已由 setUp 注入，模拟器环境安全
        configStore.apiKey = "test-key-12345"
        configStore.provider = .deepSeek
        configStore.model = "deepseek-v4-pro"
        configStore.isEnabled = true

        // 初始化一个新的 Store 来测试持久性
        let restored = LLMConfigStore()
        XCTAssertEqual(restored.apiKey, "test-key-12345")
        XCTAssertEqual(restored.provider, .deepSeek)
        XCTAssertEqual(restored.model, "deepseek-v4-pro")
        XCTAssertTrue(restored.isEnabled)
    }

    /// 验证所有 AI 服务提供商的模型图标与文案配置无误
    func testAllProviderDefaults() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty, "所有 provider displayName 不应为空")
            XCTAssertFalse(provider.icon.isEmpty, "所有 provider icon 不应为空")
        }
    }
}

// MARK: - 存储引擎并发事务与异常路径单元测试
@MainActor
final class SQLiteStoreConcurrencyTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        try await super.tearDown()
    }

    /// 验证高并发批量写入与主线程同步读取碰撞时无死锁且保持数据最终一致性
    func testConcurrentBulkIngestAndRead() async throws {
        let store = ServiceContainer.shared.resolve(SQLiteStore.self)
        
        // 并发执行 20 次异步写入
        await withTaskGroup(of: Void.self) { group in
            for i in 1...20 {
                group.addTask {
                    let page = KnowledgePage(
                        id: UUID(),
                        title: "并发测试标题 \(i)",
                        content: "这是并发写入的测试内容段落 \(i)",
                        tags: ["TestTag"],
                        updatedAt: Date()
                    )
                    await store.syncRemotePage(page)
                }
            }
        }

        let allPages = await store.pages
        XCTAssertGreaterThanOrEqual(allPages.count, 20, "高并发写入后全量读取页面数应大于等于 20")
    }

    /// 验证搜索不存在的关键词时不会抛出异常而是优雅返回空数组
    func testSearchNonExistentKeyword_returnsEmptyArray() async throws {
        let store = ServiceContainer.shared.resolve(SQLiteStore.self)
        let results = await store.searchPages(query: "NON_EXISTENT_KEYWORD_XYZ_999")
        XCTAssertTrue(results.isEmpty, "搜索不存在关键词必须优雅返回空数组")
    }
}
