//
//  InfrastructureModelsTests.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

/// PDFModels 单元测试
/// 验证 PDFDocumentInfo / PDFHighlight 数据模型与 Codable 往返
final class PDFModelsTests: XCTestCase {

    // MARK: - PDFHighlight

    /// 验证 PDFHighlight init 默认值
    func testPDFHighlightInitDefaults() {
        let highlight = PDFHighlight(pageIndex: 5, text: "高亮文本")
        XCTAssertEqual(highlight.pageIndex, 5)
        XCTAssertEqual(highlight.text, "高亮文本")
        XCTAssertEqual(highlight.color, "yellow")
        XCTAssertEqual(highlight.note, "")
        XCTAssertNotNil(highlight.id)
    }

    /// 验证 PDFHighlight 全参数 init
    func testPDFHighlightInitAllParameters() {
        let id = UUID()
        let date = Date()
        let highlight = PDFHighlight(
            id: id,
            pageIndex: 10,
            text: "text",
            color: "green",
            note: "备注",
            creationDate: date
        )
        XCTAssertEqual(highlight.id, id)
        XCTAssertEqual(highlight.pageIndex, 10)
        XCTAssertEqual(highlight.color, "green")
        XCTAssertEqual(highlight.note, "备注")
        XCTAssertEqual(highlight.creationDate, date)
    }

    /// 验证 PDFHighlight Codable 往返    // MARK: - PDFDocumentInfo

    /// 验证 PDFDocumentInfo init 默认值
    func testPDFDocumentInfoInitDefaults() {
        let doc = PDFDocumentInfo(title: "文档", fileName: "doc.pdf", pageCount: 100)
        XCTAssertEqual(doc.title, "文档")
        XCTAssertEqual(doc.fileName, "doc.pdf")
        XCTAssertEqual(doc.pageCount, 100)
        XCTAssertEqual(doc.lastReadPage, 0)
        XCTAssertTrue(doc.highlights.isEmpty)
        XCTAssertTrue(doc.linkedPageTitles.isEmpty)
        XCTAssertNotNil(doc.id)
    }

    /// 验证 PDFDocumentInfo 全参数 init
    func testPDFDocumentInfoInitAllParameters() {
        let id = UUID()
        let date = Date()
        let highlights = [PDFHighlight(pageIndex: 1, text: "h")]
        let doc = PDFDocumentInfo(
            id: id,
            title: "T",
            fileName: "f.pdf",
            pageCount: 50,
            addedDate: date,
            lastReadPage: 10,
            highlights: highlights,
            linkedPageTitles: ["page1", "page2"]
        )
        XCTAssertEqual(doc.id, id)
        XCTAssertEqual(doc.addedDate, date)
        XCTAssertEqual(doc.lastReadPage, 10)
        XCTAssertEqual(doc.highlights.count, 1)
        XCTAssertEqual(doc.linkedPageTitles, ["page1", "page2"])
    }

    /// 验证 PDFDocumentInfo Codable 往返    /// 验证 PDFDocumentInfo 空高亮列表编解码
    func testPDFDocumentInfoCodableEmptyHighlights() throws {
        let original = PDFDocumentInfo(title: "t", fileName: "f.pdf", pageCount: 1)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PDFDocumentInfo.self, from: data)
        XCTAssertTrue(decoded.highlights.isEmpty)
        XCTAssertTrue(decoded.linkedPageTitles.isEmpty)
    }
}

/// RAGGovernanceModels 单元测试
/// 验证 TokenUsage / RAGEvaluation / LLMCallLog / RetrievalSnapshot / RelevanceJudgment 数据模型
final class RAGGovernanceModelsTests: XCTestCase {

    // MARK: - TokenUsage

    /// 验证 TokenUsage init 计算 totalTokens
    func testTokenUsageInitComputesTotalTokens() {
        let usage = TokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        XCTAssertEqual(usage.promptTokens, 100)
        XCTAssertEqual(usage.completionTokens, 50)
        XCTAssertEqual(usage.totalTokens, 150)
        XCTAssertNil(usage.id)
    }

    /// 验证 TokenUsage databaseTableName    /// 验证 TokenUsage Codable 往返（snake_case）    // MARK: - RAGEvaluation

    /// 验证 RAGEvaluation init 默认值
    func testRAGEvaluationInitDefaults() {
        let eval = RAGEvaluation(
            query: "q",
            answer: "a",
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.7,
            evaluatorModel: "gpt-4"
        )
        XCTAssertEqual(eval.query, "q")
        XCTAssertEqual(eval.faithfulness, 0.9)
        XCTAssertEqual(eval.relevance, 0.8)
        XCTAssertEqual(eval.precision, 0.7)
        XCTAssertEqual(eval.hallucinationRate, 0.0)
        XCTAssertEqual(eval.citationAccuracy, 0.0)
        XCTAssertEqual(eval.answerCorrectness, 0.0)
        XCTAssertEqual(eval.contextSufficiency, 0.0)
        XCTAssertNil(eval.userRating)
        XCTAssertNil(eval.id)
    }

