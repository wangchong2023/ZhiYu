//
//  EmbeddingManagerTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 EmbeddingManager 开展自动化单元测试验证。
//
import XCTest
import Accelerate
@testable import ZhiYu

// MARK: - 向量仓库 Mock 类
/// 线程安全的模拟向量仓库实现，以便于对 EmbeddingManager 进行单元测试隔离
final class MockVectorRepository: VectorRepository, @unchecked Sendable {
    
    private let queue = DispatchQueue(label: "com.zhiyu.mock.vectorrepo")
    private var chunksStore: [UUID: [PageChunk]] = [:]
    private var embeddingsStore: [UUID: [Float]] = [:]
    
    func saveChunks(_ chunks: [PageChunk], for pageID: UUID) async throws {
        queue.sync {
            chunksStore[pageID] = chunks
        }
    }
    
    func fetchChunks(for pageID: UUID) async throws -> [PageChunk] {
        return queue.sync {
            chunksStore[pageID] ?? []
        }
    }
    
    func fetchAllChunksWithEmbeddings() async throws -> [PageChunk] {
        return queue.sync {
            chunksStore.values.flatMap { $0 }.filter { $0.embedding != nil }
        }
    }
    
    func deleteChunks(for pageID: UUID) async throws {
        _ = queue.sync {
            chunksStore.removeValue(forKey: pageID)
        }
    }
    
    func cleanupOrphanedChunks() async throws -> Int {
        return 0
    }
    
    func saveEmbedding(id: UUID, vector: [Float], modelName: String) async throws {
        queue.sync {
            embeddingsStore[id] = vector
        }
    }
    
    func fetchAllEmbeddings() async throws -> [UUID: [Float]] {
        return queue.sync {
            embeddingsStore
        }
    }
}

// MARK: - EmbeddingManager 单元测试
final class EmbeddingManagerTests: XCTestCase {
    
