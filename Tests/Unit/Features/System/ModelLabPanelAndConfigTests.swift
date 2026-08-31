//
//  ModelLabPanelAndConfigTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 ModelLabManager、UseCaseType 全 7 大场景匹配、PerformanceStats 性能指标与推理追踪状态机。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ModelLabPanelAndConfigTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. UseCaseType 7 大场景枚举分支全覆盖

    func testUseCaseType_AllCasesAndProperties() {
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.id.isEmpty)
            XCTAssertFalse(useCase.title.isEmpty)
            XCTAssertFalse(useCase.description.isEmpty)
            XCTAssertFalse(useCase.icon.isEmpty)
            XCTAssertFalse(useCase.requiredTask.isEmpty)
        }
    }

    // MARK: - 2. ModelLabManager 状态流转与重置分支

    func testModelLabManager_InitialStateAndUseCaseSelection() {
        let manager = ModelLabManager()
        XCTAssertNil(manager.selectedUseCase)
        XCTAssertFalse(manager.isGenerating)

        manager.selectedUseCase = .promptLab
        XCTAssertEqual(manager.selectedUseCase, .promptLab)

        manager.selectedUseCase = .askImage
        XCTAssertEqual(manager.selectedUseCase, .askImage)
        XCTAssertEqual(manager.selectedUseCase?.requiredTask, "multimodal")
    }

    // MARK: - 3. 性能统计结构 (PerformanceStats) 相等性与默认值

    func testPerformanceStats_Equatability() {
        let stats1 = PerformanceStats(speed: 42.5, prefillLatency: 120, firstTokenLatency: 80, memoryUsage: 1024.0)
        let stats2 = PerformanceStats(speed: 42.5, prefillLatency: 120, firstTokenLatency: 80, memoryUsage: 1024.0)
        let stats3 = PerformanceStats(speed: 30.0, prefillLatency: 200, firstTokenLatency: 150, memoryUsage: 512.0)

        XCTAssertEqual(stats1, stats2)
        XCTAssertNotEqual(stats1, stats3)
    }

    // MARK: - 4. 追踪步进结构 (TraceStep) 标识符与初始化

    func testTraceStep_Initialization() {
        let step = TraceStep(
            title: "Prompt 构建",
            desc: "已完成系统级 Prompt 注入",
            icon: "doc.text.fill",
            colorName: "blue"
        )
        XCTAssertEqual(step.id, "Prompt 构建")
        XCTAssertEqual(step.title, "Prompt 构建")
        XCTAssertEqual(step.colorName, "blue")
    }
}
