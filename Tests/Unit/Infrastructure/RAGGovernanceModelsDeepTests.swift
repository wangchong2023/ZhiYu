//
//  RAGGovernanceModelsDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 Infrastructure 层纯数据模型 RAGGovernanceModels
//           （TokenUsage / RAGEvaluation / LLMCallLog / RetrievalSnapshot /
//           RelevanceJudgment）的 init 默认值、CodingKeys 映射、Codable 编解码往返。
//

import XCTest
@testable import ZhiYu

// MARK: - RAGGovernanceModels 测试

final class RAGGovernanceModelsDeepTests: XCTestCase {

    /// 验证 TokenUsage init 含默认值
    func testTokenUsageInitWithDefaults() {
        let usage = TokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        XCTAssertNil(usage.id)
        XCTAssertEqual(usage.model, "gpt-4")
        XCTAssertEqual(usage.promptTokens, 100)
        XCTAssertEqual(usage.completionTokens, 50)
        XCTAssertEqual(usage.totalTokens, 150)
        XCTAssertNotNil(usage.createdAt)
    }

    /// 验证 TokenUsage totalTokens 自动计算
    func testTokenUsageTotalTokensCalculation() {
        let usage = TokenUsage(model: "claude", promptTokens: 200, completionTokens: 80)
        XCTAssertEqual(usage.totalTokens, 280)
    }

    /// 验证 TokenUsage databaseTableName
    func testTokenUsageDatabaseTableName() {
        XCTAssertFalse(TokenUsage.databaseTableName.isEmpty)
    }

    /// 验证 TokenUsage Codable 往返（snake_case 映射）
    func testTokenUsageCodableRoundTrip() throws {
        let original = TokenUsage(id: 1, model: "gpt-4", promptTokens: 100, completionTokens: 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.promptTokens, original.promptTokens)
        XCTAssertEqual(decoded.completionTokens, original.completionTokens)
        XCTAssertEqual(decoded.totalTokens, original.totalTokens)
    }

    /// 验证 RAGEvaluation init 含默认值
    func testRAGEvaluationInitWithDefaults() {
        let eval = RAGEvaluation(
            query: "问题",
            answer: "回答",
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.7,
            evaluatorModel: "gpt-4"
        )
        XCTAssertNil(eval.id)
        XCTAssertEqual(eval.query, "问题")
        XCTAssertEqual(eval.answer, "回答")
        XCTAssertEqual(eval.faithfulness, 0.9)
        XCTAssertEqual(eval.relevance, 0.8)
        XCTAssertEqual(eval.precision, 0.7)
        XCTAssertEqual(eval.hallucinationRate, 0.0)
        XCTAssertEqual(eval.citationAccuracy, 0.0)
        XCTAssertEqual(eval.answerCorrectness, 0.0)
        XCTAssertEqual(eval.contextSufficiency, 0.0)
        XCTAssertNil(eval.userRating)
        XCTAssertEqual(eval.evaluatorModel, "gpt-4")
    }

    /// 验证 RAGEvaluation init 含全部参数
    func testRAGEvaluationInitWithAllParameters() {
        let eval = RAGEvaluation(
            id: 10,
            query: "Q",
            answer: "A",
            faithfulness: 0.95,
            relevance: 0.85,
            precision: 0.75,
            hallucinationRate: 0.1,
            citationAccuracy: 0.9,
            answerCorrectness: 0.88,
            contextSufficiency: 0.8,
            userRating: 2,
            evaluatorModel: "claude"
        )
        XCTAssertEqual(eval.id, 10)
        XCTAssertEqual(eval.hallucinationRate, 0.1)
        XCTAssertEqual(eval.citationAccuracy, 0.9)
        XCTAssertEqual(eval.answerCorrectness, 0.88)
        XCTAssertEqual(eval.contextSufficiency, 0.8)
        XCTAssertEqual(eval.userRating, 2)
    }

    /// 验证 RAGEvaluation Codable 往返
    func testRAGEvaluationCodableRoundTrip() throws {
        let original = RAGEvaluation(
            id: 1,
            query: "查询",
            answer: "答案",
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.7,
            hallucinationRate: 0.05,
            citationAccuracy: 0.95,
            answerCorrectness: 0.9,
            contextSufficiency: 0.85,
            userRating: 1,
            evaluatorModel: "gpt-4"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RAGEvaluation.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.query, original.query)
        XCTAssertEqual(decoded.faithfulness, original.faithfulness)
        XCTAssertEqual(decoded.hallucinationRate, original.hallucinationRate)
        XCTAssertEqual(decoded.citationAccuracy, original.citationAccuracy)
        XCTAssertEqual(decoded.userRating, original.userRating)
    }

