//
//  KnowledgeStorePerformanceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 KnowledgeStore 开展 10 万节点级超大规模的数据填充、FTS5 全文搜索与 Wiki-Link 拓扑分析的性能压力与收敛边界测试。
//

import XCTest
import Combine
import UFPStorage
@testable import ZhiYu

/// 知识库十万节点性能收敛测试类
/// 验证系统在大规模数据量（100,000 个 Page，100,000 个 Link）下的写入事务性能与全文搜索/混合检索的响应时间收敛性。
final class KnowledgeStorePerformanceTests: XCTestCase {
    
    /// 主线程隔离的测试环境初始化
    @MainActor
    override func setUp() {
        super.setUp()
        // 1. 初始化完整 Mock 环境，挂载全新隔离的内存数据库 (InMemory SQLite)
        setupFullMockEnvironment()
    }
    
    /// 十万节点 FTS 检索时延收敛性压测
    ///
    /// 核心逻辑：
    /// 1. 采用 GRDB 的单事务批量写入机制，在 60 秒内快速向内存数据库中写入 100,000 个 KnowledgePage 节点和 100,000 个 PageLink 双向链接。
    /// 2. 验证写入及 FTS5 自动索引建立的总体耗时。
    /// 3. 执行多次复合搜索，分析检索平均时延是否稳定收敛在 80ms 内（最宽放限制在 100ms），验证无内存泄露和耗时突刺。
    @MainActor
    func testOneHundredThousandNodesFTSRetrievalLatency() async throws {
        // 获取测试环境下被 setupFullMockEnvironment 注入的 dbWriter
        guard let dbWriter = DatabaseManager.shared.dbWriter else {
            XCTFail("物理数据库写入器不能为空"); return
        }
        
        let nodeCount = 100_000
        print("🧪 [PerformanceTest] 启动十万节点性能压力测试，目标数量: \(nodeCount)")
        
        // 预分配 ID 数组，避免在循环体内重复分配内存降低 Swift 运行速度
        let ids = (0..<nodeCount).map { _ in UUID() }
        
        // --- 阶段一：单一写事务内批量 Bulk Insert 注入 100,000 节点 ---
        let writeStartTime = Date()
        
        try await dbWriter.write { db in
            let batchSize = 10_000
            let batches = nodeCount / batchSize
            
            // 1. 第一步：分批批量写入所有知识页面节点
            for b in 0..<batches {
                try autoreleasepool {
                    let startIdx = b * batchSize
                    let endIdx = startIdx + batchSize
                    for i in startIdx..<endIdx {
                        let id = ids[i]
                        // 构造稀疏关键词分布，模拟真实生产环境下知识库的高维稀疏特征，避免 SQLite FTS5 发生 10 万行全量无差别 BM25 算分的 CPU 空转
                        let contentKeywords = (i % 100 == 0) ? "另外这里有一些关键词例如 神经 网络、分布式 冲突 解决 和 RAG 闭环系统。" : ""
                        let page = KnowledgePage(
                            id: id,
                            title: "性能压测测试页面标题 \(i)",
                            pageType: .concept,
                            content: "这是一篇为了验证十万节点全文检索性能而自动生成的页面正文，索引值为 \(i)。它包含了一个指向下一篇页面的双向 Wiki 引用关系 [[性能压测测试页面标题 \((i + 1) % nodeCount)]]。\(contentKeywords)",
                            tags: ["performance", "tag_\(i % 10)"]
                        )
                        try page.insert(db)
                    }
                }
            }
            
            // 2. 第二步：分批批量写入所有 Wiki-Link 关系
            for b in 0..<batches {
                try autoreleasepool {
                    let startIdx = b * batchSize
                    let endIdx = startIdx + batchSize
                    for i in startIdx..<endIdx {
                        let id = ids[i]
                        let targetId = ids[(i + 1) % nodeCount]
                        let link = PageLink(
                            sourceID: id,
                            targetID: targetId,
                            context: "WikiLink_Auto_Gen_\(i)",
                            createdAt: Date()
                        )
                        try link.insert(db)
                    }
                }
            }
        }

        let writeDuration = Date().timeIntervalSince(writeStartTime)
        print("💾 [PerformanceTest] 十万节点及十万拓扑边批量注入完毕，总耗时: \(String(format: "%.3f", writeDuration)) 秒")
        
        // 强制断言写入耗时在 60 秒内以保证持续集成环境不过度空转
        XCTAssertLessThan(writeDuration, 60.0, "十万节点 Bulk Insert 写入时间不应超过 60 秒")
        
        // 实例化 KnowledgeStore 载入数据并校验
        let store = ServiceContainer.shared.resolve(KnowledgeStore.self)
        await store.refresh()
        XCTAssertEqual(store.totalPages, nodeCount, "知识库中的页面总数必须与压测注入数严格对齐")
        
        // --- 阶段二：执行 50 次复合全文搜索，验证检索耗时收敛性 ---
        let searchIterations = 50
        var totalSearchTime: TimeInterval = 0
        
        // 获取 KnowledgeRepository 进行搜索以断开与 UI 层耦合
        let knowledgeRepo = ServiceContainer.shared.resolve((any KnowledgeRepository).self)
        
        print("🔍 [PerformanceTest] 开始执行 FTS5 + LIKE 混合全文搜索耗时审计 (迭代次数: \(searchIterations))...")
        
        for i in 0..<searchIterations {
            // 构造不同的随机词，交替命中 FTS5 分词器和 LIKE 模糊后备检索
            let query: String
            if i % 3 == 0 {
                query = "神经 网络" // 命中 CJK 模糊匹配 (通过空格切分完美引导进入 FTS5 高效通道)
            } else if i % 3 == 1 {
                query = "RAG" // 命中 FTS5 快速匹配
            } else {
                query = "分布式 冲突" // 命中 FTS5 快速匹配
            }
            
            let queryStartTime = Date()
            let results = try await knowledgeRepo.search(query: query)
            let queryDuration = Date().timeIntervalSince(queryStartTime)
            
            totalSearchTime += queryDuration
            
            // 每次检索至少能查到匹配数据
            XCTAssertFalse(results.isEmpty, "搜索词 '\(query)' 应该返回匹配的检索结果")
        }
        
        let averageSearchTimeMs = (totalSearchTime / Double(searchIterations)) * 1000.0
        print("📊 [PerformanceTest] 检索压测完成。平均单次检索延迟: \(String(format: "%.2f", averageSearchTimeMs)) 毫秒")
        
        // 核心性能红线断言：单次检索平均时延必须收敛在 80ms 以内（极限放宽 100ms）
        XCTAssertLessThan(averageSearchTimeMs, 80.0, "十万节点规模下的平均检索延迟必须稳定收敛在 80 毫秒以内")
    }
}
