//
//  PromptConstantsTokenLimitsTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 PromptConstants.TokenLimits 的语义不变量。
//           这些常量直接决定 LLM 上下文窗口与用户输入边界，错误值会导致 API 失败或安全漏洞。
//

import XCTest
@testable import ZhiYuDomain

final class PromptConstantsTokenLimitsTests: XCTestCase {

    /// charactersPerToken 必须为正数（约 4 字符/Token 是英文经验值）
    func testCharactersPerTokenPositive() {
        XCTAssertGreaterThan(PromptConstants.TokenLimits.charactersPerToken, 0)
    }

    /// maxUserInputLength 必须为正数且合理（不超过 LLM 上下文窗口）
    func testMaxUserInputLengthPositive() {
        XCTAssertGreaterThan(PromptConstants.TokenLimits.maxUserInputLength, 0)
        XCTAssertLessThanOrEqual(PromptConstants.TokenLimits.maxUserInputLength, 100_000)
    }

    /// maxSynthesisInputLength 必须大于 maxUserInputLength（合成需要更多上下文）
    func testSynthesisInputLargerThanUserInput() {
        XCTAssertGreaterThan(PromptConstants.TokenLimits.maxSynthesisInputLength,
                             PromptConstants.TokenLimits.maxUserInputLength,
                             "RAG 合成输入必须比单次用户输入更大")
    }

    /// defaultMaxOutputTokens 必须为正数且在 LLM 模型限制内
    func testDefaultMaxOutputTokensReasonable() {
        XCTAssertGreaterThan(PromptConstants.TokenLimits.defaultMaxOutputTokens, 0)
        // GPT-4 最大 4096 输出 Token，3072 是安全值
        XCTAssertLessThanOrEqual(PromptConstants.TokenLimits.defaultMaxOutputTokens, 4096)
    }

    /// maxChatHistorySize 必须为正数（RAG 历史轮数限制）
    func testMaxChatHistorySizePositive() {
        XCTAssertGreaterThan(PromptConstants.TokenLimits.maxChatHistorySize, 0)
    }

    /// maxChatHistorySize 不应过大（避免上下文爆炸）
    func testMaxChatHistorySizeReasonable() {
        XCTAssertLessThanOrEqual(PromptConstants.TokenLimits.maxChatHistorySize, 50,
                                 "历史轮数不应超过 50，避免上下文窗口溢出")
    }

    /// Token 估算一致性：maxUserInputLength / charactersPerToken 应在合理 Token 范围
    func testTokenEstimationConsistency() {
        let estimatedTokens = PromptConstants.TokenLimits.maxUserInputLength
            / PromptConstants.TokenLimits.charactersPerToken
        XCTAssertGreaterThan(estimatedTokens, 100,
                             "用户输入应至少支持 100 Token")
        XCTAssertLessThan(estimatedTokens, 10_000,
                          "用户输入不应超过 10000 Token（避免成本失控）")
    }
}
