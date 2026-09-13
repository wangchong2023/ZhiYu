//
//  ProtocolsAndFallbacksInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：验证领域层协议、NoOp 安全桩、DependencyKey 降级回退及数据存储加密。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ProtocolsAndFallbacksInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. VaultRepository & NoOpVaultRepository

    func testNoOpVaultRepository_allMethodsReturnSafeDefaults() async throws {
        let repo = NoOpVaultRepository()
        let vaults = try await repo.fetchAllVaults()
        XCTAssertTrue(vaults.isEmpty)

        let testVault = Vault(id: UUID(), name: "测试库")
        try await repo.saveVault(testVault)
        try await repo.updateLastAccessed(id: testVault.id)
        try await repo.deleteVault(id: testVault.id)
        try await repo.saveSetting(key: "test_key", value: "test_value")
    }

    func testVaultRepositoryKey_fallbackValues() {
        let testVal = VaultRepositoryKey.testValue
        XCTAssertNotNil(testVal)
        let previewVal = VaultRepositoryKey.previewValue
        XCTAssertNotNil(previewVal)
    }

    // MARK: - 2. RemoteConfigCapabilities & NoOpRemoteConfig

    func testNoOpRemoteConfig_returnsEmptyCollections() async throws {
        let config = NoOpRemoteConfig()
        let manifests = try await config.fetchLLMManifests()
        XCTAssertTrue(manifests.isEmpty)

        let skills = try await config.fetchAgentSkills()
        XCTAssertTrue(skills.isEmpty)
    }

    func testRemoteConfigKey_fallbackValues() {
        let testVal = RemoteConfigKey.testValue
        XCTAssertNotNil(testVal)
        let previewVal = RemoteConfigKey.previewValue
        XCTAssertNotNil(previewVal)
    }

    // MARK: - 3. SearchIndexerProtocol & UnsupportedSearchIndexer

    func testUnsupportedSearchIndexer_allMethodsNoOpSafely() {
        let indexer = UnsupportedSearchIndexer()
        let page = KnowledgePage(id: UUID(), title: "测试", pageType: .concept, content: "内容")
        indexer.indexPage(page)
        indexer.indexPages([page])
        indexer.removeIndex(for: page.id)
        indexer.deindexAll()
        indexer.reindexAll(pages: [page])
        XCTAssertNotNil(indexer)
    }

    func testSearchIndexerKey_fallbackValues() {
        let testVal = SearchIndexerKey.testValue
        XCTAssertNotNil(testVal)
        let previewVal = SearchIndexerKey.previewValue
        XCTAssertNotNil(previewVal)
    }

    // MARK: - 4. FeatureProtocols NoOp Services

    func testNoOpVaultService_allOperationsSafe() async throws {
        let service = NoOpVaultService()
        XCTAssertTrue(service.vaults.isEmpty)
        XCTAssertNil(service.selectedVaultID)
        XCTAssertNil(service.currentVault)

        let testVault = Vault(id: UUID(), name: "测试")
        try await service.selectVaultAndWait(testVault)
        await service.refreshPageCount(for: testVault.id)
        service.selectVault(testVault)
        service.exitVault()
        service.createVault(name: "新建库", icon: nil, description: nil)
        service.updateVault(id: testVault.id, name: "更新库", icon: nil, description: nil)
        service.renameVault(id: testVault.id, newName: "新名称")
        service.deleteVault(id: testVault.id)
    }

    func testNoOpAISynthesisService_returnsEmptyValues() async throws {
        let service = NoOpAISynthesisService()
        let summary = try await service.summarize(content: "长文本")
        XCTAssertEqual(summary, "")

        let mindmap = try await service.generateMindMap(content: "长文本")
        XCTAssertEqual(mindmap, "")

        let questions = try await service.generateInsightfulQuestions(pages: [])
        XCTAssertTrue(questions.isEmpty)

        let followUps = try await service.predictFollowUpQuestions(history: [], pages: [])
        XCTAssertTrue(followUps.isEmpty)
    }

    func testNoOpChatService_streamsAndMessages() async throws {
        let service = NoOpChatService()
        XCTAssertTrue(service.loadHistory().isEmpty)
        service.clearHistory()
        service.saveUserMessage("用户消息")
        service.saveAssistantMessage("助手回复")

        var received: [String] = []
        for try await chunk in service.streamChat(query: "你好", pages: []) {
            received.append(chunk)
        }
        XCTAssertTrue(received.isEmpty)
    }

    // MARK: - 5. LLM Services NoOp Implementations

    func testNoOpLLMChatService_delegations() async throws {
        let service = NoOpLLMChatService()
        XCTAssertFalse(service.isEnabled)

        let chatRes = try await service.chat(query: "你好", history: [], pages: [])
        XCTAssertEqual(chatRes.role, .assistant)
        XCTAssertEqual(chatRes.content, "")

        let genRes = try await service.generate(prompt: "P", systemPrompt: "S", maxTokens: 10)
        XCTAssertEqual(genRes, "")

        var streamChunks: [String] = []
        for try await chunk in service.chatStream(query: "流式", history: [], pages: []) {
            streamChunks.append(chunk)
        }
        XCTAssertTrue(streamChunks.isEmpty)
    }

    func testNoOpLLMKnowledgeService_methods() async throws {
        let service = NoOpLLMKnowledgeService()
        let ingestRes = try await service.smartIngest(title: "标题", rawContent: "内容", pages: [])
        XCTAssertEqual(ingestRes.title, "标题")
        XCTAssertEqual(ingestRes.compiledContent, "")

        let links = try await service.discoverPotentialLinks(content: "内容", existingTitles: ["A"])
        XCTAssertTrue(links.isEmpty)

        let folded = try await service.foldContent(existingContent: "旧内容", newContent: "新内容", title: "T")
        XCTAssertEqual(folded, "旧内容")

        let refactors = try await service.analyzeForRefactoring(pages: [])
        XCTAssertTrue(refactors.isEmpty)
    }

    func testNoOpLLMRetrievalService_methods() async throws {
        let service = NoOpLLMRetrievalService()
        let rewritten = await service.rewriteQuery("查询")
        XCTAssertEqual(rewritten, "查询")

        let expanded = await service.expandQuery("查询")
        XCTAssertTrue(expanded.isEmpty)

        let reranked = try await service.rerank(query: "Q", candidates: [])
        XCTAssertTrue(reranked.isEmpty)

        let chunks = await service.rerankChunks(query: "Q", chunks: [])
        XCTAssertTrue(chunks.isEmpty)

        let doc = await service.generateHypotheticalDocument(query: "Q")
        XCTAssertEqual(doc, "")
    }

    func testNoOpLLMService_fullDelegation() async throws {
        let service = NoOpLLMService()
        XCTAssertFalse(service.isEnabled)

        let chat = try await service.chat(query: "Q", history: [], pages: [])
        XCTAssertEqual(chat.content, "")

        let gen = try await service.generate(prompt: "P", systemPrompt: "S", maxTokens: 10)
        XCTAssertEqual(gen, "")

        let ingest = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
        XCTAssertEqual(ingest.title, "T")

        let links = try await service.discoverPotentialLinks(content: "C", existingTitles: [])
        XCTAssertTrue(links.isEmpty)

        let folded = try await service.foldContent(existingContent: "E", newContent: "N", title: "T")
        XCTAssertEqual(folded, "E")

        let refactor = try await service.analyzeForRefactoring(pages: [])
        XCTAssertTrue(refactor.isEmpty)

        let rewritten = await service.rewriteQuery("Q")
        XCTAssertEqual(rewritten, "Q")

        let expanded = await service.expandQuery("Q")
        XCTAssertTrue(expanded.isEmpty)

        let reranked = try await service.rerank(query: "Q", candidates: [])
        XCTAssertTrue(reranked.isEmpty)

        let chunks = await service.rerankChunks(query: "Q", chunks: [])
        XCTAssertTrue(chunks.isEmpty)

        let doc = await service.generateHypotheticalDocument(query: "Q")
        XCTAssertEqual(doc, "")

        var streamOut: [String] = []
        for try await chunk in service.chatStream(query: "Q", history: [], pages: []) {
            streamOut.append(chunk)
        }
        XCTAssertTrue(streamOut.isEmpty)
    }

    // MARK: - 6. PluginDataStore 加密存储与读取

    func testPluginDataStore_saveAndLoadRoundTrip() {
        let store = PluginDataStore()
        let pluginID = "com.zhiyu.test.plugin_\(UUID().uuidString)"

        store.savePluginData(pluginID: pluginID, key: "api_token", value: "secret_123")
        let loaded = store.loadPluginData(pluginID: pluginID, key: "api_token")
        XCTAssertEqual(loaded, "secret_123")

        let nonExistent = store.loadPluginData(pluginID: pluginID, key: "non_existent")
        XCTAssertNil(nonExistent)

        let allData = store.loadAllPluginData(pluginID: pluginID)
        XCTAssertEqual(allData["api_token"], "secret_123")
    }
}
