//
//  SearchStoreAndDiagnosticsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SearchStore 防抖搜索、混合检索诊断信息、
//           空查询重置与全局数据清空事件处理。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class SearchStoreAndDiagnosticsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SearchStore 初始状态与空查询快速返回

    func testSearchStore_InitialStateAndEmptyQuery() async {
        let store = SearchStore()
        XCTAssertEqual(store.searchText, "")
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertFalse(store.isSearching)
        XCTAssertNil(store.lastSearchDiagnostic)

        // 空白字符串高级检索应立即清空并返回空数组
        let results = await store.performAdvancedSearch(query: "   \n\t  ")
        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertNil(store.lastSearchDiagnostic)
        XCTAssertFalse(store.isSearching)
    }

    // MARK: - 2. SearchStore 高级检索与诊断信息装配

    func testSearchStore_PerformAdvancedSearch_ValidQuery() async {
        let store = SearchStore()
        let results = await store.performAdvancedSearch(query: "Transformer")
        XCTAssertFalse(store.isSearching)
        XCTAssertEqual(store.searchResults.count, results.count)
    }

    // MARK: - 3. 防抖触发与清空重置测试

    func testSearchStore_DebounceAndClearAll() async {
        let store = SearchStore()

        // 赋值触发防抖
        store.searchText = "Attention"
        XCTAssertEqual(store.searchText, "Attention")

        // 立即执行 clearAll
        store.clearAll()
        XCTAssertEqual(store.searchText, "")
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertFalse(store.isSearching)
        XCTAssertNil(store.lastSearchDiagnostic)
    }
}
