//
//  TagStorePureFunctionTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 TagStore 的纯函数方法：getAllTags/sortedTags 的标签频率统计、去重、排序等语义。
//

import XCTest
@testable import ZhiYu

@MainActor
final class TagStorePureFunctionTests: XCTestCase {

    private let store = TagStore()

    // MARK: - getAllTags

    func testGetAllTags_emptyPages_returnsEmptyDict() {
        let result = store.getAllTags(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testGetAllTags_singlePageSingleTag_returnsCountOne() {
        let page = KnowledgePage(title: "A", tags: ["swift"])
        let result = store.getAllTags(from: [page])
        XCTAssertEqual(result["swift"], 1)
    }

    func testGetAllTags_multiplePagesSameTag_aggregatesCount() {
        let pageA = KnowledgePage(title: "A", tags: ["swift", "ios"])
        let pageB = KnowledgePage(title: "B", tags: ["swift", "macos"])
        let result = store.getAllTags(from: [pageA, pageB])
        XCTAssertEqual(result["swift"], 2, "swift 出现在两个页面应计数为 2")
        XCTAssertEqual(result["ios"], 1)
        XCTAssertEqual(result["macos"], 1)
    }

    func testGetAllTags_duplicateTagsInSamePage_countedOncePerPage() {
        // KnowledgePage.tags 是 [String]，可能有重复
        let page = KnowledgePage(title: "A", tags: ["swift", "swift", "ios"])
        let result = store.getAllTags(from: [page])
        XCTAssertEqual(result["swift"], 2, "同一页面内重复标签应计数为出现次数")
    }

    func testGetAllTags_noTags_returnsEmptyDict() {
        let page = KnowledgePage(title: "A", tags: [])
        let result = store.getAllTags(from: [page])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - sortedTags

    func testSortedTags_emptyPages_returnsEmptyArray() {
        let result = store.sortedTags(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testSortedTags_singleTag_returnsSingleElement() {
        let page = KnowledgePage(title: "A", tags: ["swift"])
        let result = store.sortedTags(from: [page])
        XCTAssertEqual(result, ["swift"])
    }

    func testSortedTags_multipleTags_sortedAlphabetically() {
        let page = KnowledgePage(title: "A", tags: ["zebra", "apple", "mango"])
        let result = store.sortedTags(from: [page])
        XCTAssertEqual(result, ["apple", "mango", "zebra"])
    }

    func testSortedTags_duplicateTagsAcrossPages_deduplicated() {
        let pageA = KnowledgePage(title: "A", tags: ["swift", "ios"])
        let pageB = KnowledgePage(title: "B", tags: ["swift", "macos"])
        let result = store.sortedTags(from: [pageA, pageB])
        XCTAssertEqual(result, ["ios", "macos", "swift"], "应去重并按字母排序")
    }

    func testSortedTags_caseSensitive_sortsByRawValue() {
        // Set<String> 去重区分大小写
        let page = KnowledgePage(title: "A", tags: ["Swift", "swift"])
        let result = store.sortedTags(from: [page])
        XCTAssertEqual(result.count, 2, "大小写不同的标签应视为不同标签")
    }

    // MARK: - 一致性

    func testGetAllTags_andSortedTags_consistentKeys() {
        let pageA = KnowledgePage(title: "A", tags: ["swift", "ios"])
        let pageB = KnowledgePage(title: "B", tags: ["swift", "macos"])
        let allTags = store.getAllTags(from: [pageA, pageB])
        let sortedTags = store.sortedTags(from: [pageA, pageB])
        XCTAssertEqual(Set(allTags.keys), Set(sortedTags), "getAllTags 的键应与 sortedTags 一致")
    }
}
