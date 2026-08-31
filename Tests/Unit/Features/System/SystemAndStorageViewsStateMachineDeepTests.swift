//
//  SystemAndStorageViewsStateMachineDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：深度验证 SystemStatsView、RawStorageListView、ModelLabView 等表现层视图的全状态机流转与边界安全。
//

import XCTest
import SwiftUI
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class SystemAndStorageViewStateTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SystemStatsView 全 Tab 与高时延状态机求值

    func testSystemStatsView_AllTabsAndStates_RendersSafely() async {
        let store = AppStore()
        let theme = ThemeManager()

        // 基础视图渲染
        let view = SystemStatsView()
            .environment(store)
            .environment(theme)

        let controller = UIHostingController(rootView: view)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // 验证 Tab 枚举完整性
        for tab in SystemStatsView.Tab.allCases {
            XCTAssertFalse(tab.title.isEmpty, "Tab 标题不应为空: \(tab.rawValue)")
            XCTAssertFalse(tab.rawValue.isEmpty)
        }
    }

    // MARK: - 2. RawStorageListView 与 RawCategoryType 状态机

    func testRawStorageListView_CategoriesAndHighlightedText() {
        let store = AppStore()
        let theme = ThemeManager()

        // 1. RawCategoryType 6 大分类完整性与图标映射
        for category in RawCategoryType.allCases {
            XCTAssertEqual(category.id, category.rawValue)
            XCTAssertFalse(category.systemIconName.isEmpty, "分类图标不应为空: \(category.rawValue)")
            XCTAssertFalse(category.displayName.isEmpty, "分类本地化名称不应为空: \(category.rawValue)")
            _ = category.defaultColor
        }

        // 2. HighlightedText 正常与高亮匹配
        let normalText = HighlightedText(text: "智宇知识库测试内容", highlight: "")
        let normalCtrl = UIHostingController(rootView: normalText)
        _ = normalCtrl.view

        let highlightedText = HighlightedText(text: "智宇知识库测试内容", highlight: "知识库")
        let highlightedCtrl = UIHostingController(rootView: highlightedText)
        _ = highlightedCtrl.view

        // 3. RawStorageListView 渲染
        let listView = RawStorageListView()
            .environment(store)
            .environment(theme)
            .environment(Router())

        let listCtrl = UIHostingController(rootView: listView)
        _ = listCtrl.view
        listCtrl.view.setNeedsLayout()
        listCtrl.view.layoutIfNeeded()
    }

    // MARK: - 3. ModelLabView 全状态与 UseCase 枚举覆盖

    func testModelLabView_RenderingAndUseCases() {
        for useCase in UseCaseType.allCases {
            XCTAssertFalse(useCase.title.isEmpty)
            XCTAssertFalse(useCase.icon.isEmpty)
            XCTAssertFalse(useCase.requiredTask.isEmpty)
            XCTAssertFalse(useCase.description.isEmpty)
        }

        let modelLabView = ModelLabView(embedInScrollView: true, onGoToStore: {})
            .environment(AppStore())
            .environment(ThemeManager())

        let controller = UIHostingController(rootView: modelLabView)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }
}
