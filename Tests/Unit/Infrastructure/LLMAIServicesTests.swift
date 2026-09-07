//
//  LLMAIServicesTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LLMAIServices 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

// MARK: - Mock LLM Client
final class MockLLMClient: LLMClientProtocol, @unchecked Sendable {
    var mockResponse: [String: Any] = [:]
    var mockError: Error?
    var lastBody: [String: Any]?

    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        lastBody = body
        if let error = mockError { throw error }
        return mockResponse
    }

    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
        fatalError("Not implemented")
    }
}

final class LLMAIServicesTests: XCTestCase {
    
    var mockClient: MockLLMClient!
    var contextBuilder: LLMContextBuilder!
    
    override func setUp() {
        super.setUp()
        mockClient = MockLLMClient()
        contextBuilder = LLMContextBuilder()
    }
    
    // MARK: - Ingest Service Tests
    
    func testSmartIngest() async throws {
        let service = LLMIngestService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        
        // 模拟 AI 返回的结构化 JSON
        let jsonResponse = """
        {
            "compiled_content": "Compiled content",
            "suggested_tags": ["tag1", "tag2"],
            "suggested_type": "concept",
            "related_titles": ["Rel1"],
            "summary": "Summary text"
        }
        """
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": jsonResponse]
            ]]
        ]
        
        let result = try await service.smartIngest(title: "Test", rawContent: "Raw", pages: [])
        
        XCTAssertEqual(result.compiledContent, "Compiled content")
        XCTAssertEqual(result.suggestedTags, ["tag1", "tag2"])
        XCTAssertEqual(result.summary, "Summary text")
    }
    
    // MARK: - Retrieval Service Tests
    
    func testRewriteQuery() async {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "Optimized Query"]
            ]]
        ]
        
        let rewritten = await service.rewriteQuery("Natural query")
        XCTAssertEqual(rewritten, "Optimized Query")
    }
    
    func testRerank() async throws {
        let service = LLMRetrievalService(client: mockClient, model: "gpt-4o", contextBuilder: contextBuilder)
        
        let page1 = KnowledgePage(title: "Page 1", pageType: .concept, content: "C1")
        let page2 = KnowledgePage(title: "Page 2", pageType: .concept, content: "C2")
        let candidates = [page1, page2]
        
        // 模拟返回排序后的 ID 数组
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[\"\(page2.id.uuidString)\", \"\(page1.id.uuidString)\"]"]
            ]]
        ]
        
        let ranked = try await service.rerank(query: "Test", candidates: candidates)
        
        XCTAssertEqual(ranked.first?.id, page2.id)
        XCTAssertEqual(ranked.last?.id, page1.id)
    }
    
    // MARK: - Refactor Service Tests
    
    func testDiscoverPotentialLinks() async throws {
        let service = LLMRefactorService(client: mockClient, model: "gpt-4o")
        
        mockClient.mockResponse = [
            "choices": [[
                "message": ["content": "[\"Link1\", \"Link2\"]"]
            ]]
        ]
        
        let links = try await service.discoverPotentialLinks(content: "Content", existingTitles: ["Link1", "Link2"])
        XCTAssertEqual(links, ["Link1", "Link2"])
    }
    
    // MARK: - LLMConfigStore 安全存储测试（VULN-008 修复后）
    
    /// 验证 VULN-008 修复：API 密钥仅通过 Keychain 加密存储，UserDefaults 中不得保留任何明文或密文备份。
    /// 使用 MockKeychainService + MockSecureEnclaveCryptoService 避免模拟器 Keychain -34018 环境问题。
    @MainActor
    func testLLMConfigStoreFallback() throws {
        let testProvider = LLMProvider.deepSeek
        let testKey = "sk-test-fallback-key-123456"
        let keychainKey = "llm_api_key_\(testProvider.rawValue)"
        let fallbackKey = "zhiyu_llm_api_key_fallback_\(testProvider.rawValue)"
        
        // 注入 Mock 服务，绕过模拟器 Keychain entitlement 限制
        let mockKeychain = MockKeychainService()
        let mockCrypto = MockSecureEnclaveCryptoService()
        KeychainService.testOverride = mockKeychain
        SecureEnclaveCryptoService.testOverride = mockCrypto
        defer {
            KeychainService.testOverride = nil
            SecureEnclaveCryptoService.testOverride = nil
        }
        
        // 清理残留
        UserDefaults.standard.removeObject(forKey: fallbackKey)
        try? mockKeychain.delete(key: keychainKey)
        
        let store = LLMConfigStore()
        store.provider = testProvider
        store.apiKey = testKey
        
        XCTAssertEqual(store.apiKey, testKey, "内存中的 API 密钥应立即更新")
        
        // VULN-008 核心断言：UserDefaults 中不得存在任何 API 密钥备份
        XCTAssertNil(UserDefaults.standard.string(forKey: fallbackKey),
                     "VULN-008: UserDefaults 中不得保留 API 密钥的任何备份形式")
        
        // 验证 Keychain 中存有密钥（Mock 为直通，非真实加密）
        let storedValue = try? mockKeychain.retrieve(key: keychainKey)
        XCTAssertNotNil(storedValue, "API 密钥应已存入 Keychain")
        XCTAssertEqual(storedValue, testKey, "API 密钥应物理写入 Keychain 存储区")
        
        // 验证解密后能还原原始密钥
        if let encrypted = storedValue,
           let decrypted = try? mockCrypto.decrypt(encrypted) {
            XCTAssertEqual(decrypted, testKey, "Keychain 加密密钥解密后应与原始 Key 完全一致")
        }
        
        // 验证重新实例化后能从 Keychain 恢复
        let secondStore = LLMConfigStore()
        secondStore.provider = testProvider
        XCTAssertEqual(secondStore.apiKey, testKey, "重新实例化后应能通过 Keychain 恢复 API 密钥")
        
        // 清空密钥后验证 Keychain 和 UserDefaults 均无残留
        store.apiKey = ""
        XCTAssertNil(try? mockKeychain.retrieve(key: keychainKey),
                     "清空密钥后 Keychain 不得有任何残留")
        XCTAssertNil(UserDefaults.standard.string(forKey: fallbackKey),
                     "清空密钥后 UserDefaults 不得有任何残留")
    }
}
