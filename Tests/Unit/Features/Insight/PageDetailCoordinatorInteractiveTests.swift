//
//  PageDetailCoordinatorInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：PageDetailCoordinator 核心业务状态机、回链提取、AI 任务调度与防双链嵌套测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PageDetailCoordinatorInteractiveTests: XCTestCase {

    private var appStore: AppStore!
    private var aiWorkflowStore: AIWorkflowStore!
    private var pageManager: KnowledgePageManager!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        aiWorkflowStore = ServiceContainer.shared.resolveOptional(AIWorkflowStore.self) ?? AIWorkflowStore()
        pageManager = KnowledgePageManager()
    }

    override func tearDown() async throws {
        appStore = nil
        aiWorkflowStore = nil
        pageManager = nil
        try await super.tearDown()
    }

    // MARK: - 1. 页面置顶状态切换与持久化测试

    func testTogglePinInvertsStateAndPersistsToStore() async {
        let initialPage = KnowledgePage(title: "置顶测试页面", content: "核心知识点", isPinned: false)
        await appStore.savePage(initialPage)

        let coordinator = PageDetailCoordinator(page: initialPage)
        XCTAssertFalse(coordinator.page.isPinned, "初始状态不应置顶")

        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned, "调用 togglePin 后状态应变为置顶")

        let persistedPage = appStore.pages.first(where: { $0.id == initialPage.id })
        XCTAssertEqual(persistedPage?.isPinned, true, "持久化存储中的页面应同步更新为置顶")

        // 再次切换还原
        await coordinator.togglePin()
        XCTAssertFalse(coordinator.page.isPinned, "再次调用 togglePin 后状态应恢复为非置顶")
    }

    // MARK: - 2. 页面删除操作流转测试

    func testDeletePageRemovesPageFromStore() async {
        let targetPage = KnowledgePage(title: "待删除页面", content: "临时内容")
        await appStore.savePage(targetPage)
        XCTAssertTrue(appStore.pages.contains(where: { $0.id == targetPage.id }))

        let coordinator = PageDetailCoordinator(page: targetPage)
        await coordinator.deletePage()

        XCTAssertFalse(appStore.pages.contains(where: { $0.id == targetPage.id }), "调用 deletePage 后页面应从 Store 中彻底移除")
    }

    // MARK: - 3. 反向链接 (Backlinks) 提取精度与过滤测试

    func testBacklinksExtractionMatchesReferencingPages() async {
        let targetPage = KnowledgePage(title: "目标核心知识", content: "被引用正文")
        let referencingPage1 = KnowledgePage(title: "引用页 A", content: "请参见 [[目标核心知识]] 的详细推导。")
        let referencingPage2 = KnowledgePage(title: "引用页 B", content: "参考 [[目标核心知识|核心文档]] 中的定义。")
        let unrelatedPage = KnowledgePage(title: "无关页 C", content: "这里没有任何双向链接引用。")

        await appStore.savePage(targetPage)
        await appStore.savePage(referencingPage1)
        await appStore.savePage(referencingPage2)
        await appStore.savePage(unrelatedPage)

        let coordinator = PageDetailCoordinator(page: targetPage)
        let backlinks = coordinator.backlinks

        XCTAssertEqual(backlinks.count, 2, "应准确匹配 2 个引用了目标页面的反链页面")
        let titles = Set(backlinks.map { $0.title })
        XCTAssertTrue(titles.contains("引用页 A"))
        XCTAssertTrue(titles.contains("引用页 B"))
        XCTAssertFalse(titles.contains("无关页 C"))
    }

    // MARK: - 4. 潜在链接应用 (防双链嵌套变异测试)

    func testApplyPotentialLinkPreservesExistingWikiLinksWithoutDoubleBrackets() async throws {
        let pageID = UUID()
        let initialContent = "本文重点探讨 [[分布式系统]] 与 微服务架构，分布式系统非常复杂。"
        let sourcePage = KnowledgePage(id: pageID, title: "系统架构概览", content: initialContent)
        await appStore.savePage(sourcePage)

        let suggestion = PotentialLinkSuggestion(
            id: UUID(),
            sourcePageID: pageID,
            sourceTitle: "系统架构概览",
            targetTitle: "分布式系统"
        )

        await appStore.applyPotentialLink(suggestion)

        let updatedPage = appStore.pages.first(where: { $0.id == pageID })
        let content = updatedPage?.content ?? ""

        // 核心防腐变异断言：绝对不能出现 [[[[分布式系统]]]] 四重中括号
        XCTAssertFalse(content.contains("[[[[分布式系统]]]]"), "应用潜在链接时绝不能对已有双链进行重复嵌套包裹")
        XCTAssertTrue(content.contains("[[分布式系统]]"), "原有的双链及新补全的双链应保持合法的双中括号格式")

        // 验证非链接的文字成功转换为链接
        XCTAssertTrue(content.contains("[[分布式系统]]非常复杂"))
    }

    // MARK: - 5. AI 任务编排触发测试

    func testAIWorkflowOperationsTriggerCorrectly() async {
        let page = KnowledgePage(title: "AI 测试页", content: "包含大量用于提取的任务正文")
        let coordinator = PageDetailCoordinator(page: page)

        coordinator.generateSummary()
        coordinator.extractActions()
        coordinator.expandContent()
        coordinator.performSynthesis(type: .mindmap)
        coordinator.findRelatedLinks()

        XCTAssertTrue(coordinator.hasScannedForLinks, "触发 findRelatedLinks 后 hasScannedForLinks 状态应为 true")
    }
}
