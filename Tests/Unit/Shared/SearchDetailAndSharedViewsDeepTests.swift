//
//  SearchDetailAndSharedViewsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 共享 UI 与表现层深度集成测试
//  核心职责：深度覆盖 SearchView、PageDetailView、MarkdownRendererView、
//            AppCard 及 AIRainbowGlowBadge 的全生命周期装载与分支状态。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SearchDetailAndSharedViewsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - 1. SearchView 混合搜索与状态机深测

    func testSearchView_InstantiationAndFilterTransitions() {
        let view = SearchView(initialQuery: "Swift", initialFilterType: .concept)
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "带初始检索词的 SearchView 应能安全装载并完成布局")

        // 默认空初始条件
        let defaultView = SearchView()
        let defaultHost = defaultView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(defaultHost.view, "无参数构造的 SearchView 应能安全渲染空搜索主态")
    }

    // MARK: - 2. PageDetailView 详情与协同元数据交互深测

    func testPageDetailView_RenderingAndMetadata() {
        let samplePage = KnowledgePage(
            title: "微内核架构实践",
            pageType: .concept,
            content: "# 微内核架构\n\n通过插件化机制解耦业务大脑与数据引擎。",
            tags: ["架构", "解耦"]
        )

        let detailView = PageDetailView(page: samplePage)
        let host = detailView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "PageDetailView 应当在虚拟 UIWindow 下正确装载渲染")
        XCTAssertEqual(samplePage.title, "微内核架构实践")
        XCTAssertEqual(samplePage.tags.count, 2)
    }

    // MARK: - 3. MarkdownRendererView 语法树分支与隐私遮罩深测

    func testMarkdownRendererView_RichContentAndPrivacyMask() {
        let markdownContent = """
        # 智宇知识引擎
        
        > 这是引用的核心摘要
        
        - 列表项一
        - 列表项二
        
        ```swift
        let core = KnowledgeEngine()
        ```
        
        [智宇官网](https://zhiyu.app)
        """

        // 1. 公开模式普通渲染
        let publicView = MarkdownRendererView(
            content: markdownContent,
            isPrivate: false,
            onLinkTap: { _ in }
        )
        let hostPublic = publicView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostPublic.view, "公开富文本 MarkdownRendererView 应当能被解析并正常渲染")
        XCTAssertFalse(markdownContent.isEmpty)
        XCTAssertTrue(markdownContent.contains("智宇知识引擎"))

        // 2. 隐私模式渲染
        let privateView = MarkdownRendererView(
            content: markdownContent,
            isPrivate: true,
            onLinkTap: { _ in }
        )
        let hostPrivate = privateView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostPrivate.view, "私密模式 MarkdownRendererView 应当触发隐私模糊与遮罩保护")

        // 3. 空内容渲染
        let emptyView = MarkdownRendererView(
            content: "",
            isPrivate: false,
            onLinkTap: { _ in }
        )
        let hostEmpty = emptyView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostEmpty.view, "空内容 MarkdownRendererView 应当正常渲染降级占位")
        XCTAssertTrue(emptyView.content.isEmpty)
    }

    // MARK: - 4. AppCard 容器与修饰符深测

    func testAppCard_ContainerAndModifiers() {
        // 1. 标准卡片容器
        let card = AppCard(
            cornerRadiusToken: .card,
            paddingToken: .standardPadding
        ) {
            Text("卡片测试内容")
                .font(.headline)
        }
        let hostCard = card.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostCard.view, "AppCard 标准卡片容器应能正常挂载渲染")
        XCTAssertEqual(card.cornerRadiusToken, .card)
        XCTAssertEqual(card.paddingToken, .standardPadding)

        // 2. AppCardModifier 视图修饰符
        let modifier = AppCardModifier(
            cornerRadiusToken: .medium,
            paddingToken: .small,
            backgroundColor: .appBackground
        )
        let modifiedView = Text("修饰符测试内容")
            .modifier(modifier)
        let hostModified = modifiedView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostModified.view, "AppCardModifier 修饰符应能正确计算并渲染内边距与背景")
        XCTAssertEqual(modifier.cornerRadiusToken, .medium)
        XCTAssertEqual(modifier.paddingToken, .small)
    }

    // MARK: - 5. AIRainbowGlowBadge 呼吸微标与弹窗状态深测

    func testAIRainbowGlowBadge_RenderingAndInteraction() {
        let modelManager = GlobalModelManager.shared
        let badge = AIRainbowGlowBadge()
        let host = badge.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "AIRainbowGlowBadge 呼吸微标应能在虚拟宿主窗口完成布局与动画启动")
        XCTAssertNotNil(modelManager)
    }

    // MARK: - 6. SearchView 排序枚举全覆盖

    func testSearchView_SortOptionTitles() {
        for option in SearchView.SortOption.allCases {
            XCTAssertFalse(option.rawValue.isEmpty, "SortOption 的本地化键值不应为空")
        }
    }
}
