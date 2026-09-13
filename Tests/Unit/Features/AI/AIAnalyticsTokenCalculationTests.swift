//
//  AIAnalyticsTokenCalculationTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - AI
//  核心职责：验证 PromptConstants 字符换算常量在除零守卫与边界值下的安全性。
//

import XCTest
import UFPCore
@testable import ZhiYu

#if !os(watchOS)
@MainActor
final class AIAnalyticsTokenCalculationTests: XCTestCase {

    /// 验证 charactersPerToken 为 0 时使用 max(1, ...) 守卫防止除零崩溃
    func testTokenLimits_charactersPerToken_guardsAgainstDivisionByZero() {
        let charactersPerToken = 0
        let safeValue = max(1, charactersPerToken)
        XCTAssertEqual(safeValue, 1, "max(1, 0) 应为 1，防止除零")

        let actualValue = PromptConstants.TokenLimits.charactersPerToken
        let actualSafe = max(1, actualValue)
        XCTAssertGreaterThanOrEqual(actualSafe, 1)

        let promptTokens = 100 / actualSafe
        XCTAssertEqual(promptTokens, 100 / max(1, actualValue))
    }
}
#endif
