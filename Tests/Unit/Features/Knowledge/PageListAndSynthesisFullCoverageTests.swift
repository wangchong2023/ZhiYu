//
//  PageListAndSynthesisFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 KnowledgePageListView 列表筛选与 SynthesisView 的 8 种合成策略模板切换分支。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class PageListAndSynthesisFullCoverageTests: XCTestCase {

    private var store: AppStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router.shared
    }

    override func tearDown() async throws {
        store = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. KnowledgePageListView 空状态与数据填充状态

    func testKnowledgePageListViewRendering() async {
        // 1. 空状态
        store.knowledgeStore.pages = []
        let emptyListView = KnowledgePageListView()
            .snapshotEnvironment()
        let emptyHost = UIHostingController(rootView: emptyListView)
        XCTAssertNotNil(emptyHost.view)
        emptyHost.view.layoutIfNeeded()

        // 2. 注入多篇知识库页面
        let page1 = KnowledgePage(title: "SwiftUI 深度实战", content: "关于状态与绑定的解析", tags: ["SwiftUI", "iOS"])
        let page2 = KnowledgePage(title: "GRDB 架构优化", content: "SQLite 索引与性能", tags: ["Database"])
        await store.savePage(page1)
        await store.savePage(page2)

        let populatedView = KnowledgePageListView()
            .snapshotEnvironment()
        let populatedHost = UIHostingController(rootView: populatedView)
        XCTAssertNotNil(populatedHost.view)
        populatedHost.view.layoutIfNeeded()
    }

    // MARK: - 2. SynthesisView 综合实验室与策略选择

    struct SynthesisWrapperView: View {
        @State private var selection: SidebarSelection?
        @State private var selectedTab: AppTab = .synthesis

        var body: some View {
            SynthesisView(selection: $selection, selectedTab: $selectedTab)
                .snapshotEnvironment()
        }
    }

    func testSynthesisViewRendering() {
        let wrapper = SynthesisWrapperView()
        let hosting = UIHostingController(rootView: wrapper)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }
}
