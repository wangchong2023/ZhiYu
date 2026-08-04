//
//  PromptConstantsInferenceDefaultsTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 PromptConstants.InferenceDefaults 的推理参数语义。
//           temperature/topP 必须在 [0,1] 范围，penalty 必须非负。
//

import XCTest
@testable import ZhiYuDomain

final class PromptConstantsInferenceDefaultsTests: XCTestCase {

    /// defaultTemperature 必须在 (0, 1] 范围
    func testTemperatureInRange() {
        let t = PromptConstants.InferenceDefaults.defaultTemperature
        XCTAssertGreaterThan(t, 0, "temperature 必须大于 0（0 表示完全确定性）")
        XCTAssertLessThanOrEqual(t, 1.0, "temperature 不应超过 1.0")
    }

    /// defaultTopP 必须在 (0, 1] 范围
    func testTopPInRange() {
        let p = PromptConstants.InferenceDefaults.defaultTopP
        XCTAssertGreaterThan(p, 0)
        XCTAssertLessThanOrEqual(p, 1.0)
    }

    /// defaultPresencePenalty 必须非负
    func testPresencePenaltyNonNegative() {
        XCTAssertGreaterThanOrEqual(PromptConstants.InferenceDefaults.defaultPresencePenalty, 0)
    }

    /// defaultPresencePenalty 不应过大（避免输出不连贯）
    func testPresencePenaltyReasonable() {
        XCTAssertLessThanOrEqual(PromptConstants.InferenceDefaults.defaultPresencePenalty, 2.0,
                                 "presence penalty 不应超过 2.0")
    }

    /// temperature + topP 组合不应导致过度随机
    func testTemperatureTopPCombinationSafe() {
        let t = PromptConstants.InferenceDefaults.defaultTemperature
        let p = PromptConstants.InferenceDefaults.defaultTopP
        // 经验法则：t * p 不应过低（避免输出退化）
        XCTAssertGreaterThan(t * p, 0.3, "temperature * topP 不应低于 0.3，避免输出过于保守")
    }
}
