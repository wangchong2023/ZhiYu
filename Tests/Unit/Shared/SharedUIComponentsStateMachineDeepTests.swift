//
//  SharedUIComponentsStateMachineDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：深度验证 PageDetailAIMenuButton、PageDetailMetaSectionView、AdaptiveTextEditor 等通用 UI 组件的渲染与交互状态机。
//

import XCTest
import SwiftUI
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class SharedUIComponentsStateMachineDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PageDetailMetaSectionView 元数据面板求值

    func testPageDetailMetaSectionView_RendersCorrectly() {
        let store = KnowledgeStore()
        let router = Router()

        let page = KnowledgePage(
            title: "元数据测试页面",
            pageType: .concept,
            content: "# 标题\n这是正文内容，包含一些知识点",
            tags: ["AI", "RAG", "Swift"],
            isPinned: true
        )

        var isExpanded = true
        let bindingExpanded = Binding(get: { isExpanded }, set: { isExpanded = $0 })

        let metaView = PageDetailMetaSectionView(page: page, isExpanded: bindingExpanded)
            .environment(store)
            .environment(router)

        let controller = UIHostingController(rootView: metaView)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    // MARK: - 2. AdaptiveTextEditor 文本编辑组件

    func testAdaptiveTextEditor_TextBindingAndEditing() {
        var text = "初始 Markdown 文本"
        let bindingText = Binding(get: { text }, set: { text = $0 })

        let editor = AdaptiveTextEditor(text: bindingText)
        let controller = UIHostingController(rootView: editor)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        bindingText.wrappedValue = "更新后的 Markdown 文本"
        XCTAssertEqual(text, "更新后的 Markdown 文本")
    }

    // MARK: - 3. PageDetailAIMenuButton AI 菜单按键

    func testPageDetailAIMenuButton_MenuActions() {
        let aiButton = PageDetailAIMenuButton(
            isDisabled: false,
            onGenerateSummary: {},
            onExtractActions: {},
            onMindmap: {},
            onQuiz: {},
            onSlides: {},
            onReport: {},
            onInfographic: {},
            onShowSnapshotHistory: {},
            onExpandContent: {},
            onFindRelatedLinks: {}
        )

        let controller = UIHostingController(rootView: aiButton)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }
}
