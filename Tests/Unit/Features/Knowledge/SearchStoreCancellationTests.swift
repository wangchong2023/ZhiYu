//
//  SearchStoreCancellationTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Knowledge
//  核心职责：验证 SearchStore 取消搜索时 isSearching 状态的重置与防抖流转。
//

import XCTest
@testable import ZhiYuUnitTestHost

final class SearchStoreCancellationTests: XCTestCase {

    /// 验证 SearchStore 取消搜索时 isSearching 被重置为 false
    @MainActor
    func testSearchStore_clearSearchText_resetsIsSearching() async throws {
        let store = SearchStore()
        store.searchText = "test query"
        try? await Task.sleep(nanoseconds: 50_000_000)
        store.searchText = ""
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(store.isSearching, "清空搜索后 isSearching 应为 false")
    }

    /// 验证纯空白搜索词不触发防抖搜索并清空残留诊断状态
    @MainActor
    func testSearchStore_whitespaceOnlyQuery_doesNotTriggerSearch() {
        let store = SearchStore()
        store.searchText = "   \n\t  "
        XCTAssertFalse(store.isSearching, "纯空白搜索词不应进入 isSearching 状态")
        XCTAssertTrue(store.searchResults.isEmpty)
        XCTAssertNil(store.lastSearchDiagnostic)
    }
}