    /// 验证 LLMCallLog init
    func testLLMCallLogInit() {
        let log = LLMCallLog(
            model: "gpt-4",
            promptTokens: 100,
            completionTokens: 50,
            latencyMS: 200,
            status: "success"
        )
        XCTAssertNil(log.id)
        XCTAssertEqual(log.model, "gpt-4")
        XCTAssertEqual(log.promptTokens, 100)
        XCTAssertEqual(log.completionTokens, 50)
        XCTAssertEqual(log.latencyMS, 200)
        XCTAssertEqual(log.status, "success")
    }

    /// 验证 LLMCallLog Codable 往返
    func testLLMCallLogCodableRoundTrip() throws {
        let original = LLMCallLog(
            id: 5,
            model: "claude",
            promptTokens: 200,
            completionTokens: 100,
            latencyMS: 500,
            status: "error"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMCallLog.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.latencyMS, original.latencyMS)
        XCTAssertEqual(decoded.status, original.status)
    }

    /// 验证 RetrievalSnapshot init
    func testRetrievalSnapshotInit() {
        let snapshot = RetrievalSnapshot(
            evaluationID: 1,
            rank: 1,
            sourceID: "uuid-123",
            pageTitle: "标题",
            snippet: "片段",
            score: 0.95
        )
        XCTAssertNil(snapshot.id)
        XCTAssertEqual(snapshot.evaluationID, 1)
        XCTAssertEqual(snapshot.rank, 1)
        XCTAssertEqual(snapshot.sourceID, "uuid-123")
        XCTAssertEqual(snapshot.pageTitle, "标题")
        XCTAssertEqual(snapshot.snippet, "片段")
        XCTAssertEqual(snapshot.score, 0.95)
    }

    /// 验证 RetrievalSnapshot Codable 往返
    func testRetrievalSnapshotCodableRoundTrip() throws {
        let original = RetrievalSnapshot(
            id: 10,
            evaluationID: 2,
            rank: 3,
            sourceID: "src-456",
            pageTitle: "页面",
            snippet: "文本片段",
            score: 0.88
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetrievalSnapshot.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.evaluationID, original.evaluationID)
        XCTAssertEqual(decoded.rank, original.rank)
        XCTAssertEqual(decoded.sourceID, original.sourceID)
        XCTAssertEqual(decoded.score, original.score)
    }

    /// 验证 RelevanceJudgment init 含默认值
    func testRelevanceJudgmentInitWithDefaults() {
        let judgment = RelevanceJudgment(
            queryHash: "abc123",
            query: "查询",
            sourceID: "src-1",
            relevanceLevel: 2
        )
        XCTAssertNil(judgment.id)
        XCTAssertEqual(judgment.queryHash, "abc123")
        XCTAssertEqual(judgment.query, "查询")
        XCTAssertEqual(judgment.sourceID, "src-1")
        XCTAssertEqual(judgment.relevanceLevel, 2)
        XCTAssertEqual(judgment.judgeSource, "llm-auto")
        XCTAssertNil(judgment.evaluationID)
    }

    /// 验证 RelevanceJudgment init 含全部参数
    func testRelevanceJudgmentInitWithAllParameters() {
        let judgment = RelevanceJudgment(
            id: 20,
            queryHash: "hash",
            query: "Q",
            sourceID: "src",
            relevanceLevel: 0,
            judgeSource: "manual",
            evaluationID: 5
        )
        XCTAssertEqual(judgment.id, 20)
        XCTAssertEqual(judgment.judgeSource, "manual")
        XCTAssertEqual(judgment.evaluationID, 5)
    }

    /// 验证 RelevanceJudgment Codable 往返
    func testRelevanceJudgmentCodableRoundTrip() throws {
        let original = RelevanceJudgment(
            id: 1,
            queryHash: "sha256",
            query: "问题",
            sourceID: "source",
            relevanceLevel: 1,
            judgeSource: "manual",
            evaluationID: 3
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RelevanceJudgment.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.queryHash, original.queryHash)
        XCTAssertEqual(decoded.relevanceLevel, original.relevanceLevel)
        XCTAssertEqual(decoded.judgeSource, original.judgeSource)
        XCTAssertEqual(decoded.evaluationID, original.evaluationID)
    }
}
