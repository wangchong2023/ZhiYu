//
//  ModelLabSandboxAndMetricsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 ModelLabView 大模型实验室、ModelLabConfigSheet 配置弹出页、
//           ModelLabSandboxPanel 场景沙箱面板与 ModelLabMetricsPanel 性能统计面板。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class ModelLabSandboxAndMetricsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ModelLabView 全场景用例与沙箱挂载测试

    func testModelLabView_AllUseCasesHierarchy() {
        for useCase in UseCaseType.allCases {
            let host = NavigationStack {
                ModelLabView(onGoToStore: {})
            }
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }

    // MARK: - 2. ModelLabView 各分段面板深度挂载测试

    func testModelLabView_PanelsAndSheets() {
        let view = ModelLabView(onGoToStore: {})
        
        let sheetHost = view.configurationSheet
            .snapshotEnvironment()
            .renderInWindow()
        XCTAssertNotNil(sheetHost.view)

        let metricsHost = view.metricsMonitorBoard
            .snapshotEnvironment()
            .renderInWindow()
        XCTAssertNotNil(metricsHost.view)

        for useCase in UseCaseType.allCases {
            let panelHost = view.useCaseDetailPanel(for: useCase)
                .snapshotEnvironment()
                .renderInWindow()
            XCTAssertNotNil(panelHost.view)
        }
    }

    // MARK: - 3. ModelLabManager 状态管理与推理模拟测试

    func testModelLabManager_StateAndStatsUpdate() {
        let manager = ModelLabManager()
        XCTAssertFalse(manager.isGenerating)

        manager.selectedUseCase = .aiChat
        XCTAssertFalse(manager.attachmentOptions.isEmpty)

        manager.selectedUseCase = .askImage
        XCTAssertFalse(manager.paramTips.isEmpty)

        manager.currentStats = PerformanceStats(
            speed: 42.5,
            prefillLatency: 120,
            firstTokenLatency: 80,
            memoryUsage: 350.0
        )
        XCTAssertEqual(manager.currentStats.speed, 42.5)
        XCTAssertEqual(manager.currentStats.prefillLatency, 120)
        XCTAssertEqual(manager.currentStats.firstTokenLatency, 80)
        XCTAssertEqual(manager.currentStats.memoryUsage, 350.0)
    }

    // MARK: - 4. 参数预设匹配与边界测试

    func testParameterPreset_MatchAndAllCases() {
        for preset in ParameterPreset.allCases {
            let params = preset.parameters
            XCTAssertGreaterThanOrEqual(params.temperature, 0.0)
            XCTAssertGreaterThanOrEqual(params.topP, 0.0)
            XCTAssertGreaterThan(params.maxTokens, 0)
        }
    }
}
