//
//  GraphViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：Graph 组件快照测试，覆盖空状态占位视图与类型过滤器药丸。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class GraphViewSnapshots: XCTestCase {

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

    // MARK: - GraphEmptyStateView 快照测试

    /// 测试空状态占位视图 — 无知识图谱时的引导界面
    func testGraphEmptyStateView_Default() {
        var selectedTab: AppTab = .graph
        let view = GraphEmptyStateView(selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }))
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - GraphFilterPillsView 快照测试

    /// 测试过滤器药丸 — 默认未选中任何类型
    func testGraphFilterPillsView_NoFilter() {
        var filterType: PageType?
        let view = GraphFilterPillsView(filterType: Binding(get: { filterType }, set: { filterType = $0 }), tooltipManager: TooltipManager())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试过滤器药丸 — 选中 concept 类型
    func testGraphFilterPillsView_ConceptSelected() {
        var filterType: PageType? = .concept
        let view = GraphFilterPillsView(filterType: Binding(get: { filterType }, set: { filterType = $0 }), tooltipManager: TooltipManager())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// 测试过滤器药丸 — 选中 entity 类型
    func testGraphFilterPillsView_EntitySelected() {
        var filterType: PageType? = .entity
        let view = GraphFilterPillsView(filterType: Binding(get: { filterType }, set: { filterType = $0 }), tooltipManager: TooltipManager())
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }
}
