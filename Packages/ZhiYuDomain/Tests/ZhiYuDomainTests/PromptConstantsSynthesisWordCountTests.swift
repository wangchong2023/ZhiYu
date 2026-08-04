//
//  PromptConstantsSynthesisWordCountTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 PromptConstants.SynthesisWordCount 的字数区间不变量。
//           每个档位的 minWords 必须小于 maxWords，且档位间必须递进不重叠。
//

import XCTest
@testable import ZhiYuDomain

final class PromptConstantsSynthesisWordCountTests: XCTestCase {

    /// 精简档：minWords < maxWords
    func testConciseRangeValid() {
        XCTAssertLessThan(PromptConstants.SynthesisWordCount.conciseMinWords,
                          PromptConstants.SynthesisWordCount.conciseMaxWords)
    }

    /// 标准档：minWords < maxWords
    func testStandardRangeValid() {
        XCTAssertLessThan(PromptConstants.SynthesisWordCount.standardMinWords,
                          PromptConstants.SynthesisWordCount.standardMaxWords)
    }

    /// 详尽档：minWords < maxWords
    func testComprehensiveRangeValid() {
        XCTAssertLessThan(PromptConstants.SynthesisWordCount.comprehensiveMinWords,
                          PromptConstants.SynthesisWordCount.comprehensiveMaxWords)
    }

    /// 三档必须递进：concise.max < standard.min
    func testConciseMaxLessThanStandardMin() {
        XCTAssertLessThan(PromptConstants.SynthesisWordCount.conciseMaxWords,
                          PromptConstants.SynthesisWordCount.standardMinWords,
                          "精简档上限必须小于标准档下限，避免档位重叠")
    }

    /// 三档必须递进：standard.max < comprehensive.min
    func testStandardMaxLessThanComprehensiveMin() {
        XCTAssertLessThan(PromptConstants.SynthesisWordCount.standardMaxWords,
                          PromptConstants.SynthesisWordCount.comprehensiveMinWords,
                          "标准档上限必须小于详尽档下限，避免档位重叠")
    }

    /// 所有 minWords 必须为正数
    func testAllMinWordsPositive() {
        XCTAssertGreaterThan(PromptConstants.SynthesisWordCount.conciseMinWords, 0)
        XCTAssertGreaterThan(PromptConstants.SynthesisWordCount.standardMinWords, 0)
        XCTAssertGreaterThan(PromptConstants.SynthesisWordCount.comprehensiveMinWords, 0)
    }

    /// 详尽档上限不应过大（避免 LLM 输出失控）
    func testComprehensiveMaxWordsReasonable() {
        XCTAssertLessThanOrEqual(PromptConstants.SynthesisWordCount.comprehensiveMaxWords, 10_000,
                                 "详尽档上限不应超过 10000 字")
    }
}
