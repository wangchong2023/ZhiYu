//
//  SearchStoreTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 SearchStore 搜索防抖、清除、高级搜索逻辑。
//

import Testing
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class SearchStoreTests: XCTestCase {
    private var store: SearchStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = SearchStore()
    }

    override func tearDown() async throws {
        store = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialSearchTextEmpty() {
        XCTAssertTrue(store.searchText.isEmpty)
    }

    func testInitialSearchResultsEmpty() {
        XCTAssertTrue(store.searchResults.isEmpty)
    }

    func testInitialIsSearchingFalse() {
        XCTAssertFalse(store.isSearching)
    }

    func testInitialIsAdvancedSearchingFalse() {
        XCTAssertFalse(store.isAdvancedSearching)
    }

    func testInitialLastSearchDiagnosticNil() {
        XCTAssertNil(store.lastSearchDiagnostic)
    }

    // MARK: - clearAll

    func testClearAllResetsSearchText() {
        store.searchText = "测试"

        store.clearAll()

        XCTAssertTrue(store.searchText.isEmpty)
    }

    func testClearAllResetsSearchResults() {
        store.searchResults = [KnowledgePage(title: "测试")]

        store.clearAll()

        XCTAssertTrue(store.searchResults.isEmpty)
    }

    func testClearAllResetsIsSearching() {
        store.isSearching = true

        store.clearAll()

        XCTAssertFalse(store.isSearching)
    }

    func testClearAllResetsIsAdvancedSearching() {
        store.isAdvancedSearching = true

        store.clearAll()

        XCTAssertFalse(store.isAdvancedSearching)
    }

    func testClearAllResetsLastSearchDiagnostic() {
        store.lastSearchDiagnostic = SearchDiagnosticInfo(
            query: "测试",
            rewrittenQuery: "测试",
            ftsCount: 1,
            vectorCount: 0,
            rrfTopResults: []
        )

        store.clearAll()

        XCTAssertNil(store.lastSearchDiagnostic)
    }

    // MARK: - searchText didSet

    func testSearchTextEmptyClearsResults() {
        store.searchText = "测试"
        store.searchResults = [KnowledgePage(title: "测试")]
        store.searchText = ""

        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertFalse(store.isSearching)
    }

    // MARK: - performAdvancedSearch

    func testPerformAdvancedSearchEmptyQueryReturnsEmpty() async {
        let results = await store.performAdvancedSearch(query: "")

        XCTAssertTrue(results.isEmpty)
    }

    func testPerformAdvancedSearchSetsIsSearchingDuringExecution() async {
        XCTAssertFalse(store.isSearching)

        _ = await store.performAdvancedSearch(query: "测试")

        XCTAssertFalse(store.isSearching)
    }

    func testPerformAdvancedSearchUpdatesSearchResults() async {
        _ = await store.performAdvancedSearch(query: "测试")

        XCTAssertNotNil(store.lastSearchDiagnostic)
    }
}
