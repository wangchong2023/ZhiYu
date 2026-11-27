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

    /// 缺陷 #230 回归：快速连续输入取消旧防抖任务时，旧任务不得把新搜索的 isSearching 误置为 false
    @MainActor
    func testSearchStore_rapidTypingDoesNotClearNewSearchLoadingState() async throws {
        let store = SearchStore()
        store.searchText = "a"
        try? await Task.sleep(for: .milliseconds(50))
        store.searchText = "ab"
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(store.isSearching, "取消旧防抖任务时，新搜索仍在防抖窗口内，isSearching 必须保持 true")

        // 清理收尾
        store.clearAll()
        XCTAssertFalse(store.isSearching)
    }
}