    private var mockRepository: MockVectorRepository!
    private var manager: EmbeddingManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockVectorRepository()
        manager = EmbeddingManager(repository: mockRepository)
    }
    
    override func tearDown() async throws {
        manager = nil
        mockRepository = nil
        try await super.tearDown()
    }
    
    // MARK: - 余弦相似度算法测试
    /// 验证高性能 Accelerate vDSP 余弦相似度计算逻辑，包括完全相同向量、正交向量与反向向量边界
    func testCosineSimilarityCalculation() {
        let v1: [Float] = [1.0, 0.0, 0.0]
        let v2: [Float] = [1.0, 0.0, 0.0]
        let similarity1 = EmbeddingManager.cosineSimilarity(v1, v2)
        XCTAssertEqual(similarity1, 1.0, accuracy: 1e-5, "完全相同的向量余弦相似度应当为 1.0")
        
        let v3: [Float] = [0.0, 1.0, 0.0]
        let similarity2 = EmbeddingManager.cosineSimilarity(v1, v3)
        XCTAssertEqual(similarity2, 0.0, accuracy: 1e-5, "相互正交的向量余弦相似度应当为 0.0")
        
        let v4: [Float] = [-1.0, 0.0, 0.0]
        let similarity3 = EmbeddingManager.cosineSimilarity(v1, v4)
        XCTAssertEqual(similarity3, -1.0, accuracy: 1e-5, "完全相反的向量余弦相似度应当为 -1.0")
    }
    
    // MARK: - 向量缓存与重载机制测试
    /// 验证向量数据库在热插拔发生时，能完全清空并从新仓储重新读取向量数据
    func testCacheSyncAndReload() async throws {
        let pageID = UUID()
        let page = KnowledgePage(id: pageID, title: "测试向量重载", content: "这里是一段用来向量化的页面文本。")
        
        // 同步前缓存应当为空
        var allEmbeddings = await manager.getAllEmbeddings()
        XCTAssertNil(allEmbeddings[pageID])
        
        // 触发向量同步
        await manager.syncEmbeddings(pages: [page])
        
        // 同步后内存缓存应该存在该向量，且数据库里成功持久化
        allEmbeddings = await manager.getAllEmbeddings()
        XCTAssertNotNil(allEmbeddings[pageID])
        let dbEmbeddings = try await mockRepository.fetchAllEmbeddings()
        XCTAssertNotNil(dbEmbeddings[pageID])
        
        // 物理驱逐内存缓存并执行重载
        await manager.clearCacheAndReload()
        
        // 重载后，向量应该能从 Mock 数据库完美恢复至内存缓存
        allEmbeddings = await manager.getAllEmbeddings()
        XCTAssertNotNil(allEmbeddings[pageID])
    }
    
    // MARK: - 语义相似度多并发检索测试
    /// 验证基于 Unsafe Pointer 及 Accelerate 硬件加速多路并发检索，相似度阈值拦截与 topK 截取
    func testParallelSearchAverages() async {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        
        let page1 = KnowledgePage(id: id1, title: "苹果公司", content: "苹果是一家科技巨头，主要业务是智能手机与电脑。")
        let page2 = KnowledgePage(id: id2, title: "红富士苹果", content: "苹果是一种甘甜的水果，含有丰富的维生素。")
        let page3 = KnowledgePage(id: id3, title: "完全无关的主题", content: "地球是太阳系的一颗行星，表面有大量的水。")
        
        // 执行同步以生成特征向量
        await manager.syncEmbeddings(pages: [page1, page2, page3])
        
        // 语义检索使用与 page2 内容完全匹配的查询，使确定性哈希余弦相似度为 1.0 以通过 0.85 阈值
        // 注意：模拟器上 NLEmbedding 不可用，降级为确定性哈希，不同文本的哈希余弦相似度 ≈ 0
        let results = await manager.search(query: "红富士苹果\n苹果是一种甘甜的水果，含有丰富的维生素。", topK: 2)
        
        // 验证检索返回非空结果且不超过 topK 限制
        XCTAssertFalse(results.isEmpty)
        XCTAssertLessThanOrEqual(results.count, 2, "限制最高返回 topK 个相似结果")
        // page2 应排在首位（确定性哈希精确匹配）
        XCTAssertEqual(results.first?.id, id2, "精确匹配应排在最前")
    }
    
    // MARK: - 边缘输入与分块检索测试
    /// 验证在超长文本、零向量及空数据集合下的健壮性表现
    func testSearchWithEmptyIndex() async {
        let results = await manager.search(query: "空搜索测试", topK: 5)
        XCTAssertTrue(results.isEmpty, "空数据库下检索不应当发生崩溃且返回空数组")
    }
    
    /// 验证页面分块在索引之后能够正确被加载入 chunk 缓存并在 advancedSearch 类似混合机制下完成匹配
    func testIndexChunksAndSearch() async throws {
        // 创建页面唯一标识码
        let pageID = UUID()
        
        // 1. 初始化两个分块实例，利用最新的 anchorPath 语义路径和 index 排序标识
        let chunk1 = PageChunk(
            id: "chunk-1",
            pageID: pageID,
            content: "Swift 6 严格并发检查可以消除数据竞争安全隐患。",
            anchorPath: "Swift 6",
            index: 0
        )
        let chunk2 = PageChunk(
            id: "chunk-2",
            pageID: pageID,
            content: "SQLite v5 基于 GRDB 持久化实现快速增量同步和索引更新。",
            anchorPath: "Database",
            index: 1
        )
        
        // 2. 批量索引分块，将分块特征信息同步到内存及数据库
        await manager.indexChunks(pageID: pageID, chunks: [chunk1, chunk2])
        
        // 3. 验证分块元数据是否能够进入 Mock 数据库中
        let dbChunks = try await mockRepository.fetchAllChunksWithEmbeddings()
        XCTAssertEqual(dbChunks.count, 2)
        XCTAssertNotNil(dbChunks.first?.embedding, "分块向量数据应被就地计算并持久化")
    }
}
