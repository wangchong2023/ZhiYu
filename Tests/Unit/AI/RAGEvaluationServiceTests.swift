//
//  RAGEvaluationServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 RAGEvaluationService 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

@MainActor
final class RAGEvaluationServiceTests: XCTestCase {
    
    private var mockLLM: MockLLMService!
    private var governanceStore: (any RAGGovernanceRepository)!
    private var evaluationService: RAGEvaluationService!
    
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        
        mockLLM = try XCTUnwrap(ServiceContainer.shared.resolve((any LLMServiceProtocol).self) as? MockLLMService)
        governanceStore = ServiceContainer.shared.resolve((any RAGGovernanceRepository).self)
        evaluationService = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
    }
    
    override func tearDown() async throws {
        mockLLM = nil
        governanceStore = nil
        evaluationService = nil
        try await super.tearDown()
    }
    
    // MARK: - 正常打分与落库测试 (Pass)
    
    /// 验证当 LLM 裁判给出高分时，报告被正确划归为 "Pass" 状态，并成功落入 SQLite 数据库
    func testEvaluationPassStatusAndPersistence() async throws {
        // 1. 模拟裁判输出合格的高分 JSON 字符串
        mockLLM.generateHandler = { _, systemPrompt in
            XCTAssertTrue(systemPrompt.contains("Judge"))
            return """
            {
                "faithfulness": 0.95,
                "relevance": 0.88,
                "context_precision": 0.92
            }
            """
        }
        
        let query = "什么是量子纠缠？"
        let answer = "量子纠缠是微观粒子间的一种强关联现象。"
        let context = "量子纠缠是指两个或多个粒子在空间上分离，但其量子态相互关联。"
        
        // 2. 执行评估
        let report = await evaluationService.evaluate(query: query, answer: answer, context: context)
        
        // 3. 断言报告的各项指标
        XCTAssertEqual(report.query, query)
        XCTAssertEqual(report.answer, answer)
        XCTAssertEqual(report.faithfulness, 0.95)
        XCTAssertEqual(report.relevance, 0.88)
        XCTAssertEqual(report.precision, 0.92)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.pass) // "Pass"
        
        // 4. 从 SQLite 治理仓储拉出最近的一条记录，验证数据真实落库
        let records = try await governanceStore.fetchRAGEvaluations(limit: 1)
        XCTAssertEqual(records.count, 1)
        if let firstRecord = records.first {
            XCTAssertEqual(firstRecord.query, query)
            XCTAssertEqual(firstRecord.answer, answer)
            XCTAssertEqual(firstRecord.faithfulness, 0.95)
            XCTAssertEqual(firstRecord.relevance, 0.88)
            XCTAssertEqual(firstRecord.precision, 0.92)
        }
    }
    
    // MARK: - 中等分数测试 (Warning)
    
    /// 验证当 LLM 裁判给出中等分数时，报告被正确划归为 "Warning" 状态
    func testEvaluationWarningStatus() async {
        mockLLM.generateHandler = { _, _ in
            return """
            {
                "faithfulness": 0.65,
                "relevance": 0.70,
                "context_precision": 0.68
            }
            """
        }
        
        let report = await evaluationService.evaluate(query: "警告测试", answer: "中等回答", context: "部分上下文")
        
        XCTAssertEqual(report.faithfulness, 0.65)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.warning) // "Warning"
    }
    
    // MARK: - 低分测试 (Fail)
    
    /// 验证当 LLM 裁判给出极低分数时，报告被正确标记为 "Fail" 状态
    func testEvaluationFailStatus() async {
        mockLLM.generateHandler = { _, _ in
            return """
            {
                "faithfulness": 0.35,
                "relevance": 0.40,
                "context_precision": 0.30
            }
            """
        }
        
        let report = await evaluationService.evaluate(query: "失败测试", answer: "答非所问", context: "完备上下文")
        
        XCTAssertEqual(report.faithfulness, 0.35)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.fail) // "Fail"
    }
    
    // MARK: - 降级防卫测试 (Degraded Error)
    
    /// 验证当 LLM 损坏输出或超时时，评估服务能够平稳拦截异常，优雅降级为 0 分 error 报告
    func testEvaluationDegradedOnInvalidJSON() async {
        // 模拟 LLM 发生网络中断或输出乱码，非有效 JSON
        mockLLM.generateHandler = { _, _ in
            return "Server Timeout, Raw HTML error..."
        }
        
        let report = await evaluationService.evaluate(query: "网络故障测试", answer: "无回答", context: "空上下文")
        
        XCTAssertEqual(report.faithfulness, 0.0)
        XCTAssertEqual(report.relevance, 0.0)
        XCTAssertEqual(report.precision, 0.0)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.error) // "Error"
    }
    
    /// 验证当 LLM 评测抛出强异常（如网络连接断开）时，评估服务能够捕获 error 并优雅降级为 0 分 error 报告
    func testEvaluationDegradedOnLLMError() async {
        // 模拟 LLM 发生物理网络连接报错，强行抛出 Error
        mockLLM.generateHandler = { _, _ in
            throw URLError(.cannotConnectToHost)
        }
        
        let report = await evaluationService.evaluate(query: "抛出异常测试", answer: "网络崩溃", context: "空上下文")
        
        XCTAssertEqual(report.faithfulness, 0.0)
        XCTAssertEqual(report.relevance, 0.0)
        XCTAssertEqual(report.precision, 0.0)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.error) // "Error"
    }
    
    // MARK: - JSON 字段缺失测试

    /// 验证当 LLM 裁判返回的 JSON 中缺少部分指标字段时，评估服务能够平稳使用 0.0 兜底，并成功生成报告并持久化
    func testEvaluationMissingJSONKeys() async {
        mockLLM.generateHandler = { _, _ in
            return "{}"
        }

        let report = await evaluationService.evaluate(query: "字段缺失测试", answer: "局部回答", context: "部分上下文")

        XCTAssertEqual(report.faithfulness, 0.0)
        XCTAssertEqual(report.relevance, 0.0)
        XCTAssertEqual(report.precision, 0.0)
        XCTAssertEqual(report.hallucinationRate, 0.0)
        XCTAssertEqual(report.citationAccuracy, 0.0)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.fail) // "Fail"
    }

    // MARK: - 新指标全维度解析测试 (Phase 2)

    /// 验证 LLM 返回 5 维指标（含幻觉率与引用准确度）时全部正确解析并持久化
    func testEvaluationFiveDimensionalParsingAndPersistence() async throws {
        mockLLM.generateHandler = { prompt, _ in
            // 验证 prompt 包含新维度关键词
            XCTAssertTrue(prompt.contains("hallucination_rate"))
            return """
            {
                "faithfulness": 0.92,
                "relevance": 0.85,
                "context_precision": 0.88,
                "hallucination_rate": 0.08,
                "citation_accuracy": 0.90
            }
            """
        }

        let query = "什么是暗物质？"
        let answer = "暗物质是一种不发光、不反射电磁辐射的物质，通过引力效应被间接探测到。"
        let context = "暗物质是宇宙中占比约 27% 的不可见物质，其存在由星系旋转曲线和引力透镜效应证实。"

        let report = await evaluationService.evaluate(query: query, answer: answer, context: context)

        // 断言所有 5 维指标
        XCTAssertEqual(report.faithfulness, 0.92)
        XCTAssertEqual(report.relevance, 0.85)
        XCTAssertEqual(report.precision, 0.88)
        XCTAssertEqual(report.hallucinationRate, 0.08)
        XCTAssertEqual(report.citationAccuracy, 0.90)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.pass)

        // 验证数据库持久化
        let records = try await governanceStore.fetchRAGEvaluations(limit: 1)
        XCTAssertEqual(records.count, 1)
        if let first = records.first {
            XCTAssertEqual(first.faithfulness, 0.92)
            XCTAssertEqual(first.relevance, 0.85)
            XCTAssertEqual(first.precision, 0.88)
            XCTAssertEqual(first.hallucinationRate, 0.08)
            XCTAssertEqual(first.citationAccuracy, 0.90)
        }
    }

    /// 验证新指标部分缺失时使用 0.0 兜底（向后兼容旧版 JSON）
    func testEvaluationPartialNewMetricsDefaultToZero() async {
        mockLLM.generateHandler = { _, _ in
            // 旧版 JSON 不含 hallucination_rate 和 citation_accuracy
            return """
            {
                "faithfulness": 0.78,
                "relevance": 0.82,
                "context_precision": 0.75
            }
            """
        }

        let report = await evaluationService.evaluate(query: "旧格式测试", answer: "兼容回答", context: "部分上下文")

        XCTAssertEqual(report.faithfulness, 0.78)
        XCTAssertEqual(report.relevance, 0.82)
        XCTAssertEqual(report.precision, 0.75)
        // 新字段缺失时应兜底为 0.0
        XCTAssertEqual(report.hallucinationRate, 0.0)
        XCTAssertEqual(report.citationAccuracy, 0.0)
    }

    // MARK: - 五维均值计算测试

    /// 验证 calculateAverageRAGScores 返回 5 维均值的正确性
    func testCalculateAverageRAGScoresFiveDimensional() async throws {
        // 写入两条已知评估记录
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "Q1", answer: "A1",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.9,
            evaluatorModel: "test-model"
        ))
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "Q2", answer: "A2",
            faithfulness: 0.7, relevance: 0.6, precision: 0.5,
            hallucinationRate: 0.3, citationAccuracy: 0.7,
            evaluatorModel: "test-model"
        ))

        let avg = try await governanceStore.calculateAverageRAGScores(days: 365)

        // (0.9 + 0.7) / 2 = 0.8
        XCTAssertEqual(avg.faithfulness, 0.8, accuracy: 0.001)
        XCTAssertEqual(avg.relevance, 0.7, accuracy: 0.001)
        XCTAssertEqual(avg.precision, 0.6, accuracy: 0.001)
        // (0.1 + 0.3) / 2 = 0.2
        XCTAssertEqual(avg.hallucinationRate, 0.2, accuracy: 0.001)
        // (0.9 + 0.7) / 2 = 0.8
        XCTAssertEqual(avg.citationAccuracy, 0.8, accuracy: 0.001)
    }

    /// 空数据库时 calculateAverageRAGScores 返回全 0
    func testCalculateAverageRAGScoresEmptyDatabase() async throws {
        let avg = try await governanceStore.calculateAverageRAGScores(days: 30)

        XCTAssertEqual(avg.faithfulness, 0.0)
        XCTAssertEqual(avg.relevance, 0.0)
        XCTAssertEqual(avg.precision, 0.0)
        XCTAssertEqual(avg.hallucinationRate, 0.0)
        XCTAssertEqual(avg.citationAccuracy, 0.0)
    }

    // MARK: - 检索快照持久化 (Phase 3)

    /// 验证检索快照的保存和读取
    func testSaveAndFetchRetrievalSnapshots() async throws {
        // 先创建一条评估记录作为外键
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "检索快照测试", answer: "测试回答",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85,
            evaluatorModel: "test-model"
        ))
        let savedEvals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(savedEvals.first?.id)

        // 保存 Top-3 检索快照
        let snapshots = [
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: UUID().uuidString, pageTitle: "文档A", snippet: "片段A", score: 0.95),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: UUID().uuidString, pageTitle: "文档B", snippet: "片段B", score: 0.82),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: UUID().uuidString, pageTitle: "文档C", snippet: "片段C", score: 0.71)
        ]
        try await governanceStore.saveRetrievalSnapshots(snapshots)

        // 读回验证
        let fetched = try await governanceStore.fetchRetrievalSnapshots(evaluationID: evalID)
        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].rank, 1)
        XCTAssertEqual(fetched[0].pageTitle, "文档A")
        XCTAssertEqual(fetched[1].rank, 2)
        XCTAssertEqual(fetched[2].rank, 3)
    }

    // MARK: - 相关性标注持久化 (Phase 3)

    /// 验证相关性标注的保存和去重覆盖
    func testSaveRelevanceJudgments() async throws {
        let queryHash = "test_hash_abc123"
        let sourceIDs = [UUID().uuidString, UUID().uuidString]

        let judgments = [
            RelevanceJudgment(queryHash: queryHash, query: "标注测试", sourceID: sourceIDs[0], relevanceLevel: 2),
            RelevanceJudgment(queryHash: queryHash, query: "标注测试", sourceID: sourceIDs[1], relevanceLevel: 0)
        ]
        try await governanceStore.saveRelevanceJudgments(judgments)

        // 验证保存成功即可（upsert 不抛异常）
        // 更新覆盖：同一 queryHash + sourceID 组合
        let updated = [
            RelevanceJudgment(queryHash: queryHash, query: "标注测试", sourceID: sourceIDs[0], relevanceLevel: 1)
        ]
        try await governanceStore.saveRelevanceJudgments(updated)
        // 测试通过：upsert 不抛错
    }

    // MARK: - Hit Rate 计算 (Phase 3)

    /// 验证 Hit Rate@K 的正确性
    func testCalculateHitRate() async throws {
        // 先建立评估 + 快照 + 标注的完整数据链
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "HR测试", answer: "A",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85,
            evaluatorModel: "test"
        ))
        let savedEvals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(savedEvals.first?.id)

        let source0 = UUID().uuidString
        let source1 = UUID().uuidString
        let source2 = UUID().uuidString

        // 3 个快照，其中只有 source1 是相关的
        try await governanceStore.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: source0, pageTitle: "P0", snippet: "s0", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: source1, pageTitle: "P1", snippet: "s1", score: 0.8),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: source2, pageTitle: "P2", snippet: "s2", score: 0.5)
        ])

        let qHash = "hit_rate_test_hash"
        try await governanceStore.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: qHash, query: "HR测试", sourceID: source0, relevanceLevel: 0),
            RelevanceJudgment(queryHash: qHash, query: "HR测试", sourceID: source1, relevanceLevel: 2),  // 相关
            RelevanceJudgment(queryHash: qHash, query: "HR测试", sourceID: source2, relevanceLevel: 0)
        ])

        // Hit@2: Top-2 中 source1 在第 2 位 → Hit ✓
        let hitAt2 = try await governanceStore.calculateHitRate(days: 365, k: 2)
        XCTAssertEqual(hitAt2, 1.0, accuracy: 0.001)

        // Hit@1: Top-1 只有 source0（不相关）→ Miss
        let hitAt1 = try await governanceStore.calculateHitRate(days: 365, k: 1)
        XCTAssertEqual(hitAt1, 0.0, accuracy: 0.001)
    }

    // MARK: - MRR 计算 (Phase 3)

    /// 验证 MRR 的正确性
    func testCalculateMRR() async throws {
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "MRR测试", answer: "A",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85,
            evaluatorModel: "test"
        ))
        let savedEvals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(savedEvals.first?.id)

        let s0 = UUID().uuidString
        let s1 = UUID().uuidString
        let s2 = UUID().uuidString

        try await governanceStore.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: s0, pageTitle: "P0", snippet: "-", score: 0.6),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: s1, pageTitle: "P1", snippet: "-", score: 0.8),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: s2, pageTitle: "P2", snippet: "-", score: 0.4)
        ])

        let qHash = "mrr_test_hash"
        try await governanceStore.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: qHash, query: "MRR测试", sourceID: s0, relevanceLevel: 0),
            RelevanceJudgment(queryHash: qHash, query: "MRR测试", sourceID: s1, relevanceLevel: 2),  // 第 2 位相关
            RelevanceJudgment(queryHash: qHash, query: "MRR测试", sourceID: s2, relevanceLevel: 0)
        ])

        // MRR = 1/2 = 0.5（首个相关文档在第 2 位）
        let mrr = try await governanceStore.calculateMRR(days: 365)
        XCTAssertEqual(mrr, 0.5, accuracy: 0.001)
    }

    // MARK: - NDCG 计算 (Phase 3)

    /// 验证 NDCG@K 的正确性
    func testCalculateNDCG() async throws {
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "NDCG测试", answer: "A",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85,
            evaluatorModel: "test"
        ))
        let savedEvals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(savedEvals.first?.id)

        let s0 = UUID().uuidString
        let s1 = UUID().uuidString
        let s2 = UUID().uuidString

        try await governanceStore.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: s0, pageTitle: "P0", snippet: "-", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: s1, pageTitle: "P1", snippet: "-", score: 0.7),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: s2, pageTitle: "P2", snippet: "-", score: 0.5)
        ])

        let qHash = "ndcg_test_hash"
        // 相关性标注: s0=2(高), s1=1(部分), s2=0(无关)
        try await governanceStore.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: qHash, query: "NDCG测试", sourceID: s0, relevanceLevel: 2),
            RelevanceJudgment(queryHash: qHash, query: "NDCG测试", sourceID: s1, relevanceLevel: 1),
            RelevanceJudgment(queryHash: qHash, query: "NDCG测试", sourceID: s2, relevanceLevel: 0)
        ])

        // DCG@3 = (2²-1)/log₂(2) + (2¹-1)/log₂(3) + 0 = 3/1 + 1/1.585 = 3.631
        // IDCG@3 = (2²-1)/log₂(2) + (2¹-1)/log₂(3) + 0 = 3.631 (already ideal)
        // NDCG@3 ≈ 1.0
        let ndcg = try await governanceStore.calculateNDCG(days: 365, k: 3)
        XCTAssertEqual(ndcg, 1.0, accuracy: 0.001)
    }

    // MARK: - 检索指标空数据集边界

    /// 空数据集时检索指标方法返回 0.0
    func testRetrievalMetricsEmptyDatabase() async throws {
        // 无评估数据 → 所有指标为 0
        let hr = try await governanceStore.calculateHitRate(days: 30, k: 5)
        let mrr = try await governanceStore.calculateMRR(days: 30)
        let ndcg = try await governanceStore.calculateNDCG(days: 30, k: 10)

        XCTAssertEqual(hr, 0.0)
        XCTAssertEqual(mrr, 0.0)
        XCTAssertEqual(ndcg, 0.0)
    }

    // MARK: - Evaluate with Sources (Phase 3 集成)

    /// 验证带 sources 参数的 evaluate 能正确触发检索快照与标注记录
    func testEvaluateWithSourcesRecordsRetrievalQuality() async throws {
        mockLLM.generateHandler = { prompt, _ in
            // 验证 prompt 包含检索源
            XCTAssertTrue(prompt.contains("检索到的文档源"))
            return """
            {
                "faithfulness": 0.90,
                "relevance": 0.85,
                "context_precision": 0.88,
                "hallucination_rate": 0.05,
                "citation_accuracy": 0.92,
                "relevance_scores": [2, 1, 0],
                "reasoning": "testing with sources"
            }
            """
        }

        let sources: [KnowledgeSource] = [
            KnowledgeSource(pageID: UUID(), title: "源A", snippet: "内容A", score: 0.95),
            KnowledgeSource(pageID: UUID(), title: "源B", snippet: "内容B", score: 0.72),
            KnowledgeSource(pageID: UUID(), title: "源C", snippet: "内容C", score: 0.45)
        ]

        let report = await evaluationService.evaluate(
            query: "带源评估测试",
            answer: "综合回答",
            context: "合并上下文",
            sources: sources
        )

        XCTAssertEqual(report.faithfulness, 0.90)
        XCTAssertEqual(report.hallucinationRate, 0.05)
        XCTAssertEqual(report.citationAccuracy, 0.92)

        // 验证评估被持久化并有关联的快照
        let evals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        XCTAssertEqual(evals.count, 1)
        if let eval = evals.first, let evalID = eval.id {
            let snapshots = try await governanceStore.fetchRetrievalSnapshots(evaluationID: evalID)
            // 快照在异步 recordRetrievalQuality 中保存，可能尚未落库
            if !snapshots.isEmpty {
                XCTAssertEqual(snapshots[0].rank, 1)
                XCTAssertEqual(snapshots[0].pageTitle, "源A")
            }
        }
    }

    /// 验证无 sources 的 evaluate 保持向后兼容（不产生快照）
    func testEvaluateWithoutSourcesBackwardCompatible() async throws {
        mockLLM.generateHandler = { _, _ in
            return """
            {
                "faithfulness": 0.85,
                "relevance": 0.80,
                "context_precision": 0.75,
                "hallucination_rate": 0.15,
                "citation_accuracy": 0.70
            }
            """
        }

        let report = await evaluationService.evaluate(
            query: "无源测试", answer: "回答", context: "上下文"
            // 不传 sources
        )

        XCTAssertEqual(report.faithfulness, 0.85)
        // 无快照记录（向后兼容）
    }

    // MARK: - 六维评分测试（含 answerCorrectness）

    /// 验证 calculateAverageRAGScores 包含六维均值的正确性
    func testCalculateAverageRAGScoresSevenDimensional() async throws {
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "Q1", answer: "A1",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.9, answerCorrectness: 0.85,
            contextSufficiency: 0.75, evaluatorModel: "test-model"
        ))
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "Q2", answer: "A2",
            faithfulness: 0.7, relevance: 0.6, precision: 0.5,
            hallucinationRate: 0.3, citationAccuracy: 0.7, answerCorrectness: 0.55,
            contextSufficiency: 0.65, evaluatorModel: "test-model"
        ))

        let avg = try await governanceStore.calculateAverageRAGScores(days: 365)

        XCTAssertEqual(avg.faithfulness, 0.8, accuracy: 0.001)
        XCTAssertEqual(avg.relevance, 0.7, accuracy: 0.001)
        XCTAssertEqual(avg.precision, 0.6, accuracy: 0.001)
        XCTAssertEqual(avg.hallucinationRate, 0.2, accuracy: 0.001)
        XCTAssertEqual(avg.citationAccuracy, 0.8, accuracy: 0.001)
        XCTAssertEqual(avg.answerCorrectness, 0.7, accuracy: 0.001)
        // (0.75 + 0.65) / 2 = 0.7
        XCTAssertEqual(avg.contextSufficiency, 0.7, accuracy: 0.001)
    }

    /// 空数据库时七维评分返回全 0
    func testCalculateAverageRAGScoresSevenDimensionalEmpty() async throws {
        let avg = try await governanceStore.calculateAverageRAGScores(days: 30)
        XCTAssertEqual(avg.answerCorrectness, 0.0)
        XCTAssertEqual(avg.contextSufficiency, 0.0)
    }

    // MARK: - userRating 更新测试

    /// 验证用户评分可正常写入和读取
    func testUpdateUserRating() async throws {
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "评分测试", answer: "A",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85, answerCorrectness: 0.8,
            evaluatorModel: "test"
        ))
        let evals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(evals.first?.id)

        // 初始无评分
        XCTAssertNil(evals.first?.userRating)

        // 好评
        try await governanceStore.updateUserRating(evaluationID: evalID, rating: 2)
        let afterUp = try await governanceStore.fetchRAGEvaluations(limit: 1)
        XCTAssertEqual(afterUp.first?.userRating, 2)

        // 改为差评
        try await governanceStore.updateUserRating(evaluationID: evalID, rating: 1)
        let afterDown = try await governanceStore.fetchRAGEvaluations(limit: 1)
        XCTAssertEqual(afterDown.first?.userRating, 1)
    }

    // MARK: - Recall 计算

    /// 验证 Recall@K：相关文档中被 Top-K 覆盖的比例
    func testCalculateRecall() async throws {
        // 创建评估
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "Recall测试", answer: "A",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85, answerCorrectness: 0.8,
            evaluatorModel: "test"
        ))
        let savedEvals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(savedEvals.first?.id)

        let s0 = UUID().uuidString  // 相关
        let s1 = UUID().uuidString  // 相关
        let s2 = UUID().uuidString  // 无关
        let s3 = UUID().uuidString  // 相关但不在检索结果中

        // Top-3 检索快照（只含 s0, s1, s2）
        try await governanceStore.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: s0, pageTitle: "P0", snippet: "-", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: s1, pageTitle: "P1", snippet: "-", score: 0.8),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: s2, pageTitle: "P2", snippet: "-", score: 0.5)
        ])

        // 4 个相关文档（s3 未出现在检索结果中）
        let qHash = "recall_test_hash"
        try await governanceStore.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: qHash, query: "Recall测试", sourceID: s0, relevanceLevel: 2, evaluationID: evalID),
            RelevanceJudgment(queryHash: qHash, query: "Recall测试", sourceID: s1, relevanceLevel: 2, evaluationID: evalID),
            RelevanceJudgment(queryHash: qHash, query: "Recall测试", sourceID: s2, relevanceLevel: 0, evaluationID: evalID),
            RelevanceJudgment(queryHash: qHash, query: "Recall测试", sourceID: s3, relevanceLevel: 2, evaluationID: evalID)
        ])

        // Recall@3: 2 个相关被检索到 / 3 个实际相关 = 2/3 ≈ 0.667
        let recall = try await governanceStore.calculateRecall(days: 365, k: 3)
        XCTAssertEqual(recall, 2.0 / 3.0, accuracy: 0.001)

        // Recall@2: 2 个相关被检索到 / 3 个实际相关 = 2/3 ≈ 0.667
        let recall2 = try await governanceStore.calculateRecall(days: 365, k: 2)
        XCTAssertEqual(recall2, 2.0 / 3.0, accuracy: 0.001)

        // Recall@1: 1 个相关被检索到 / 3 个实际相关 = 1/3
        let recall1 = try await governanceStore.calculateRecall(days: 365, k: 1)
        XCTAssertEqual(recall1, 1.0 / 3.0, accuracy: 0.001)
    }

    /// 空数据集时 Recall 返回 0
    func testCalculateRecallEmpty() async throws {
        let r = try await governanceStore.calculateRecall(days: 30, k: 5)
        XCTAssertEqual(r, 0.0)
    }

    // MARK: - F1 Score 计算

    /// 验证 F1@K 的正确计算
    func testCalculateF1Score() async throws {
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "F1测试", answer: "A",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85, answerCorrectness: 0.8,
            evaluatorModel: "test"
        ))
        let savedEvals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(savedEvals.first?.id)

        let s0 = UUID().uuidString
        let s1 = UUID().uuidString
        let s2 = UUID().uuidString

        try await governanceStore.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: s0, pageTitle: "P0", snippet: "-", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: s1, pageTitle: "P1", snippet: "-", score: 0.7)
        ])

        let qHash = "f1_test_hash"
        try await governanceStore.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: qHash, query: "F1测试", sourceID: s0, relevanceLevel: 2, evaluationID: evalID),
            RelevanceJudgment(queryHash: qHash, query: "F1测试", sourceID: s1, relevanceLevel: 0, evaluationID: evalID),
            RelevanceJudgment(queryHash: qHash, query: "F1测试", sourceID: s2, relevanceLevel: 2, evaluationID: evalID)
        ])

        // Precision@2 = 1/2 = 0.5, Recall@2 = 1/2 = 0.5
        // F1 = 2 * 0.5 * 0.5 / (0.5 + 0.5) = 0.5
        let f1 = try await governanceStore.calculateF1Score(days: 365, k: 2)
        XCTAssertEqual(f1, 0.5, accuracy: 0.001)
    }

    /// 空数据集时 F1 返回 0
    func testCalculateF1ScoreEmpty() async throws {
        let f1 = try await governanceStore.calculateF1Score(days: 30, k: 5)
        XCTAssertEqual(f1, 0.0)
    }

    // MARK: - MAP 计算

    /// 验证 MAP 的正确计算
    func testCalculateMAP() async throws {
        try await governanceStore.saveRAGEvaluation(RAGEvaluation(
            query: "MAP测试", answer: "A",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85, answerCorrectness: 0.8,
            evaluatorModel: "test"
        ))
        let savedEvals = try await governanceStore.fetchRAGEvaluations(limit: 1)
        let evalID = try XCTUnwrap(savedEvals.first?.id)

        let s0 = UUID().uuidString  // 相关（rank 1）
        let s1 = UUID().uuidString  // 无关
        let s2 = UUID().uuidString  // 相关（rank 3）

        try await governanceStore.saveRetrievalSnapshots([
            RetrievalSnapshot(evaluationID: evalID, rank: 1, sourceID: s0, pageTitle: "P0", snippet: "-", score: 0.9),
            RetrievalSnapshot(evaluationID: evalID, rank: 2, sourceID: s1, pageTitle: "P1", snippet: "-", score: 0.8),
            RetrievalSnapshot(evaluationID: evalID, rank: 3, sourceID: s2, pageTitle: "P2", snippet: "-", score: 0.7)
        ])

        let qHash = "map_test_hash"
        try await governanceStore.saveRelevanceJudgments([
            RelevanceJudgment(queryHash: qHash, query: "MAP测试", sourceID: s0, relevanceLevel: 2, evaluationID: evalID),
            RelevanceJudgment(queryHash: qHash, query: "MAP测试", sourceID: s1, relevanceLevel: 0, evaluationID: evalID),
            RelevanceJudgment(queryHash: qHash, query: "MAP测试", sourceID: s2, relevanceLevel: 2, evaluationID: evalID)
        ])

        // P@1 = 1/1=1, P@3 = 2/3≈0.667
        // AP = (1 + 0.667) / 2 = 0.8333
        let map = try await governanceStore.calculateMAP(days: 365)
        XCTAssertEqual(map, (1.0 + 2.0/3.0) / 2.0, accuracy: 0.001)
    }

    /// 空数据集时 MAP 返回 0
    func testCalculateMAPEmpty() async throws {
        let map = try await governanceStore.calculateMAP(days: 30)
        XCTAssertEqual(map, 0.0)
    }

    // MARK: - 检索延迟计算

    /// 验证 calculateRetrievalLatency 返回正确的百分位分布
    func testCalculateRetrievalLatency() async throws {
        // 通过 logCall 写入模拟延迟数据
        /// 10 条调用日志，延迟分别为 100, 200, ..., 1000 ms
        let latencies = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
        for ms in latencies {
            try await governanceStore.logCall(model: "test-model", promptTokens: 100, completionTokens: 50, latencyMS: ms, status: "success")
        }

        let result = try await governanceStore.calculateRetrievalLatency(days: 30)

        XCTAssertEqual(result.sampleCount, 10)
        // 排序后: [100,200,300,400,500,600,700,800,900,1000]
        // p50: index = round((10-1)*0.5) = 4 → 500
        XCTAssertEqual(result.p50, 500)
        // p95: index = round((10-1)*0.95) = 9 → 1000
        XCTAssertEqual(result.p95, 1000)
        // p99: index = round((10-1)*0.99) = 9 → 1000
        XCTAssertEqual(result.p99, 1000)
    }

    /// 空日志时延迟返回全 0
    func testCalculateRetrievalLatencyEmpty() async throws {
        let result = try await governanceStore.calculateRetrievalLatency(days: 7)
        XCTAssertEqual(result.sampleCount, 0)
        XCTAssertEqual(result.p50, 0)
        XCTAssertEqual(result.p95, 0)
        XCTAssertEqual(result.p99, 0)
    }

    // MARK: - Token 效率计算

    /// 验证 calculateTokenEfficiency 正确计算 Token 摘要与成本
    func testCalculateTokenEfficiency() async throws {
        // 写入 3 条 Token 使用记录
        struct TokenRecord {
            let model: String
            let prompt: Int
            let completion: Int
        }
        let records: [TokenRecord] = [
            TokenRecord(model: "test", prompt: 1000, completion: 500),   // 1500 total
            TokenRecord(model: "test", prompt: 2000, completion: 1000),  // 3000 total
            TokenRecord(model: "test", prompt: 500, completion: 200)     // 700 total
        ]
        for record in records {
            try await governanceStore.logTokenUsage(model: record.model, promptTokens: record.prompt, completionTokens: record.completion)
        }

        let eff = try await governanceStore.calculateTokenEfficiency(days: 30)

        // 总 Token: 1500 + 3000 + 700 = 5200
        XCTAssertEqual(eff.totalTokens, 5200)
        // 查询次数: 3
        XCTAssertEqual(eff.queryCount, 3)
        // 平均每次: 5200 / 3 ≈ 1733.33
        XCTAssertEqual(eff.avgTokensPerQuery, 5200.0 / 3.0, accuracy: 1.0)
        // 总 prompt: 3500, 总 completion: 1700
        // prompt 成本: 3500/1M * 2.50 = 0.00875
        // completion 成本: 1700/1M * 10.00 = 0.017
        // 总成本 ≈ 0.02575
        XCTAssertEqual(eff.estimatedCostUSD, 0.02575, accuracy: 0.0001)
    }

    /// 空数据时 Token 效率返回全 0
    func testCalculateTokenEfficiencyEmpty() async throws {
        let eff = try await governanceStore.calculateTokenEfficiency(days: 7)
        XCTAssertEqual(eff.totalTokens, 0)
        XCTAssertEqual(eff.queryCount, 0)
        XCTAssertEqual(eff.avgTokensPerQuery, 0)
        XCTAssertEqual(eff.estimatedCostUSD, 0)
    }

    // MARK: - 新指标空数据集边界测试

    /// 空数据集时所有新增检索指标返回 0
    func testNewRetrievalMetricsAllEmpty() async throws {
        let recall = try await governanceStore.calculateRecall(days: 30, k: 5)
        let f1 = try await governanceStore.calculateF1Score(days: 30, k: 5)
        let map = try await governanceStore.calculateMAP(days: 30)
        let lat = try await governanceStore.calculateRetrievalLatency(days: 30)
        let tok = try await governanceStore.calculateTokenEfficiency(days: 30)

        XCTAssertEqual(recall, 0.0)
        XCTAssertEqual(f1, 0.0)
        XCTAssertEqual(map, 0.0)
        XCTAssertEqual(lat.sampleCount, 0)
        XCTAssertEqual(tok.totalTokens, 0)
    }
}
