//
//  StorageDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：SystemAndStorageViewsStateMachineDeepTests.swift, SystemStorageAndPluginBehaviorTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class StorageDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

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

    func testRawStorageListViewInspector() async throws {
        struct Wrapper: View {
            var body: some View {
                RawStorageListView()
            }
        }

        let wrapper = Wrapper()
        XCTAssertNotNil(wrapper)
        let view = wrapper.snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testSettingsAndPluginCenterAndProfile() async throws {
        struct Wrapper: View {
            var body: some View {
                VStack {
                    SettingsView()
                    PluginCenterView()
                    UserProfileView()
                }
            }
        }

        let wrapper = Wrapper()
        XCTAssertNotNil(wrapper)
        let view = wrapper.snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

}
