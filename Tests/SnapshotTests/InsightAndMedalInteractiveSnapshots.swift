//
//  InsightAndMedalInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：知识库洞察仪表盘 (KnowledgeDashboardView) 与治理中心 (LintView) 的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class InsightAndMedalInteractiveSnapshots: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 知识库仪表盘核心指标与图表快照

    func testKnowledgeDashboardView_MainMetrics_RendersCharts() {
        let view = NavigationStack {
            KnowledgeDashboardView()
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 知识库健康治理中心 (LintView) 快照

    func testLintView_HealthCheckTab_RendersScoreCard() {
        let view = NavigationStack {
            LintView(selection: .constant(.tool(.lint)))
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
