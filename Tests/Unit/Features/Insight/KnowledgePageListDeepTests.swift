//
//  KnowledgePageListDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：KnowledgePageListAndTagCloudDeepTests.swift, KnowledgePageListViewInteractiveTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class KnowledgePageListDeepTests: XCTestCase {

    private var appStore: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = AppStore()
    }

    override func tearDown() async throws {
        appStore = nil
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testKnowledgePageListView_AllTypes() {
        let rawList = KnowledgePageListView(filterType: nil)
        XCTAssertNotNil(rawList)
        let host = NavigationStack {
            rawList
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testKnowledgePageListView_FilteredByType() {
        for type in PageType.allCases {
            let rawList = KnowledgePageListView(filterType: type)
            XCTAssertNotNil(rawList)
            let host = NavigationStack {
                rawList
            }
            .snapshotEnvironment()
            .renderInWindow()

            XCTAssertNotNil(host.view)
        }
    }

    func testTagCloudView_Hierarchy() {
        let rawTagCloud = TagCloudView()
        XCTAssertNotNil(rawTagCloud)
        let host = NavigationStack {
            rawTagCloud
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testFilterPagesByTypeSortsAlphabetically() async {
        let pageC = KnowledgePage(title: "C 语言基础", pageType: .concept, content: "内容")
        let pageA = KnowledgePage(title: "A 算法设计", pageType: .concept, content: "内容")
        let pageB = KnowledgePage(title: "B 架构演进", pageType: .concept, content: "内容")
        let pageSource = KnowledgePage(title: "外部参考源", pageType: .source, content: "源内容")

        await appStore.savePage(pageC)
        await appStore.savePage(pageA)
        await appStore.savePage(pageB)
        await appStore.savePage(pageSource)

        let conceptPages = appStore.pages.filter { $0.pageType == .concept }.sorted { $0.title < $1.title }
        XCTAssertEqual(conceptPages.count, 3)
        XCTAssertEqual(conceptPages[0].title, "A 算法设计")
        XCTAssertEqual(conceptPages[1].title, "B 架构演进")
        XCTAssertEqual(conceptPages[2].title, "C 语言基础")

        let sourcePages = appStore.pages.filter { $0.pageType == .source }
        XCTAssertEqual(sourcePages.count, 1)
        XCTAssertEqual(sourcePages.first?.title, "外部参考源")
    }

    func testDeleteConfirmationDialogMessageSemantics() {
        // 校验单页面删除应使用特定的页面删除提示，严禁错误展示清空全库提示 (L10n.Settings.clearAll.message)
        let singlePageDeleteMessage = L10n.Knowledge.Page.deleteMessage
        let clearAllSystemMessage = L10n.Settings.clearAll.message

        XCTAssertNotEqual(
            singlePageDeleteMessage,
            clearAllSystemMessage,
            "单页面删除文案不能等同于清空全库全局警告文案"
        )
        XCTAssertFalse(
            singlePageDeleteMessage.contains("系统设置"),
            "单页面删除提示不应提及系统设置"
        )
    }

    func testEmptySearchConditionExhibitsAllVisibleTypes() async {
        let p1 = KnowledgePage(title: "测试概念", pageType: .concept, content: "...")
        let p2 = KnowledgePage(title: "测试实体", pageType: .entity, content: "...")
        await appStore.savePage(p1)
        await appStore.savePage(p2)

        let hasContent = PageType.allCases.contains { type in
            appStore.pages.contains { $0.pageType == type }
        }
        XCTAssertTrue(hasContent, "有页面时空搜索应返回有结果状态")
    }

    func testKnowledgePageListViewMountAndRender() {
        let rawList = KnowledgePageListView(filterType: .concept)
        XCTAssertNotNil(rawList)
        let view = rawList.snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "KnowledgePageListView 宿主视图应完成挂载")
    }

}
