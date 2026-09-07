//
//  PageDetailTagCloudCoordinatorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PageDetailTagCloudCoordinatorTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PageDetailCoordinator Pin, Backlinks, and Delete

    func testPageDetailCoordinatorPinAndBacklinks() async throws {
        let store = AppStore()
        let targetPage = KnowledgePage(
            title: "Target Page",
            pageType: .concept,
            content: "I am the target of links."
        )
        let referrerPage = KnowledgePage(
            title: "Referrer Page",
            pageType: .concept,
            content: "Here is a link to [[Target Page]] inside text."
        )

        await store.savePage(targetPage)
        await store.savePage(referrerPage)

        let coordinator = PageDetailCoordinator(page: targetPage)

        // 1. 验证反向链接提取
        let backlinks = coordinator.backlinks
        XCTAssertEqual(backlinks.count, 1)
        XCTAssertEqual(backlinks.first?.title, "Referrer Page")

        // 2. 置顶状态切换
        XCTAssertFalse(coordinator.page.isPinned)
        await coordinator.togglePin()
        XCTAssertTrue(coordinator.page.isPinned)

        // 3. 删除页面
        await coordinator.deletePage()
        let fetched = store.pages.first(where: { $0.id == targetPage.id })
        XCTAssertNil(fetched)
    }

    // MARK: - 2. TagCloudCoordinator Search, Filter, and Bulk Actions

    func testTagCloudCoordinatorSearchAndBulkOperations() async throws {
        let store = AppStore()
        // 将测试 store 注册到 DI 容器，确保 TagCloudCoordinator 内 @Dependency(\.appStore) 解析到同一实例
        ServiceContainer.shared.register(store, for: AppStore.self)
        let page1 = KnowledgePage(title: "Page A", pageType: .concept, content: "Body", tags: ["Swift", "Core"])
        let page2 = KnowledgePage(title: "Page B", pageType: .concept, content: "Body", tags: ["Swift", "UI"])
        await store.savePage(page1)
        await store.savePage(page2)

        let coordinator = TagCloudCoordinator(initialTag: "Swift")
        await coordinator.fetchData()

        XCTAssertEqual(coordinator.selectedTag, "Swift")
        XCTAssertEqual(coordinator.filteredPages.count, 2)

        // 1. 搜索过滤
        coordinator.searchText = "UI"
        XCTAssertEqual(coordinator.filteredTags.count, 1)
        XCTAssertEqual(coordinator.filteredTags.first?.tag, "UI")

        // 2. 批量选择操作
        coordinator.isEditMode = true
        coordinator.selectedTagsForBulk.insert("Swift")
        XCTAssertTrue(coordinator.selectedTagsForBulk.contains("Swift"))
    }
}