    /// 验证 RAGEvaluation 全参数 init
    func testRAGEvaluationInitAllParameters() {
        let eval = RAGEvaluation(
            id: 5,
            query: "q",
            answer: "a",
            faithfulness: 1.0,
            relevance: 0.9,
            precision: 0.8,
            hallucinationRate: 0.1,
            citationAccuracy: 0.95,
            answerCorrectness: 0.85,
            contextSufficiency: 0.75,
            userRating: 2,
            evaluatorModel: "claude"
        )
        XCTAssertEqual(eval.id, 5)
        XCTAssertEqual(eval.hallucinationRate, 0.1)
        XCTAssertEqual(eval.citationAccuracy, 0.95)
        XCTAssertEqual(eval.answerCorrectness, 0.85)
        XCTAssertEqual(eval.contextSufficiency, 0.75)
        XCTAssertEqual(eval.userRating, 2)
    }

    /// 验证 RAGEvaluation databaseTableName
    func testRAGEvaluationDatabaseTableName() {
        XCTAssertEqual(RAGEvaluation.databaseTableName, AppConstants.Storage.Tables.ragEvaluations)
    }

    /// 验证 RAGEvaluation Codable 往返（snake_case keys）    // MARK: - LLMCallLog

    /// 验证 LLMCallLog init    /// 验证 LLMCallLog databaseTableName
    func testLLMCallLogDatabaseTableName() {
        XCTAssertEqual(LLMCallLog.databaseTableName, AppConstants.Storage.Tables.llmCallLogs)
    }

    /// 验证 LLMCallLog Codable 往返（snake_case keys）    // MARK: - RetrievalSnapshot

    /// 验证 RetrievalSnapshot init    /// 验证 RetrievalSnapshot databaseTableName
    func testRetrievalSnapshotDatabaseTableName() {
        XCTAssertEqual(RetrievalSnapshot.databaseTableName, AppConstants.Storage.Tables.retrievalSnapshots)
    }

    /// 验证 RetrievalSnapshot Codable 往返（snake_case keys）    // MARK: - RelevanceJudgment

    /// 验证 RelevanceJudgment init 默认值
    func testRelevanceJudgmentInitDefaults() {
        let judgment = RelevanceJudgment(
            queryHash: "hash123",
            query: "查询",
            sourceID: "src-1",
            relevanceLevel: 2
        )
        XCTAssertEqual(judgment.queryHash, "hash123")
        XCTAssertEqual(judgment.query, "查询")
        XCTAssertEqual(judgment.sourceID, "src-1")
        XCTAssertEqual(judgment.relevanceLevel, 2)
        XCTAssertEqual(judgment.judgeSource, "llm-auto")
        XCTAssertNil(judgment.evaluationID)
        XCTAssertNil(judgment.id)
    }

    /// 验证 RelevanceJudgment 全参数 init
    func testRelevanceJudgmentInitAllParameters() {
        let judgment = RelevanceJudgment(
            id: 7,
            queryHash: "h",
            query: "q",
            sourceID: "s",
            relevanceLevel: 0,
            judgeSource: "manual",
            evaluationID: 99
        )
        XCTAssertEqual(judgment.id, 7)
        XCTAssertEqual(judgment.relevanceLevel, 0)
        XCTAssertEqual(judgment.judgeSource, "manual")
        XCTAssertEqual(judgment.evaluationID, 99)
    }

    /// 验证 RelevanceJudgment databaseTableName
    func testRelevanceJudgmentDatabaseTableName() {
        XCTAssertEqual(RelevanceJudgment.databaseTableName, AppConstants.Storage.Tables.relevanceJudgments)
    }

    /// 验证 RelevanceJudgment Codable 往返（snake_case keys）
    func testRelevanceJudgmentCodableRoundTrip() throws {
        let judgment = RelevanceJudgment(id: 1, queryHash: "hash1", query: "test", sourceID: "doc1", relevanceLevel: 2, judgeSource: "auto", evaluationID: 1)
        let encoded = try JSONEncoder().encode(judgment)
        let decoded = try JSONDecoder().decode(RelevanceJudgment.self, from: encoded)
        XCTAssertEqual(decoded.id, judgment.id)
        XCTAssertEqual(decoded.query, judgment.query)
    }
}
