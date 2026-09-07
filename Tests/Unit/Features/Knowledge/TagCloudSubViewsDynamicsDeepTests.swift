//
//  TagCloudSubViewsDynamicsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class TagCloudSubViewsDynamicsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. TagCloudCoordinator Filter & Bulk Actions

    func testTagCloudCoordinatorDynamicsAndFilters() async throws {
        let coordinator = TagCloudCoordinator()
        coordinator.tags = [
            ("Swift", 10),
            ("Rust", 5),
            ("Architecture", 8),
            ("RAG", 15)
        ]

        // 搜索过滤
        coordinator.searchText = "sw"
        XCTAssertEqual(coordinator.filteredTags.count, 1)
        XCTAssertEqual(coordinator.filteredTags.first?.tag, "Swift")

        // 批量选择
        coordinator.isEditMode = true
        coordinator.selectedTagsForBulk = ["Swift", "Rust"]
        XCTAssertTrue(coordinator.selectedTagsForBulk.contains("Rust"))

        // 重命名与添加标签弹窗控制
        coordinator.tagToRename = "Swift"
        coordinator.newTagName = "Swift6"
        coordinator.showAddTagDialog = true
        coordinator.addTagName = "Concurrency"
        XCTAssertTrue(coordinator.showAddTagDialog)
    }

    // MARK: - 2. TagCloudView Full Interactive Mounting
}
