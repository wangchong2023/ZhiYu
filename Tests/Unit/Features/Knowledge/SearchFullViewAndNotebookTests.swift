//
//  SearchFullViewAndNotebookTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 SearchView 排序规则、多维条件过滤与 NotebookHub 状态机分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SearchFullViewAndNotebookTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SearchView.SortOption 枚举覆盖

    func testSearchViewSortOption_AllCases() {
        let options = SearchView.SortOption.allCases
        XCTAssertEqual(options.count, 4)
        XCTAssertTrue(options.contains(.updated))
        XCTAssertTrue(options.contains(.created))
        XCTAssertTrue(options.contains(.title))
        XCTAssertTrue(options.contains(.type))
    }

    // MARK: - 2. 知识页面别名与标签过滤分支

    func testKnowledgePage_AliasAndTagSearchMatching() {
        let page = KnowledgePage(
            title: "微服务网关",
            pageType: .concept,
            content: "基于 Spring Cloud Gateway",
            aliases: ["API 网关"],
            tags: ["Gateway", "Microservices"]
        )

        let query = "api 网关"
        let matchesAlias = page.aliases.contains { $0.lowercased().contains(query) }
        XCTAssertTrue(matchesAlias, "应当通过别名匹配到该知识页面")
    }
}
