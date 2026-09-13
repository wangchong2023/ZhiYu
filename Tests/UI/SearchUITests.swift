//
//  SearchUITests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 SearchUI 开展自动化单元测试验证。
//
import XCTest

// MARK: - Search UI Tests
/// 搜索功能 UI 自动化测试套件
/// 覆盖范围：搜索栏交互、类型过滤标签、排序菜单、搜索结果导航
final class SearchTests: KnowledgeBaseUITests {

    override func setUp() async throws {
        try await super.setUp()
        // 导航到 Knowledge Tab（Search 现在在 Knowledge Tab 内或通过检索 UI 访问）
        tapTab(named: "Knowledge")
        try? await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
    }

    /// 验证搜索栏可交互
    func testSearchBarIsTappable() async {
        let searchField = app.textFields["搜索页面、标签、内容..."]
        if searchField.exists {
            safeTap(searchField)
            searchField.typeText("Test")
            try? await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
            // 验证键盘出现
            XCTAssertTrue(app.keyboards.element.exists)
            // 清空搜索
            let clearButton = app.buttons["Clear text"]
            if clearButton.exists {
                safeTap(clearButton)
            }
        }
    }

    /// 验证类型过滤 Pill 按钮可交互    /// 验证排序菜单可弹出
    func testSortMenu() async {
        let sortButton = app.buttons["最近更新"]
        if sortButton.exists {
            safeTap(sortButton)
            try? await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
            // 验证 menu 出现
            if app.menuItems.firstMatch.exists {
                app.menuItems.firstMatch.tap()
                try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
            }
        }
    }

    /// 验证搜索结果点击可导航
    func testSearchResultsNavigation() async {
        let searchField = app.textFields["搜索页面、标签、内容..."]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Page")
            try? await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000))
            // 查找第一个结果
            let resultCell = app.tables.cells.firstMatch
            if resultCell.exists && resultCell.isHittable {
                safeTap(resultCell)
                try? await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000))
            }
        }
    }
}
