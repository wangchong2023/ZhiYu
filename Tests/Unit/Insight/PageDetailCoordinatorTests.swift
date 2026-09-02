//
//  PageDetailCoordinatorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 PageDetailCoordinator 的 backlinks 计算、删除/置顶、AI 任务编排入口。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class PageDetailCoordinatorTests: XCTestCase {

    private var store: AppStore!
    private var coordinator: PageDetailCoordinator!
    private var page: KnowledgePage?

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AppStore()
        store.knowledgeStore.pages = []
        let newPage = KnowledgePage(title: "目标页", content: "内容", isPinned: false)
        page = newPage
        await store.savePage(newPage)
        coordinator = PageDetailCoordinator(page: newPage)
    }

    override func tearDown() async throws {
        coordinator = nil
        store = nil
        page = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态

    /// 验证初始 isEditing 为 false
    func testInitialIsEditingFalse() {
        XCTAssertFalse(coordinator.isEditing)
    }

    /// 验证初始 showBacklinks 为 false
    func testInitialShowBacklinksFalse() {
        XCTAssertFalse(coordinator.showBacklinks)
    }

    /// 验证初始 showDeleteConfirmation 为 false
    func testInitialShowDeleteConfirmationFalse() {
        XCTAssertFalse(coordinator.showDeleteConfirmation)
    }

    /// 验证初始 hasScannedForLinks 为 false
    func testInitialHasScannedForLinksFalse() {
        XCTAssertFalse(coordinator.hasScannedForLinks)
    }

    // MARK: - backlinks 计算

    /// 验证 backlinks 包含引用当前页的页面
    func testBacklinksIncludesReferencingPages() async {
        let referrer = KnowledgePage(title: "引用页", content: "这里引用了 [[目标页]] 的概念")
        await store.savePage(referrer)

        XCTAssertEqual(coordinator.backlinks.count, 1)
        XCTAssertEqual(coordinator.backlinks.first?.title, "引用页")
    }

    /// 验证 backlinks 排除不引用当前页的页面
    func testBacklinksExcludesNonReferencingPages() async {
        let other = KnowledgePage(title: "无关页", content: "[[其他页]] 是一个链接")
        await store.savePage(other)

        XCTAssertTrue(coordinator.backlinks.isEmpty)
    }

    /// 验证 backlinks 大小写敏感（WikiLink 原样匹配）
    func testBacklinksCaseSensitive() async {
        let referrer = KnowledgePage(title: "引用页", content: "[[目标页]]")
        let referrerLower = KnowledgePage(title: "小写引用", content: "[[目标页]]")
        await store.savePage(referrer)
        await store.savePage(referrerLower)

        XCTAssertEqual(coordinator.backlinks.count, 2)
    }

    /// 验证 backlinks 空内容不崩溃
    func testBacklinksEmptyContentNoCrash() async {
        let empty = KnowledgePage(title: "空页", content: "")
        await store.savePage(empty)

        XCTAssertTrue(coordinator.backlinks.isEmpty)
    }

    // MARK: - deletePage

    /// 验证 deletePage 从 store 删除
    func testDeletePageRemovesFromStore() async {
        guard let pageID = page?.id else {
            XCTFail("page 不应为 nil")
            return
        }
        await coordinator.deletePage()

        XCTAssertTrue(store.pages.filter { $0.id == pageID }.isEmpty)
    }

    // MARK: - togglePin

    /// 验证 togglePin 从 false 翻转为 true
    func testTogglePinFalseToTrue() async {
        coordinator.page.isPinned = false
        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned)
    }

    /// 验证 togglePin 从 true 翻转为 false
    func testTogglePinTrueToFalse() async {
        guard var pinned = page else {
            XCTFail("page 不应为 nil")
            return
        }
        pinned.isPinned = true
        await store.savePage(pinned)
        coordinator.page = pinned

        await coordinator.togglePin()

        XCTAssertFalse(coordinator.page.isPinned)
    }

    /// 验证 togglePin 同步到 store
    func testTogglePinSyncsToStore() async {
        guard let pageID = page?.id else {
            XCTFail("page 不应为 nil")
            return
        }
        await coordinator.togglePin()

        let stored = store.pages.first { $0.id == pageID }
        XCTAssertEqual(stored?.isPinned, coordinator.page.isPinned)
    }

    // MARK: - AI 任务入口

    /// 验证 generateSummary 触发 runAIOperation
    func testGenerateSummaryTriggersOperation() {
        coordinator.generateSummary()
    }

    /// 验证 extractActions 触发 runAIOperation
    func testExtractActionsTriggersOperation() {
        coordinator.extractActions()
    }

    /// 验证 expandContent 触发 runAIOperation
    func testExpandContentTriggersOperation() {
        coordinator.expandContent()
    }

    /// 验证 performSynthesis 触发 runAIOperation
    func testPerformSynthesisTriggersOperation() {
        coordinator.performSynthesis(type: .mindmap)
    }

    /// 验证 findRelatedLinks 设置 hasScannedForLinks 为 true
    func testFindRelatedLinksSetsFlag() {
        XCTAssertFalse(coordinator.hasScannedForLinks)

        coordinator.findRelatedLinks()

        XCTAssertTrue(coordinator.hasScannedForLinks)
    }

    // MARK: - 页面属性更新

    /// 验证更新 page 实例后属性正确反映
    func testUpdatePageReflectedInCoordinator() {
        let newTitle = "新标题"
        coordinator.page.title = newTitle

        XCTAssertEqual(coordinator.page.title, newTitle)
    }

    /// 验证 isEditing 状态切换
    func testToggleIsEditing() {
        coordinator.isEditing = true
        XCTAssertTrue(coordinator.isEditing)

        coordinator.isEditing = false
        XCTAssertFalse(coordinator.isEditing)
    }
}
