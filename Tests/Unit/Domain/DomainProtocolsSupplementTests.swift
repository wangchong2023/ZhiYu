//
//  DomainProtocolsSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Domain/Protocols 下 18 个 NoOp/Stub/Unsupported 默认实现
//           返回安全默认值（空/false/nil/throw），不崩溃。
//

import XCTest
import UFPCore
@testable import ZhiYu

/// Domain/Protocols NoOp/Stub 实现补盲测试
///
/// 覆盖 18 个 NoOp/Stub/Unsupported 类：
/// - LLMServiceProtocol: NoOpLLMChatService/NoOpLLMKnowledgeService/NoOpLLMRetrievalService/NoOpLLMService
/// - KnowledgeRepository: NoOpKnowledgeRepository
/// - EmbeddingProvider: NoOpEmbeddingProvider
/// - ImportFileStore: NoOpImportFileStore
/// - ImportRecordRepository: NoOpImportRecordRepository
/// - ModelDownloadCapabilities: NoOpModelDownload
/// - RAGGovernanceRepository: NoOpRAGGovernanceRepository
/// - StoreCapabilities: NoOpPageStoreCapabilities
/// - IngestServiceProtocol: NoOpIngestService
/// - FeedbackRepository: NoOpFeedbackRepository
/// - FeatureProtocols: NoOpVaultService/NoOpChatService
/// - SpeechServiceProtocol: NoOpSpeechService
/// - PDFServiceProtocol: NoOpPDFService
/// - SearchIndexerProtocol: UnsupportedSearchIndexer
@MainActor
final class DomainProtocolsSupplementTests: XCTestCase {

    // MARK: - NoOpLLMChatService

    /// NoOpLLMChatService 应返回安全默认值
    func testNoOpLLMChatService_返回安全默认值() async throws {
        let service = NoOpLLMChatService()
        XCTAssertFalse(service.isEnabled, "NoOp isEnabled 应为 false")
        let chat = try await service.chat(query: "test", history: [], pages: [])
        XCTAssertEqual(chat.content, "", "NoOp chat 应返回空内容")
        let generated = try await service.generate(prompt: "test", systemPrompt: "test", maxTokens: 100)
        XCTAssertEqual(generated, "", "NoOp generate 应返回空字符串")
    }

