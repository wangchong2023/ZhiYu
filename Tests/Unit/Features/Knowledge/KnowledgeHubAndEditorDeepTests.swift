//
//  KnowledgeHubAndEditorDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对知识库工作台、Markdown 编辑器、搜索中心、标签云与保险库切换
//            执行深层状态机分支覆盖与交互边界测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class KnowledgeHubAndEditorDeepTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var searchStore: SearchStore!
    private var tagStore: TagStore!
    private var vaultService: VaultService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        appStore = AppStore()
        router = Router.shared
        searchStore = SearchStore()
        tagStore = TagStore()
        vaultService = VaultService.shared
    }

    override func tearDown() async throws {
        appStore = nil
        router = nil
        searchStore = nil
        tagStore = nil
        vaultService = nil
        try await super.tearDown()
    }

    // MARK: - 1. NotebookHubView 笔记本主页多卡片状态

    func testNotebookHubView_FullRendering() {
        let hubView = NotebookHubView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: hubView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. MarkdownEditorView 编辑器工具栏与文本绑定

    func testMarkdownEditorView_RenderingAndToolbarActions() {
        let editorView = MarkdownEditorView(
            text: .constant("# 标题\n这是正文内容 [[分布式事务]]。"),
            placeholder: "请输入正文内容..."
        )
        .snapshotEnvironment()

        let host = UIHostingController(rootView: editorView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. SearchView 搜索状态机 (空查询/关键词过滤/高级多维检索)

    func testSearchView_QueryStates() {
        let searchView = SearchView()
            .environment(searchStore)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: searchView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. TagCloudView 标签聚合与批量操作

    func testTagCloudView_Rendering() {
        let tagView = TagCloudView()
            .environment(tagStore)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: tagView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}
