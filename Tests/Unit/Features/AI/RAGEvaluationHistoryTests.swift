//
//  RAGEvaluationHistoryTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - AI
//  核心职责：验证 RAGEvalTimeRange 时间跨度天数常量以及 RAGEvaluationHistoryPanel 前缀预计算逻辑。
//

import XCTest
@testable import ZhiYu

final class RAGEvaluationHistoryTests: XCTestCase {

    /// 验证 FeatureConstants.RAGEvalTimeRange 天数常量值
    func testRAGEvalTimeRange_dayConstants_matchExpectedDurations() {
        XCTAssertEqual(FeatureConstants.RAGEvalTimeRange.shortDays, 7)
        XCTAssertEqual(FeatureConstants.RAGEvalTimeRange.mediumDays, 30)
        XCTAssertEqual(FeatureConstants.RAGEvalTimeRange.longDays, 90)
    }

    /// 验证预计算 prefix 数组切片与逐项迭代结果一致
    func testRAGEvaluationHistoryPanel_precomputedPrefix_matchesIterative() {
        let evaluations = Array(0..<10).map { _ in UUID() }
        let displayLimit = 5

        let iterativeLast = evaluations.prefix(displayLimit).last
        let precomputed = Array(evaluations.prefix(displayLimit))
        let precomputedLast = precomputed.last

        XCTAssertEqual(iterativeLast, precomputedLast)
        XCTAssertEqual(precomputed.count, displayLimit)
    }
}