    /// NoOpLLMChatService chatStream 应立即 finish
    func testNoOpLLMChatService_chatStream_立即finish() async throws {
        let service = NoOpLLMChatService()
        let stream = service.chatStream(query: "test", history: [], pages: [])
        var count = 0
        for try await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0, "NoOp chatStream 应不产生任何 chunk")
    }

    // MARK: - NoOpLLMKnowledgeService

    /// NoOpLLMKnowledgeService smartIngest 应保留 title 返回空内容
    func testNoOpLLMKnowledgeService_smartIngest_保留title() async throws {
        let service = await NoOpLLMKnowledgeService()
        let result = try await service.smartIngest(title: "test", rawContent: "content", pages: [])
        XCTAssertEqual(result.title, "test", "NoOp smartIngest 应保留 title")
        XCTAssertEqual(result.compiledContent, "", "NoOp smartIngest 应返回空内容")
        XCTAssertTrue(result.suggestedTags.isEmpty, "NoOp smartIngest 应返回空标签")
    }

    /// NoOpLLMKnowledgeService discoverPotentialLinks 应返回空数组
    func testNoOpLLMKnowledgeService_discoverPotentialLinks_返回空数组() async throws {
        let service = await NoOpLLMKnowledgeService()
        let links = try await service.discoverPotentialLinks(content: "test", existingTitles: [])
        XCTAssertTrue(links.isEmpty, "NoOp discoverPotentialLinks 应返回空数组")
    }

    /// NoOpLLMKnowledgeService foldContent 应返回 existingContent
    func testNoOpLLMKnowledgeService_foldContent_返回existingContent() async throws {
        let service = await NoOpLLMKnowledgeService()
        let folded = try await service.foldContent(existingContent: "old", newContent: "new", title: "test")
        XCTAssertEqual(folded, "old", "NoOp foldContent 应返回 existingContent")
    }

    /// NoOpLLMKnowledgeService analyzeForRefactoring 应返回空数组
    func testNoOpLLMKnowledgeService_analyzeForRefactoring_返回空数组() async throws {
        let service = await NoOpLLMKnowledgeService()
        let suggestions = try await service.analyzeForRefactoring(pages: [])
        XCTAssertTrue(suggestions.isEmpty, "NoOp analyzeForRefactoring 应返回空数组")
    }

    // MARK: - NoOpLLMRetrievalService

    /// NoOpLLMRetrievalService rewriteQuery 应返回原 query
    func testNoOpLLMRetrievalService_rewriteQuery_返回原query() async {
        let service = await NoOpLLMRetrievalService()
        let rewritten = await service.rewriteQuery("test")
        XCTAssertEqual(rewritten, "test", "NoOp rewriteQuery 应返回原 query")
    }

    /// NoOpLLMRetrievalService expandQuery 应返回空数组
    func testNoOpLLMRetrievalService_expandQuery_返回空数组() async {
        let service = await NoOpLLMRetrievalService()
        let expanded = await service.expandQuery("test")
        XCTAssertTrue(expanded.isEmpty, "NoOp expandQuery 应返回空数组")
    }

    /// NoOpLLMRetrievalService rerank 应原样返回 candidates
    func testNoOpLLMRetrievalService_rerank_原样返回candidates() async throws {
        let service = await NoOpLLMRetrievalService()
        let reranked = try await service.rerank(query: "test", candidates: [])
        XCTAssertTrue(reranked.isEmpty, "NoOp rerank 空输入应返回空数组")
    }
    /// NoOpLLMRetrievalService generateHypotheticalDocument 应返回空字符串
    func testNoOpLLMRetrievalService_generateHypotheticalDocument_返回空字符串() async {
        let service = await NoOpLLMRetrievalService()
        let hyde = await service.generateHypotheticalDocument(query: "test")
        XCTAssertEqual(hyde, "", "NoOp generateHypotheticalDocument 应返回空字符串")
    }

    // MARK: - NoOpLLMService

    /// NoOpLLMService 应返回安全默认值
    func testNoOpLLMService_返回安全默认值() async throws {
        let service = await NoOpLLMService()
        XCTAssertFalse(service.isEnabled, "NoOp isEnabled 应为 false")
        XCTAssertEqual(service.apiKey, "", "NoOp apiKey 应为空")
        XCTAssertEqual(service.baseURL, "", "NoOp baseURL 应为空")
        XCTAssertEqual(service.model, "", "NoOp model 应为空")
        XCTAssertFalse(service.autoScan, "NoOp autoScan 应为 false")
        XCTAssertFalse(service.autoRefactor, "NoOp autoRefactor 应为 false")
    }

    /// NoOpLLMService chat 应返回空内容
    func testNoOpLLMService_chat_返回空内容() async throws {
        let service = await NoOpLLMService()
        let chat = try await service.chat(query: "test", history: [], pages: [])
        XCTAssertEqual(chat.content, "", "NoOpLLMService chat 应返回空内容")
    }

    /// NoOpLLMService chatStream 应立即 finish
    func testNoOpLLMService_chatStream_立即finish() async throws {
        let service = await NoOpLLMService()
        let stream = service.chatStream(query: "test", history: [], pages: [])
        var count = 0
        for try await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0, "NoOpLLMService chatStream 应不产生任何 chunk")
    }

    /// NoOpLLMService smartIngest 应保留 title
    func testNoOpLLMService_smartIngest_保留title() async throws {
        let service = await NoOpLLMService()
        let result = try await service.smartIngest(title: "test", rawContent: "content", pages: [])
        XCTAssertEqual(result.title, "test")
    }

    /// NoOpLLMService rewriteQuery 应返回原 query
    func testNoOpLLMService_rewriteQuery_返回原query() async {
        let service = await NoOpLLMService()
        let rewritten = await service.rewriteQuery("test")
        XCTAssertEqual(rewritten, "test")
    }

    // MARK: - NoOpKnowledgeRepository

    /// NoOpKnowledgeRepository fetchAll 应返回空数组
    func testNoOpKnowledgeRepository_fetchAll_返回空数组() async throws {
        let repo = NoOpKnowledgeRepository()
        let pages = try await repo.fetchAll()
        XCTAssertTrue(pages.isEmpty)
    }

    /// NoOpKnowledgeRepository fetch 应返回 nil
    func testNoOpKnowledgeRepository_fetch_返回nil() async throws {
        let repo = NoOpKnowledgeRepository()
        let page = try await repo.fetch(id: UUID())
        XCTAssertNil(page)
    }

    /// NoOpKnowledgeRepository save/delete 应不崩溃
    func testNoOpKnowledgeRepository_saveDelete_不崩溃() async throws {
        let repo = NoOpKnowledgeRepository()
        try await repo.save(KnowledgePage(title: "test", pageType: .concept, content: ""))
        try await repo.delete(id: UUID())
        // 不崩溃即通过
    }

    /// NoOpKnowledgeRepository search 应返回空数组
    func testNoOpKnowledgeRepository_search_返回空数组() async throws {
        let repo = NoOpKnowledgeRepository()
        let results = try await repo.search(query: "test")
        XCTAssertTrue(results.isEmpty)
    }

    /// NoOpKnowledgeRepository fetchBacklinks 应返回空数组
    func testNoOpKnowledgeRepository_fetchBacklinks_返回空数组() async throws {
        let repo = NoOpKnowledgeRepository()
        let backlinks = try await repo.fetchBacklinks(for: UUID())
        XCTAssertTrue(backlinks.isEmpty)
    }

    /// NoOpKnowledgeRepository count 应返回 0
    func testNoOpKnowledgeRepository_count_返回0() async throws {
        let repo = NoOpKnowledgeRepository()
        let count = try await repo.count()
        XCTAssertEqual(count, 0)
    }

    /// NoOpKnowledgeRepository renameTag/deleteTag 应不崩溃
    func testNoOpKnowledgeRepository_tagOperations_不崩溃() async throws {
        let repo = NoOpKnowledgeRepository()
        try await repo.renameTag(old: "old", to: "new")
        try await repo.deleteTag("tag")
        // 不崩溃即通过
    }

    // MARK: - NoOpEmbeddingProvider

    /// NoOpEmbeddingProvider getAllEmbeddings 应返回空字典
    func testNoOpEmbeddingProvider_getAllEmbeddings_返回空字典() async {
        let provider = NoOpEmbeddingProvider()
        let embeddings = await provider.getAllEmbeddings()
        XCTAssertTrue(embeddings.isEmpty)
    }

    /// NoOpEmbeddingProvider vectorizeChunks 应返回空数组
    func testNoOpEmbeddingProvider_vectorizeChunks_返回空数组() async {
        let provider = NoOpEmbeddingProvider()
        let vectors = await provider.vectorizeChunks(chunks: ["test"])
        XCTAssertTrue(vectors.isEmpty)
    }

    /// NoOpEmbeddingProvider search 应返回空数组
    func testNoOpEmbeddingProvider_search_返回空数组() async {
        let provider = NoOpEmbeddingProvider()
        let results = await provider.search(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// NoOpEmbeddingProvider multiQuerySearch 应返回空数组
    func testNoOpEmbeddingProvider_multiQuerySearch_返回空数组() async {
        let provider = NoOpEmbeddingProvider()
        let results = await provider.multiQuerySearch(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// NoOpEmbeddingProvider hydeSearch 应返回空数组
    func testNoOpEmbeddingProvider_hydeSearch_返回空数组() async {
        let provider = NoOpEmbeddingProvider()
        let results = await provider.hydeSearch(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// NoOpEmbeddingProvider advancedSearch 应返回空数组
    func testNoOpEmbeddingProvider_advancedSearch_返回空数组() async {
        let provider = NoOpEmbeddingProvider()
        let results = await provider.advancedSearch(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// NoOpEmbeddingProvider updateEmbedding/indexChunks/syncEmbeddings 应不崩溃
    func testNoOpEmbeddingProvider_updateAndSync_不崩溃() async {
        let provider = NoOpEmbeddingProvider()
        let page = KnowledgePage(title: "test", pageType: .concept, content: "content")
        await provider.updateEmbedding(for: page)
        await provider.indexChunks(pageID: UUID(), chunks: [])
        await provider.syncEmbeddings(pages: [page])
        // 不崩溃即通过
    }

    /// NoOpEmbeddingProvider loadInitialCache/clearCacheAndReload 应不崩溃
    func testNoOpEmbeddingProvider_cacheOperations_不崩溃() async {
        let provider = NoOpEmbeddingProvider()
        await provider.loadInitialCache()
        await provider.clearCacheAndReload()
        // 不崩溃即通过
    }

    // MARK: - NoOpImportFileStore

    /// NoOpImportFileStore saveContent 应返回 nil
    func testNoOpImportFileStore_saveContent_返回nil() {
        let store = NoOpImportFileStore()
        let result = store.saveContent("test", category: .file, ext: "pdf")
        XCTAssertNil(result)
    }

    /// NoOpImportFileStore saveData 应返回 nil
    func testNoOpImportFileStore_saveData_返回nil() {
        let store = NoOpImportFileStore()
        let result = store.saveData(Data(), category: .file, ext: "pdf")
        XCTAssertNil(result)
    }

    /// NoOpImportFileStore copyFile 应返回 nil
    func testNoOpImportFileStore_copyFile_返回nil() {
        let store = NoOpImportFileStore()
        let result = store.copyFile(at: URL(fileURLWithPath: "/tmp/test"), category: .file)
        XCTAssertNil(result)
    }

    // MARK: - NoOpImportRecordRepository

    /// NoOpImportRecordRepository fetchAll 应返回空数组
    func testNoOpImportRecordRepository_fetchAll_返回空数组() async throws {
        let repo = NoOpImportRecordRepository()
        let records = try await repo.fetchAll(category: nil, limit: 10)
        XCTAssertTrue(records.isEmpty)
    }

    /// NoOpImportRecordRepository fetchByID 应返回 nil
    func testNoOpImportRecordRepository_fetchByID_返回nil() async throws {
        let repo = NoOpImportRecordRepository()
        let record = try await repo.fetchByID("test")
        XCTAssertNil(record)
    }

    /// NoOpImportRecordRepository fetchInProgress 应返回空数组
    func testNoOpImportRecordRepository_fetchInProgress_返回空数组() async throws {
        let repo = NoOpImportRecordRepository()
        let records = try await repo.fetchInProgress()
        XCTAssertTrue(records.isEmpty)
    }

    /// NoOpImportRecordRepository totalStorageSize 应返回 0
    func testNoOpImportRecordRepository_totalStorageSize_返回0() async throws {
        let repo = NoOpImportRecordRepository()
        let size = try await repo.totalStorageSize()
        XCTAssertEqual(size, 0)
    }

    /// NoOpImportRecordRepository save/update 操作应不崩溃
    func testNoOpImportRecordRepository_saveUpdate_不崩溃() async throws {
        let repo = NoOpImportRecordRepository()
        let record = ImportRecord(
            id: "test", category: "file", title: "test.pdf",
            status: "pending", createdAt: Date()
        )
        try await repo.save(record)
        try await repo.updateStatus(id: "test", status: "completed", completedAt: Date())
        try await repo.updatePageID(id: "test", pageID: UUID().uuidString)
        try await repo.updateRawText(id: "test", rawText: "text")
        try await repo.updateTags(id: "test", tags: "tag1,tag2")
        // 不崩溃即通过
    }

    // MARK: - NoOpModelDownload

    /// NoOpModelDownload startDownload 应不崩溃
    func testNoOpModelDownload_startDownload_不崩溃() async throws {
        let download = NoOpModelDownload()
        try await download.startDownload(modelId: "test", remoteURL: URL(string: "https://example.com")!)
        // 不崩溃即通过
    }

    /// NoOpModelDownload pause/resume/cancel 应不崩溃
    func testNoOpModelDownload_pauseResumeCancel_不崩溃() async throws {
        let download = NoOpModelDownload()
        try await download.pauseDownload(modelId: "test")
        try await download.resumeDownload(modelId: "test")
        try await download.cancelDownload(modelId: "test")
        // 不崩溃即通过
    }

    /// NoOpModelDownload observeDownloadState 应返回空流
    func testNoOpModelDownload_observeDownloadState_空流() async {
        let download = NoOpModelDownload()
        let stream = await download.observeDownloadState(for: "test")
        var count = 0
        for await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0, "NoOp observeDownloadState 应不产生任何事件")
    }

    // MARK: - NoOpRAGGovernanceRepository

    /// NoOpRAGGovernanceRepository fetchTokenStats 应返回零统计
    func testNoOpRAGGovernanceRepository_fetchTokenStats_零统计() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let stats = try await repo.fetchTokenStats(days: 7)
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.prompt, 0)
        XCTAssertEqual(stats.completion, 0)
    }

    /// NoOpRAGGovernanceRepository fetchDailyAIStats 应返回空数组
    func testNoOpRAGGovernanceRepository_fetchDailyAIStats_空数组() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let stats = try await repo.fetchDailyAIStats(days: 7)
        XCTAssertTrue(stats.isEmpty)
    }

    /// NoOpRAGGovernanceRepository fetchRecentLogs 应返回空数组
    func testNoOpRAGGovernanceRepository_fetchRecentLogs_空数组() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let logs = try await repo.fetchRecentLogs(limit: 10)
        XCTAssertTrue(logs.isEmpty)
    }

    /// NoOpRAGGovernanceRepository fetchRAGEvaluations 应返回空数组
    func testNoOpRAGGovernanceRepository_fetchRAGEvaluations_空数组() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let evals = try await repo.fetchRAGEvaluations(limit: 10)
        XCTAssertTrue(evals.isEmpty)
    }

    /// NoOpRAGGovernanceRepository calculateAverageRAGScores 应返回全零评分
    func testNoOpRAGGovernanceRepository_calculateAverageRAGScores_全零() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let scores = try await repo.calculateAverageRAGScores(days: 7)
        XCTAssertEqual(scores.faithfulness, 0)
        XCTAssertEqual(scores.relevance, 0)
        XCTAssertEqual(scores.precision, 0)
        XCTAssertEqual(scores.hallucinationRate, 0)
        XCTAssertEqual(scores.citationAccuracy, 0)
    }

    /// NoOpRAGGovernanceRepository 检索指标应返回 0
    func testNoOpRAGGovernanceRepository_retrievalMetrics_返回0() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let hitRate = try await repo.calculateHitRate(days: 7, k: 5)
        let mrr = try await repo.calculateMRR(days: 7)
        let ndcg = try await repo.calculateNDCG(days: 7, k: 5)
        let recall = try await repo.calculateRecall(days: 7, k: 5)
        let f1 = try await repo.calculateF1Score(days: 7, k: 5)
        let map = try await repo.calculateMAP(days: 7)
        XCTAssertEqual(hitRate, 0)
        XCTAssertEqual(mrr, 0)
        XCTAssertEqual(ndcg, 0)
        XCTAssertEqual(recall, 0)
        XCTAssertEqual(f1, 0)
        XCTAssertEqual(map, 0)
    }

    /// NoOpRAGGovernanceRepository calculateRetrievalLatency 应返回全零
    func testNoOpRAGGovernanceRepository_calculateRetrievalLatency_全零() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let latency = try await repo.calculateRetrievalLatency(days: 7)
        XCTAssertEqual(latency.p50, 0)
        XCTAssertEqual(latency.p95, 0)
        XCTAssertEqual(latency.p99, 0)
        XCTAssertEqual(latency.sampleCount, 0)
    }

    /// NoOpRAGGovernanceRepository calculateTokenEfficiency 应返回全零
    func testNoOpRAGGovernanceRepository_calculateTokenEfficiency_全零() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let efficiency = try await repo.calculateTokenEfficiency(days: 7)
        XCTAssertEqual(efficiency.totalTokens, 0)
        XCTAssertEqual(efficiency.queryCount, 0)
        XCTAssertEqual(efficiency.avgTokensPerQuery, 0)
        XCTAssertEqual(efficiency.estimatedCostUSD, 0)
    }

    /// NoOpRAGGovernanceRepository logTokenUsage/logCall/saveRAGEvaluation 应不崩溃
    func testNoOpRAGGovernanceRepository_logOperations_不崩溃() async throws {
        let repo = NoOpRAGGovernanceRepository()
        try await repo.logTokenUsage(model: "test", promptTokens: 100, completionTokens: 50)
        try await repo.logCall(model: "test", promptTokens: 100, completionTokens: 50, latencyMS: 200, status: "success")
        try await repo.saveRAGEvaluation(RAGEvaluation(
            id: 0, query: "test", answer: "test",
            faithfulness: 1.0, relevance: 1.0, precision: 1.0,
            hallucinationRate: 0, citationAccuracy: 1.0,
            evaluatorModel: "test-model", createdAt: Date()
        ))
        // 不崩溃即通过
    }

    /// NoOpRAGGovernanceRepository fetchRetrievalSnapshots 应返回空数组
    func testNoOpRAGGovernanceRepository_fetchRetrievalSnapshots_空数组() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let snapshots = try await repo.fetchRetrievalSnapshots(evaluationID: 1)
        XCTAssertTrue(snapshots.isEmpty)
    }

    /// NoOpRAGGovernanceRepository fetchMonthlyTokenStats 应返回空数组
    func testNoOpRAGGovernanceRepository_fetchMonthlyTokenStats_空数组() async throws {
        let repo = NoOpRAGGovernanceRepository()
        let stats = try await repo.fetchMonthlyTokenStats()
        XCTAssertTrue(stats.isEmpty)
    }

    /// NoOpRAGGovernanceRepository saveRetrievalSnapshots/saveRelevanceJudgments/updateUserRating 应不崩溃
    func testNoOpRAGGovernanceRepository_saveOperations_不崩溃() async throws {
        let repo = NoOpRAGGovernanceRepository()
        try await repo.saveRetrievalSnapshots([])
        try await repo.saveRelevanceJudgments([])
        try await repo.updateUserRating(evaluationID: 1, rating: 5)
        // 不崩溃即通过
    }

    // MARK: - NoOpPageStoreCapabilities

    /// NoOpPageStoreCapabilities pages 应返回空数组
    func testNoOpPageStoreCapabilities_pages_返回空数组() async {
        let store = NoOpPageStoreCapabilities()
        let pages = await store.pages
        XCTAssertTrue(pages.isEmpty)
    }

    /// NoOpPageStoreCapabilities fetchAllPages 应返回空数组
    func testNoOpPageStoreCapabilities_fetchAllPages_返回空数组() async throws {
        let store = NoOpPageStoreCapabilities()
        let pages = try await store.fetchAllPages()
        XCTAssertTrue(pages.isEmpty)
    }

    /// NoOpPageStoreCapabilities getStorageStats 应返回全零
    func testNoOpPageStoreCapabilities_getStorageStats_全零() async {
        let store = NoOpPageStoreCapabilities()
        let stats = await store.getStorageStats()
        XCTAssertEqual(stats.databaseSize, 0)
        XCTAssertEqual(stats.logsSize, 0)
        XCTAssertEqual(stats.exportsSize, 0)
    }

    /// NoOpPageStoreCapabilities searchPages 应返回空数组
    func testNoOpPageStoreCapabilities_searchPages_返回空数组() async {
        let store = NoOpPageStoreCapabilities()
        let results = await store.searchPages(query: "test")
        XCTAssertTrue(results.isEmpty)
    }

    /// NoOpPageStoreCapabilities fetchBacklinksByID 应返回空数组
    func testNoOpPageStoreCapabilities_fetchBacklinksByID_返回空数组() async {
        let store = NoOpPageStoreCapabilities()
        let backlinks = await store.fetchBacklinksByID(for: UUID())
        XCTAssertTrue(backlinks.isEmpty)
    }

    /// NoOpPageStoreCapabilities createPage 应返回传入参数构造的页面
    func testNoOpPageStoreCapabilities_createPage_保留参数() async throws {
        let store = NoOpPageStoreCapabilities()
        let page = try await store.createPage(
            title: "test", pageType: .concept, customIcon: nil,
            content: "content", tags: ["tag"], sourceURL: nil,
            rawSnippet: nil, fileSize: nil, sourceType: nil
        )
        XCTAssertEqual(page.title, "test")
        XCTAssertEqual(page.content, "content")
    }

    /// NoOpPageStoreCapabilities updatePage/deletePage/syncRemotePage 应不崩溃
    func testNoOpPageStoreCapabilities_updateDelete_不崩溃() async throws {
        let store = NoOpPageStoreCapabilities()
        let page = KnowledgePage(title: "test", pageType: .concept, content: "")
        try await store.updatePage(page)
        try await store.deletePage(page)
        await store.syncRemotePage(page)
        // 不崩溃即通过
    }

    /// NoOpPageStoreCapabilities anyCreatePage 应不崩溃
    func testNoOpPageStoreCapabilities_anyCreatePage_不崩溃() async {
        let store = NoOpPageStoreCapabilities()
        _ = await store.anyCreatePage(
            title: "test", pageType: .concept, customIcon: nil,
            content: "content", tags: [], sourceURL: nil,
            rawSnippet: nil, fileSize: nil, sourceType: nil, forceDeepScan: false
        )
        // 不崩溃即通过
    }

    /// NoOpPageStoreCapabilities anyUpdatePage/anyDeletePage 应不崩溃
    func testNoOpPageStoreCapabilities_anyUpdateDelete_不崩溃() async {
        let store = NoOpPageStoreCapabilities()
        let page = KnowledgePage(title: "test", pageType: .concept, content: "")
        await store.anyUpdatePage(page, forceDeepScan: false)
        await store.anyDeletePage(page)
        // 不崩溃即通过
    }

    /// NoOpPageStoreCapabilities reloadFromDisk/replaceAllPages/resetDatabase/performBatchWrite 应不崩溃
    func testNoOpPageStoreCapabilities_batchOperations_不崩溃() async throws {
        let store = NoOpPageStoreCapabilities()
        await store.reloadFromDisk()
        await store.replaceAllPages([])
        try await store.resetDatabase()
        try await store.performBatchWrite { _ in }
        // 不崩溃即通过
    }

    /// NoOpPageStoreCapabilities renameTag/deleteTag/seedDefaultContent/addLog 应不崩溃
    func testNoOpPageStoreCapabilities_tagAndLog_不崩溃() async {
        let store = NoOpPageStoreCapabilities()
        await store.renameTag("old", to: "new")
        await store.deleteTag("tag")
        await store.seedDefaultContent { _, _, _ in }
        store.addLog(action: .create, target: "test", details: "", duration: nil, startTime: nil, endTime: nil, module: nil)
        // 不崩溃即通过
    }

    /// NoOpPageStoreCapabilities embeddingProvider 应返回 NoOpEmbeddingProvider
    func testNoOpPageStoreCapabilities_embeddingProvider_返回NoOp() {
        let store = NoOpPageStoreCapabilities()
        let provider = store.embeddingProvider
        XCTAssertTrue(provider is NoOpEmbeddingProvider, "embeddingProvider 应为 NoOpEmbeddingProvider")
    }

    // MARK: - NoOpIngestService

    /// NoOpIngestService ingestFolder 应返回空数组
    func testNoOpIngestService_ingestFolder_返回空数组() async {
        let service = NoOpIngestService()
        let store = NoOpPageStoreCapabilities()
        let pages = await service.ingestFolder(at: URL(fileURLWithPath: "/tmp"), type: .concept, pageStore: store)
        XCTAssertTrue(pages.isEmpty)
    }

    // MARK: - NoOpFeedbackRepository

    /// NoOpFeedbackRepository fetchAll 应返回空数组
    func testNoOpFeedbackRepository_fetchAll_返回空数组() async throws {
        let repo = NoOpFeedbackRepository()
        let entries = try await repo.fetchAll(limit: 10)
        XCTAssertTrue(entries.isEmpty)
    }

    /// NoOpFeedbackRepository fetchByID 应返回 nil
    func testNoOpFeedbackRepository_fetchByID_返回nil() async throws {
        let repo = NoOpFeedbackRepository()
        let entry = try await repo.fetchByID(id: "test")
        XCTAssertNil(entry)
    }

    /// NoOpFeedbackRepository save/updateStatus 应不崩溃
    func testNoOpFeedbackRepository_saveUpdate_不崩溃() async throws {
        let repo = NoOpFeedbackRepository()
        let entry = FeedbackEntry(id: "test", title: "test", category: "bug", rating: 5, content: "content", status: .pending, createdAt: Date())
        try await repo.save(entry)
        try await repo.updateStatus(id: "test", status: .synced)
        // 不崩溃即通过
    }

    // MARK: - NoOpVaultService

    /// NoOpVaultService 初始状态应返回安全默认值
    func testNoOpVaultService_初始状态_安全默认值() async {
        let service = await NoOpVaultService()
        XCTAssertTrue(service.vaults.isEmpty, "初始 vaults 应为空")
        XCTAssertNil(service.selectedVaultID, "初始 selectedVaultID 应为 nil")
        XCTAssertNil(service.currentVault, "初始 currentVault 应为 nil")
    }

    /// NoOpVaultService 所有操作应不崩溃
    func testNoOpVaultService_allOperations_不崩溃() async throws {
        let service = await NoOpVaultService()
        let vault = Vault(name: "test")
        try await service.selectVaultAndWait(vault)
        await service.refreshPageCount(for: UUID())
        service.selectVault(vault)
        service.exitVault()
        service.createVault(name: "new", icon: nil, description: nil)
        service.updateVault(id: UUID(), name: "updated", icon: nil, description: nil)
        service.renameVault(id: UUID(), newName: "renamed")
        service.deleteVault(id: UUID())
        // 不崩溃即通过
    }

    // MARK: - NoOpChatService

    /// NoOpChatService loadHistory 应返回空数组
    func testNoOpChatService_loadHistory_返回空数组() async {
        let service = await NoOpChatService()
        let history = service.loadHistory()
        XCTAssertTrue(history.isEmpty)
    }

    /// NoOpChatService streamChat 应立即 finish
    func testNoOpChatService_streamChat_立即finish() async throws {
        let service = await NoOpChatService()
        let stream = service.streamChat(query: "test", pages: [])
        var count = 0
        for try await _ in stream {
            count += 1
        }
        XCTAssertEqual(count, 0)
    }

    /// NoOpChatService clearHistory/saveMessages 应不崩溃
    func testNoOpChatService_clearAndSave_不崩溃() async {
        let service = await NoOpChatService()
        service.clearHistory()
        service.saveUserMessage("test")
        service.saveAssistantMessage("response")
        // 不崩溃即通过
    }

    // MARK: - NoOpSpeechService

    /// NoOpSpeechService 初始状态应返回安全默认值
    func testNoOpSpeechService_初始状态_安全默认值() async {
        let service = await NoOpSpeechService()
        XCTAssertFalse(service.isRecording)
        XCTAssertFalse(service.isTranscribing)
        XCTAssertEqual(service.transcribedText, "")
        XCTAssertEqual(service.audioLevel, 0)
        XCTAssertTrue(service.audioLevelHistory.isEmpty)
        XCTAssertEqual(service.statusMessage, "")
        XCTAssertTrue(service.supportedLanguages.isEmpty)
        XCTAssertEqual(service.selectedLanguage, "")
        XCTAssertFalse(service.hasPermission)
        XCTAssertTrue(service.recordings.isEmpty)
        XCTAssertNil(service.currentAudioFileURL)
    }

    /// NoOpSpeechService checkPermission/startRecording/stopRecording 应不崩溃
    func testNoOpSpeechService_recordingOperations_不崩溃() async {
        let service = await NoOpSpeechService()
        service.checkPermission()
        service.startRecording()
        service.stopRecording()
        // 不崩溃即通过
    }

    /// NoOpSpeechService transcribeFile 应返回空字符串
    func testNoOpSpeechService_transcribeFile_返回空字符串() async throws {
        let service = await NoOpSpeechService()
        let result = try await service.transcribeFile(url: URL(fileURLWithPath: "/tmp/test.m4a"))
        XCTAssertEqual(result, "")
    }

    /// NoOpSpeechService saveRecording 应保留 title
    func testNoOpSpeechService_saveRecording_保留title() async {
        let service = await NoOpSpeechService()
        let recording = service.saveRecording(title: "test recording")
        XCTAssertEqual(recording.title, "test recording")
        XCTAssertEqual(recording.text, "")
    }

    /// NoOpSpeechService deleteRecording/clearTranscription 应不崩溃
    func testNoOpSpeechService_deleteAndClear_不崩溃() async {
        let service = await NoOpSpeechService()
        let recording = service.saveRecording(title: "test")
        service.deleteRecording(recording)
        service.clearTranscription()
        // 不崩溃即通过
    }

    // MARK: - NoOpPDFService

    /// NoOpPDFService savePDF 应返回 nil
    func testNoOpPDFService_savePDF_返回nil() async {
        let service = await NoOpPDFService()
        let url = await service.savePDF(data: Data(), fileName: "test.pdf")
        XCTAssertNil(url)
    }

    /// NoOpPDFService deletePDF 应返回 false
    func testNoOpPDFService_deletePDF_返回false() async {
        let service = await NoOpPDFService()
        let result = await service.deletePDF(fileName: "test.pdf")
        XCTAssertFalse(result)
    }

    /// NoOpPDFService allPDFFilenames 应返回空数组
    func testNoOpPDFService_allPDFFilenames_返回空数组() async {
        let service = await NoOpPDFService()
        let filenames = await service.allPDFFilenames()
        XCTAssertTrue(filenames.isEmpty)
    }

    /// NoOpPDFService getPDFURL 应返回 nil
    func testNoOpPDFService_getPDFURL_返回nil() async {
        let service = await NoOpPDFService()
        let url = service.getPDFURL(fileName: "test.pdf")
        XCTAssertNil(url)
    }

    /// NoOpPDFService extractText 应返回 nil
    func testNoOpPDFService_extractText_返回nil() async {
        let service = await NoOpPDFService()
        let text = await service.extractText(from: URL(fileURLWithPath: "/tmp/test.pdf"))
        XCTAssertNil(text)
    }

    /// NoOpPDFService extractText pageRange 应返回 nil
    func testNoOpPDFService_extractText_pageRange_返回nil() async {
        let service = await NoOpPDFService()
        let text = await service.extractText(from: URL(fileURLWithPath: "/tmp/test.pdf"), pageRange: 0..<5)
        XCTAssertNil(text)
    }

    /// NoOpPDFService extractImages 应返回空数组
    func testNoOpPDFService_extractImages_返回空数组() async {
        let service = await NoOpPDFService()
        let images = await service.extractImages(from: URL(fileURLWithPath: "/tmp/test.pdf"))
        XCTAssertTrue(images.isEmpty)
    }

    /// NoOpPDFService loadDocumentsInfo 应返回空数组
    func testNoOpPDFService_loadDocumentsInfo_返回空数组() async {
        let service = await NoOpPDFService()
        let docs = await service.loadDocumentsInfo()
        XCTAssertTrue(docs.isEmpty)
    }

    /// NoOpPDFService saveDocumentsInfo 应不崩溃
    func testNoOpPDFService_saveDocumentsInfo_不崩溃() async {
        let service = await NoOpPDFService()
        await service.saveDocumentsInfo([])
        // 不崩溃即通过
    }

    // MARK: - UnsupportedSearchIndexer

    /// UnsupportedSearchIndexer 所有方法应不崩溃
    func testUnsupportedSearchIndexer_allMethods_不崩溃() {
        let indexer = UnsupportedSearchIndexer()
        let page = KnowledgePage(title: "test", pageType: .concept, content: "content")
        indexer.indexPage(page)
        indexer.indexPages([page])
        indexer.removeIndex(for: UUID())
        indexer.deindexAll()
        indexer.reindexAll(pages: [page])
        // 不崩溃即通过
    }
}
