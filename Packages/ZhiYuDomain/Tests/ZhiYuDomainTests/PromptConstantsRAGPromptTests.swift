//
//  PromptConstantsRAGPromptTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 PromptConstants.RAGPrompt 的语义不变量。
//           这些常量决定系统提示词的上下文注入量，过大导致 Token 爆炸，过小导致 RAG 失效。
//

import XCTest
@testable import ZhiYuDomain

final class PromptConstantsRAGPromptTests: XCTestCase {

    /// maxEntityOverview 必须为正数
    func testMaxEntityOverviewPositive() {
        XCTAssertGreaterThan(PromptConstants.RAGPrompt.maxEntityOverview, 0)
    }

    /// maxConceptOverview 必须为正数
    func testMaxConceptOverviewPositive() {
        XCTAssertGreaterThan(PromptConstants.RAGPrompt.maxConceptOverview, 0)
    }

    /// maxSourceOverview 必须为正数
    func testMaxSourceOverviewPositive() {
        XCTAssertGreaterThan(PromptConstants.RAGPrompt.maxSourceOverview, 0)
    }

    /// maxRecentOverview 必须为正数且小于 maxEntityOverview（最近更新是子集）
    func testMaxRecentOverviewSmallerThanEntity() {
        XCTAssertGreaterThan(PromptConstants.RAGPrompt.maxRecentOverview, 0)
        XCTAssertLessThanOrEqual(PromptConstants.RAGPrompt.maxRecentOverview,
                                 PromptConstants.RAGPrompt.maxEntityOverview)
    }

    /// contentPreviewLength 必须为正数且合理（100 字符是预览长度）
    func testContentPreviewLengthReasonable() {
        XCTAssertGreaterThan(PromptConstants.RAGPrompt.contentPreviewLength, 0)
        XCTAssertLessThanOrEqual(PromptConstants.RAGPrompt.contentPreviewLength, 500)
    }

    /// contextPreviewLength 必须大于 contentPreviewLength（查询上下文需要更详细预览）
    func testContextPreviewLargerThanContentPreview() {
        XCTAssertGreaterThan(PromptConstants.RAGPrompt.contextPreviewLength,
                             PromptConstants.RAGPrompt.contentPreviewLength,
                             "查询上下文预览必须比系统提示词预览更长")
    }

    /// maxContextPages 必须为正数且合理
    func testMaxContextPagesReasonable() {
        XCTAssertGreaterThan(PromptConstants.RAGPrompt.maxContextPages, 0)
        XCTAssertLessThanOrEqual(PromptConstants.RAGPrompt.maxContextPages, 20,
                                 "上下文页面数不应超过 20，避免 Token 爆炸")
    }

    /// 所有 RAG 限制值的总和不应超过 Token 上下文窗口
    func testRAGLimitsTotalWithinTokenBudget() {
        let totalOverview = PromptConstants.RAGPrompt.maxEntityOverview
            + PromptConstants.RAGPrompt.maxConceptOverview
            + PromptConstants.RAGPrompt.maxSourceOverview
            + PromptConstants.RAGPrompt.maxRecentOverview
        // 概览项总数不应过大
        XCTAssertLessThanOrEqual(totalOverview, 100,
                                 "概览项总数不应超过 100，避免系统提示词过长")
    }
}
