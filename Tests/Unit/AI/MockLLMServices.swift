//
//  MockLLMServices.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：为单元测试提供 MockLLMServices 仿真服务占位。
//
import Foundation
@preconcurrency import Combine
@testable import ZhiYu

@MainActor
final class MockChatLLMService: LLMChatServiceProtocol, @unchecked Sendable {
    var isEnabled: Bool = true
    
    var generateCallCount = 0
    var chatCallCount = 0
    var chatStreamCallCount = 0
    
    var stubGenerateResult = "Mock Generated Result"
    var stubChatResult = ChatMessageDTO(id: UUID(), role: .assistant, content: "Mock Chat Result", timestamp: Date(), relatedPageIDs: [])
    
    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        chatCallCount += 1
        return stubChatResult
    }
    
    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        chatStreamCallCount += 1
        return AsyncThrowingStream { continuation in
            continuation.yield("Mock ")
            continuation.yield("Stream ")
            continuation.yield("Result")
            continuation.finish()
        }
    }
    
    func generate(prompt: String, systemPrompt: String, maxTokens: Int = PromptConstants.TokenLimits.defaultMaxOutputTokens) async throws -> String {
        generateCallCount += 1
        return stubGenerateResult
    }
}

@MainActor
final class MockKnowledgeLLMService: LLMKnowledgeServiceProtocol, ObservableObject, @unchecked Sendable {
    var smartIngestCallCount = 0
    var discoverCallCount = 0
    var foldCallCount = 0
    var analyzeCallCount = 0
    
    var stubSmartIngestResult = SmartIngestResultDTO(title: "Mock Title", compiledContent: "Mock Content", suggestedTags: ["mock"], suggestedType: "doc", relatedTitles: [], summary: "Mock Summary")
    var stubDiscoverResult = ["Mock Link 1", "Mock Link 2"]
    var stubFoldResult = "Mock Folded Content"
    var stubAnalyzeResult = [RefactorSuggestionDTO(type: "merge", target: "Mock Target", reason: "Mock Reason", suggestion: "Merge them")]
    
    func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        smartIngestCallCount += 1
        return stubSmartIngestResult
    }
    
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] {
        discoverCallCount += 1
        return stubDiscoverResult
    }
    
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String {
        foldCallCount += 1
        return stubFoldResult
    }
    
    func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] {
        analyzeCallCount += 1
        return stubAnalyzeResult
    }
}

@MainActor
final class MockRetrievalLLMService: LLMRetrievalServiceProtocol, ObservableObject, @unchecked Sendable {
    var rewriteCallCount = 0
    var expandCallCount = 0
    var rerankCallCount = 0
    var rerankChunksCallCount = 0
    var generateHypotheticalCallCount = 0
    
    var stubRewriteResult = "Mock Rewritten Query"
    var stubExpandResult = ["Expand 1", "Expand 2"]
    var stubRerankResult: [any KnowledgePageRepresentable] = []
    var stubRerankChunksResult: [PageChunk] = []
    var stubGenerateHypotheticalResult = "Mock Hypothetical Document"
    
    func rewriteQuery(_ query: String) async -> String {
        rewriteCallCount += 1
        return stubRewriteResult
    }
    
    func expandQuery(_ query: String) async -> [String] {
        expandCallCount += 1
        return stubExpandResult
    }
    
    func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] {
        rerankCallCount += 1
        return stubRerankResult
    }
    
    func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] {
        rerankChunksCallCount += 1
        return stubRerankChunksResult
    }
    
    func generateHypotheticalDocument(query: String) async -> String {
        generateHypotheticalCallCount += 1
        return stubGenerateHypotheticalResult
    }
}
