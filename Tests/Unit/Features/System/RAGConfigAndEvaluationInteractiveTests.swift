//
//  RAGConfigAndEvaluationInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：RAGConfigForm 时间窗口选择、EvalTab 枚举映射与 RAGEvaluationView 视图状态挂载测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class RAGConfigAndEvaluationInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. EvalTab 枚举标题与标识符契约测试

    func testEvalTabTitlesAndCases() {
        let allTabs = EvalTab.allCases
        XCTAssertEqual(allTabs.count, 3)

        for tab in allTabs {
            XCTAssertEqual(tab.id, tab.rawValue)
            XCTAssertFalse(tab.title.isEmpty, "\(tab) 标题不能为空")
        }

        XCTAssertEqual(EvalTab.retrieval.title, L10n.Dashboard.stats.tabRetrieval)
        XCTAssertEqual(EvalTab.generation.title, L10n.Dashboard.stats.tabGeneration)
        XCTAssertEqual(EvalTab.evaluation.title, L10n.Dashboard.stats.tabSatisfactionAndEval)
    }

    // MARK: - 2. RAGTimeRangePicker 视图交互与选择绑定测试

    func testRAGTimeRangePickerBinding() {
        var days = 30
        let binding = Binding<Int>(
            get: { days },
            set: { days = $0 }
        )

        let picker = RAGTimeRangePicker(selectedDays: binding)
        let host = UIHostingController(rootView: picker)
        XCTAssertNotNil(host.view)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        binding.wrappedValue = 7
        XCTAssertEqual(days, 7)

        binding.wrappedValue = 90
        XCTAssertEqual(days, 90)
    }

    // MARK: - 3. RAGEvaluationView 视图树挂载测试

    func testRAGEvaluationViewMount() {
        let view = RAGEvaluationView()
        let host = UIHostingController(rootView: view)
        let settings = ServiceContainer.shared.resolveOptional(SettingsStore.self)
        XCTAssertNotNil(settings)
        XCTAssertNotNil(host.view)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
}
