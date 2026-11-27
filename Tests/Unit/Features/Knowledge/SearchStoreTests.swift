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
@testable import ZhiYuUnitTestHost

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

    // MARK: - 多 Vault 切换隔离（缺陷 #176）

    func testVaultWillSwitchClearsSearchTextResultsAndDiagnostics() async {
        store.searchText = "Vault A 私密搜索词"
        store.searchResults = [KnowledgePage(title: "Vault A 私密页面")]
        store.lastSearchDiagnostic = SearchDiagnosticInfo(
            query: "Vault A 私密搜索词",
            rewrittenQuery: "Vault A 私密搜索词",
            ftsCount: 1,
            vectorCount: 0,
            rrfTopResults: []
        )

        NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)

        XCTAssertEqual(store.searchText, "", "切换 Vault 后必须清空搜索关键词")
        XCTAssertTrue(store.searchResults.isEmpty, "切换 Vault 后必须清空旧笔记本搜索结果")
        XCTAssertNil(store.lastSearchDiagnostic, "切换 Vault 后必须清空旧搜索诊断信息")
        XCTAssertFalse(store.isSearching)
    }
}
