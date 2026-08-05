//
//  LLMContextBuilderPrecisionTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 ContextReranker 两阶段二次重排序与噪点剪枝能力。
//

import XCTest
@testable import ZhiYu

@MainActor
final class LLMContextBuilderPrecisionTests: XCTestCase {

    private var reranker: ContextReranker!

    override func setUp() async throws {
        try await super.setUp()
        reranker = ContextReranker()
    }

    override func tearDown() async throws {
        reranker = nil
        try await super.tearDown()
    }

    /// 验证二阶段 Reranker 能从 30 个候选切片中剔除低相关度噪点，且 Top-K 结果按加权分强降序排列
    func testTwoStageRerankNegativeFiltering() {
        let pageID = UUID()
        let query = "Kubernetes SSA Apply"

        var candidates: [(chunk: PageChunk, score: Float)] = []
        // 构建 25 个低相关度负样本
        for i in 1...25 {
            let chunk = PageChunk(
                id: "chunk_neg_\(i)",
                pageID: pageID,
                chunkType: .paragraph,
                content: "Unrelated noise text \(i)",
                index: i
            )
            candidates.append((chunk, Float(i) * 0.01)) // 分数介于 0.01 ~ 0.25
        }

        // 构建 5 个高相关度正样本
        for i in 1...5 {
            let chunk = PageChunk(
                id: "chunk_pos_\(i)",
                pageID: pageID,
                chunkType: i == 1 ? "summary" : "paragraph",
                content: "Kubernetes Server-Side Apply SSA managedFields detail \(i)",
                index: 25 + i
            )
            candidates.append((chunk, 0.70 + Float(i) * 0.05))
        }

        let reranked = reranker.rerank(query: query, candidates: candidates, topK: 5, minScore: 0.35)

        XCTAssertEqual(reranked.count, 5, "二阶段重排序后必须精选出 Top-5 切片")
        XCTAssertTrue(reranked.allSatisfy { $0.score > 0.35 }, "所有保留切片的分数必须高于门槛")
        
        // 验证二阶段评分递减顺序
        if reranked.count > 1 {
            for i in 0..<(reranked.count - 1) {
                XCTAssertGreaterThanOrEqual(reranked[i].score, reranked[i + 1].score, "重排序结果必须呈降序排列")
            }
        }
    }
}
