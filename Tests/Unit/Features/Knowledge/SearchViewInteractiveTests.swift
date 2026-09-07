//
//  SearchViewInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class SearchViewInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    private func createTestPage(
        title: String,
        content: String = "",
        pageType: PageType = .concept,
        status: PageStatus = .active,
        tags: [String] = [],
        aliases: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> KnowledgePage {
        KnowledgePage(
            id: UUID(),
            title: title,
            pageType: pageType,
            content: content,
            aliases: aliases,
            tags: tags,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func testSearchViewMountsSuccessfullyInHostingController() {
        let searchView = SearchView(initialQuery: "Testing", initialFilterType: .concept)
            .snapshotEnvironment()
        let hostingController = UIHostingController(rootView: searchView)
        hostingController.loadViewIfNeeded()
        XCTAssertNotNil(hostingController.view, "SearchView 应该正常在测试容器中实例化与挂载")
    }
}
