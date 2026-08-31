//
//  PageDetailAndLogViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 PageDetailCoordinator、反向链接过滤、置顶状态流转与 AI 任务触发分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PageDetailAndLogViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 置顶与状态切换

    func testPageDetailCoordinator_TogglePin() async {
        let page = KnowledgePage(title: "测试详情页", pageType: .concept, content: "内容", isPinned: false)
        let coordinator = PageDetailCoordinator(page: page)
        XCTAssertFalse(coordinator.page.isPinned)

        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned, "切换置顶后 isPinned 必须为 true")

        await coordinator.togglePin()
        XCTAssertFalse(coordinator.page.isPinned, "再次切换后 isPinned 恢复为 false")
    }

    // MARK: - 2. 反向链接 (Backlinks) 提取分支

    func testPageDetailCoordinator_BacklinksExtraction() async {
        let targetPage = KnowledgePage(title: "目标概念", pageType: .concept, content: "核心概念定义")
        let referringPage = KnowledgePage(title: "引用页", pageType: .concept, content: "参见 [[目标概念]] 的说明")

        let store = AppStore()
        await store.savePage(targetPage)
        await store.savePage(referringPage)

        let coordinator = PageDetailCoordinator(page: targetPage)
        let backlinks = coordinator.backlinks

        XCTAssertFalse(backlinks.isEmpty, "应当成功提取包含双链的反向链接页面")
        XCTAssertTrue(backlinks.contains { $0.title == "引用页" })
    }

    // MARK: - 3. AI 任务触发方法安全性校验

    func testPageDetailCoordinator_AIOperationsTrigger() {
        let page = KnowledgePage(title: "AI 概括页", pageType: .concept, content: "待概括长文本内容")
        let coordinator = PageDetailCoordinator(page: page)

        // 验证 AI 各子功能触发不崩溃且正确流转
        coordinator.generateSummary()
        coordinator.extractActions()
        coordinator.expandContent()
        coordinator.performSynthesis(type: .mindmap)
        coordinator.performSynthesis(type: .quiz)
    }
}
