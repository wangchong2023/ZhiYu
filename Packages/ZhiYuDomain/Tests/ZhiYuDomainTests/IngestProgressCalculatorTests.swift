//
//  IngestProgressCalculatorTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证知识摄入进度安全计算器（clampProgress / formatPercentage / resolveTaskProgress）
//           在正常值、NaN / 无穷大等极端输入下的钳位与格式化安全，杜绝闪退。
//

import XCTest
@testable import ZhiYuDomain

final class IngestProgressCalculatorTests: XCTestCase {

    // MARK: - clampProgress

    /// 验证正常值被正确钳位在 [0.0, 1.0]
    func testClampProgress_NormalValues() {
        XCTAssertEqual(IngestProgressCalculator.clampProgress(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(1.0), 1.0, accuracy: 0.001)
    }

    /// 验证越界与 NaN / 无穷大被安全钳位为保底值
    func testClampProgress_ExtremeValues() {
        XCTAssertEqual(IngestProgressCalculator.clampProgress(-0.5), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(1.5), 1.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(Double.nan), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(Double.infinity), 0.0, accuracy: 0.001)
        XCTAssertEqual(IngestProgressCalculator.clampProgress(-Double.infinity), 0.0, accuracy: 0.001)
    }

    // MARK: - formatPercentage

    /// 验证浮点进度格式化为 0 ~ 100 整数
    func testFormatPercentage_ValidRanges() {
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(0.42), 42)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(0.0), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(1.0), 100)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(999.0), 100)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(-10.0), 0)
    }

    /// 验证 NaN / 无穷大格式化不崩溃并返回保底值
    func testFormatPercentage_ExtremeValues() {
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(Double.nan), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(Double.infinity), 0)
        XCTAssertEqual(IngestProgressCalculator.formatPercentage(-Double.infinity), 0)
    }

    // MARK: - resolveTaskProgress

    /// 验证 nil 任务返回保底进度与 pending 阶段
    func testResolveTaskProgress_NilTask() {
        let (progress, stage) = IngestProgressCalculator.resolveTaskProgress(nil)
        XCTAssertEqual(progress, 0.0)
        XCTAssertEqual(stage, .pending)
    }

    /// 验证运行中任务返回其原始进度与阶段
    func testResolveTaskProgress_RunningTask() {
        let task = GlobalTask(type: .ingest, name: "导入", target: "目标", status: .running(progress: 0.6, stage: .embedding))
        let (progress, stage) = IngestProgressCalculator.resolveTaskProgress(task)
        XCTAssertEqual(progress, 0.6, accuracy: 0.001)
        XCTAssertEqual(stage, .embedding)
    }

    /// 验证非运行状态任务返回保底值
    func testResolveTaskProgress_NonRunningTask() {
        let task = GlobalTask(type: .ingest, name: "导入", target: "目标", status: .completed)
        let (progress, stage) = IngestProgressCalculator.resolveTaskProgress(task)
        XCTAssertEqual(progress, 0.0)
        XCTAssertEqual(stage, .pending)
    }

    /// Fuzz：100 个随机浮点值永不崩溃
    func testFuzz100RandomValues_NeverCrashes() {
        for _ in 0..<100 {
            let randomDouble = Double.random(in: -1000...1000)
            let clamped = IngestProgressCalculator.clampProgress(randomDouble)
            let pct = IngestProgressCalculator.formatPercentage(randomDouble)
            XCTAssertTrue(clamped >= 0.0 && clamped <= 1.0)
            XCTAssertTrue(pct >= 0 && pct <= 100)
        }
    }
}