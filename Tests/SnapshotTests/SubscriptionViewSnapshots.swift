//
//  SubscriptionViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：订阅套餐组件快照测试，覆盖月付/年付周期选择与套餐对比卡片。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class SubscriptionViewSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - SubscriptionPlanCard 快照测试

    /// 测试套餐卡片 — 默认年付选中状态
    func testSubscriptionPlanCard_YearlySelected() {
        var cycle: BillingCycle = .yearly
        let view = SubscriptionPlanCard(selectedCycle: cycle, onCycleChange: { cycle = $0 })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 400)))
    }

    /// 测试套餐卡片 — 月付选中状态
    func testSubscriptionPlanCard_MonthlySelected() {
        var cycle: BillingCycle = .monthly
        let view = SubscriptionPlanCard(selectedCycle: cycle, onCycleChange: { cycle = $0 })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 400)))
    }
}
