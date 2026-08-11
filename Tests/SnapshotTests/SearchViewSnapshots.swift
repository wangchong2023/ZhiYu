//
//  SearchViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：Search 组件快照测试，覆盖 CommandPaletteView 命令面板。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class SearchViewSnapshots: XCTestCase {

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

    // MARK: - CommandPaletteView 快照测试

    /// 测试命令面板 — 默认空搜索状态
    func testCommandPaletteView_Default() {
        let view = CommandPaletteView()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
