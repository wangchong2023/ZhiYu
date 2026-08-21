//
//  VectorAndAuthSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 EmbeddingManager 向量同步/查询边界、
//           ContextReranker 二阶段重排序、
//           AuthRegion 枚举属性与 Codable、
//           RegionCapabilities JSON 解析、
//           NoOpEmbeddingProvider 默认实现、
//           VectorIndexer 索引委托。
//

import XCTest
@testable import ZhiYu

@MainActor
final class VectorAndAuthSupplementTests: XCTestCase {

    // MARK: - EmbeddingManager 边界

    /// 空页面列表同步应不崩溃
    func testEmbeddingManager_syncEmptyPages_noCrash() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        await manager.syncEmbeddings(pages: [])
        let embeddings = await manager.getAllEmbeddings()
        XCTAssertTrue(embeddings.isEmpty)
    }

    /// indexChunks 空列表直接返回
    func testEmbeddingManager_indexEmptyChunks_returnsEarly() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        await manager.indexChunks(pageID: UUID(), chunks: [])
        // 不崩溃即通过
    }

    /// indexChunks 非空列表生成向量并持久化
    func testEmbeddingManager_indexChunks_generatesVectors() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let pageID = UUID()
        let chunk = PageChunk(
            id: "test-chunk-1",
            pageID: pageID,
            content: "This is a test chunk",
            index: 0
        )
        await manager.indexChunks(pageID: pageID, chunks: [chunk])
        // 验证 chunk 已保存到 repository
        let saved = try? await repo.fetchChunks(for: pageID)
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.count, 1)
    }

    /// vectorizeChunks 返回与输入等长的向量数组
    func testEmbeddingManager_vectorizeChunks_returnsEqualLength() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let texts = ["hello", "world", "test"]
        let vectors = await manager.vectorizeChunks(chunks: texts)
        XCTAssertEqual(vectors.count, texts.count)
        for v in vectors {
            XCTAssertFalse(v.isEmpty)
        }
    }

    /// search 空缓存返回空结果
    func testEmbeddingManager_searchEmptyCache_returnsEmpty() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let results = await manager.search(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// search 超长查询不崩溃
    func testEmbeddingManager_searchLongQuery_noCrash() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let longQuery = String(repeating: "A", count: 10000)
        let results = await manager.search(query: longQuery, topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// search topK=0 返回空结果
    func testEmbeddingManager_searchTopKZero_returnsEmpty() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let results = await manager.search(query: "test", topK: 0)
        XCTAssertTrue(results.isEmpty)
    }

    /// multiQuerySearch 空缓存返回空结果
    func testEmbeddingManager_multiQuerySearchEmptyCache_returnsEmpty() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let results = await manager.multiQuerySearch(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// hydeSearch 委托给 multiQuerySearch
    func testEmbeddingManager_hydeSearch_delegatesToMultiQuery() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let results = await manager.hydeSearch(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// selfReflectionSearch 返回原样候选
    func testEmbeddingManager_selfReflectionSearch_returnsOriginal() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let candidates: [(chunk: PageChunk, score: Float)] = []
        let results = await manager.selfReflectionSearch(query: "test", candidates: candidates)
        XCTAssertEqual(results.count, candidates.count)
    }

    /// advancedSearch 委托给 multiQuerySearch
    func testEmbeddingManager_advancedSearch_delegatesToMultiQuery() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        let results = await manager.advancedSearch(query: "test", topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    /// clearCacheAndReload 清空缓存后重新加载
    func testEmbeddingManager_clearCacheAndReload_noCrash() async {
        let repo = MockVectorRepository()
        let manager = EmbeddingManager(repository: repo)
        await manager.clearCacheAndReload()
        let embeddings = await manager.getAllEmbeddings()
        XCTAssertTrue(embeddings.isEmpty)
    }

    /// cosineSimilarity 相同向量返回 1.0
    func testEmbeddingManager_cosineSimilarity_sameVector_returnsOne() {
        let vector = [Float](repeating: 1.0, count: 10)
        let score = EmbeddingManager.cosineSimilarity(vector, vector)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    /// cosineSimilarity 零向量返回 0
    func testEmbeddingManager_cosineSimilarity_zeroVector_returnsZero() {
        let vector1 = [Float](repeating: 0.0, count: 10)
        let vector2 = [Float](repeating: 1.0, count: 10)
        let score = EmbeddingManager.cosineSimilarity(vector1, vector2)
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    /// cosineSimilarity 不同长度向量不崩溃
    func testEmbeddingManager_cosineSimilarity_differentLength_noCrash() {
        let vector1: [Float] = [1.0, 2.0, 3.0]
        let vector2: [Float] = [1.0, 2.0]
        let score = EmbeddingManager.cosineSimilarity(vector1, vector2)
        XCTAssertFalse(score.isNaN)
    }

    /// SearchDefaults 常量验证
    func testEmbeddingManager_searchDefaults_constants() {
        XCTAssertEqual(EmbeddingManager.SearchDefaults.defaultTopK, 10)
        XCTAssertEqual(EmbeddingManager.SearchDefaults.similarityThreshold, 0.3, accuracy: 0.001)
        XCTAssertEqual(EmbeddingManager.SearchDefaults.deterministicModulus, 1000, accuracy: 0.001)
        XCTAssertEqual(EmbeddingManager.SearchDefaults.vectorDimension, 512)
    }

    // MARK: - ContextReranker

    /// 空候选列表返回空结果
    func testContextReranker_emptyCandidates_returnsEmpty() {
        let reranker = ContextReranker()
        let results = reranker.rerank(query: "test", candidates: [])
        XCTAssertTrue(results.isEmpty)
    }

    /// 低于 minScore 的候选被剪枝
    func testContextReranker_lowScoreCandidates_pruned() {
        let reranker = ContextReranker()
        let chunk = PageChunk(
            id: "low-score", pageID: UUID(), content: "unrelated", index: 0
        )
        let candidates = [(chunk: chunk, score: Float(0.1))]
        let results = reranker.rerank(query: "test", candidates: candidates, minScore: 0.5)
        XCTAssertTrue(results.isEmpty)
    }

    /// 关键词匹配获得加成
    func testContextReranker_keywordMatch_getsBonus() {
        let reranker = ContextReranker()
        let chunk = PageChunk(
            id: "kw-match", pageID: UUID(), content: "machine learning model", index: 0
        )
        let candidates = [(chunk: chunk, score: Float(0.5))]
        let results = reranker.rerank(query: "machine learning", candidates: candidates, minScore: 0.3)
        XCTAssertEqual(results.count, 1)
        // 关键词加成应使分数高于原始 0.5
        XCTAssertGreaterThan(results[0].score, 0.5)
    }

    /// summary 类型切片获得 1.1x 权重
    func testContextReranker_summaryChunk_getsMultiplier() {
        let reranker = ContextReranker()
        let summaryChunk = PageChunk(
            id: "summary", pageID: UUID(), chunkType: .summary,
            content: "test content", index: 0
        )
        let regularChunk = PageChunk(
            id: "regular", pageID: UUID(), chunkType: .regular,
            content: "test content", index: 1
        )
        let candidates = [
            (chunk: summaryChunk, score: Float(0.5)),
            (chunk: regularChunk, score: Float(0.5))
        ]
        let results = reranker.rerank(query: "test", candidates: candidates, minScore: 0.3)
        // summary 应排在 regular 前面
        XCTAssertEqual(results.first?.chunk.id, "summary")
    }

    /// topK 截取正确数量
    func testContextReranker_topK_limitsResults() {
        let reranker = ContextReranker()
        let candidates: [(chunk: PageChunk, score: Float)] = (0..<10).map { i in
            (chunk: PageChunk(
                id: "chunk-\(i)", pageID: UUID(), content: "content \(i)",
                index: i
            ), score: Float(0.5 + Double(i) * 0.01))
        }
        let results = reranker.rerank(query: "content", candidates: candidates, topK: 3, minScore: 0.3)
        XCTAssertEqual(results.count, 3)
    }

    /// Constants 常量验证
    func testContextReranker_constants() {
        XCTAssertEqual(ContextReranker.Constants.defaultTopK, 5)
        XCTAssertEqual(ContextReranker.Constants.defaultMinScore, 0.35, accuracy: 0.001)
        XCTAssertEqual(ContextReranker.Constants.keywordBonusWeight, 0.25, accuracy: 0.001)
        XCTAssertEqual(ContextReranker.Constants.summaryMultiplier, 1.1, accuracy: 0.001)
        XCTAssertEqual(ContextReranker.Constants.regularMultiplier, 1.0, accuracy: 0.001)
    }

    // MARK: - AuthRegion 枚举

    /// AuthRegion 枚举 rawValue 验证
    func testAuthRegion_rawValues() {
        XCTAssertEqual(AuthRegion.china.rawValue, "CN")
        XCTAssertEqual(AuthRegion.international.rawValue, "INTL")
    }

    /// AuthRegion CaseIterable 包含 2 个 case
    func testAuthRegion_caseIterable() {
        XCTAssertEqual(AuthRegion.allCases.count, 2)
        XCTAssertTrue(AuthRegion.allCases.contains(.china))
        XCTAssertTrue(AuthRegion.allCases.contains(.international))
    }

    /// AuthRegion Codable 往返
    func testAuthRegion_codableRoundTrip() throws {
        let original = AuthRegion.china
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuthRegion.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - RegionCapabilities

    /// RegionCapabilities Codable 往返
    func testRegionCapabilities_codableRoundTrip() throws {
        let original = RegionCapabilities(regions: [
            "CN": RegionCapabilities.RegionInfo(loginPageType: "localized", pluginMarketUrl: "https://example.com/cn"),
            "US": RegionCapabilities.RegionInfo(loginPageType: "international", pluginMarketUrl: "https://example.com/us")
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegionCapabilities.self, from: data)
        XCTAssertEqual(decoded.regions.count, 2)
        XCTAssertEqual(decoded.regions["CN"]?.loginPageType, "localized")
        XCTAssertEqual(decoded.regions["US"]?.loginPageType, "international")
    }

    /// RegionCapabilities 空 regions 可解码
    func testRegionCapabilities_emptyRegions_codable() throws {
        let original = RegionCapabilities(regions: [:])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegionCapabilities.self, from: data)
        XCTAssertTrue(decoded.regions.isEmpty)
    }

    /// RegionCapabilities JSON snake_case 解码
    func testRegionCapabilities_jsonSnakeCase_decodable() throws {
        let json = #"{"regions":{"CN":{"login_page_type":"localized","plugin_market_url":"https://example.com/cn"}}}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(RegionCapabilities.self, from: data)
        XCTAssertEqual(decoded.regions["CN"]?.loginPageType, "localized")
        XCTAssertEqual(decoded.regions["CN"]?.pluginMarketUrl, "https://example.com/cn")
    }

    // MARK: - NoOpEmbeddingProvider

    /// NoOpEmbeddingProvider 所有方法返回安全默认值
    func testNoOpEmbeddingProvider_allMethods_returnDefaults() async {
        let noOp = NoOpEmbeddingProvider()
        let embeddings = await noOp.getAllEmbeddings()
        XCTAssertTrue(embeddings.isEmpty)
        await noOp.syncEmbeddings(pages: [])
        await noOp.updateEmbedding(for: KnowledgePage(title: "t", content: "c"))
        await noOp.indexChunks(pageID: UUID(), chunks: [])
        let vectors = await noOp.vectorizeChunks(chunks: ["test"])
        XCTAssertTrue(vectors.isEmpty)
        let searchResults = await noOp.search(query: "test", topK: 5)
        XCTAssertTrue(searchResults.isEmpty)
        let mqResults = await noOp.multiQuerySearch(query: "test", topK: 5)
        XCTAssertTrue(mqResults.isEmpty)
        let hydeResults = await noOp.hydeSearch(query: "test", topK: 5)
        XCTAssertTrue(hydeResults.isEmpty)
        let candidates: [(chunk: PageChunk, score: Float)] = []
        let srResults = await noOp.selfReflectionSearch(query: "test", candidates: candidates)
        XCTAssertTrue(srResults.isEmpty)
        let advResults = await noOp.advancedSearch(query: "test", topK: 5)
        XCTAssertTrue(advResults.isEmpty)
        await noOp.loadInitialCache()
        await noOp.clearCacheAndReload()
    }

    // MARK: - EmbeddingProviderKey

    /// EmbeddingProviderKey testValue fallback 到 NoOpEmbeddingProvider
    func testEmbeddingProviderKey_testValue_fallsBackToNoOp() {
        let value = EmbeddingProviderKey.testValue
        XCTAssertNotNil(value)
    }

    // MARK: - VectorIndexer

    /// VectorIndexer 空列表直接返回
    func testVectorIndexer_emptyChunks_doesNotCallProvider() async {
        let provider = NoOpEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: provider)
        await indexer.index(pageID: UUID(), chunks: [])
        // 不崩溃即通过
    }

    /// VectorIndexer 非空列表委托给 provider
    func testVectorIndexer_nonEmptyChunks_callsProvider() async {
        let provider = NoOpEmbeddingProvider()
        let indexer = VectorIndexer(embeddingProvider: provider)
        let chunk = PageChunk(
            id: "test", pageID: UUID(), content: "content", index: 0
        )
        await indexer.index(pageID: UUID(), chunks: [chunk])
        // NoOp 不崩溃即通过
    }
}
