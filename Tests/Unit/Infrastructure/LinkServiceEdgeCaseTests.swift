//
//  LinkServiceEdgeCaseTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LinkService 开展反向链接、标题空白、搜索大小写与标签去重的边界单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - LinkService Edge Cases
@MainActor
final class LinkServiceEdgeCasesTests: XCTestCase {

    var linkService: LinkService!

    override func setUp() async throws {
        try await super.setUp()
        linkService = LinkService()
    }

    func testBacklinksForPageWithNoIncomingLinks() async {
        let pages = [
            KnowledgePage(title: "A", content: "Content"),
            KnowledgePage(title: "B", pageType: .concept, content: "More content")
        ]
        let aID = pages[0].id
        let backlinks = await linkService.backlinks(for: aID, in: pages)
        XCTAssertTrue(backlinks.isEmpty, "Page with no incoming links should have empty backlinks")
    }

    func testPageByTitleWithWhitespace() async {
        let pages = [KnowledgePage(title: "  Trimmed Title  ", pageType: .entity, content: "Content")]
        let found = await linkService.pageByTitle("Trimmed Title", in: pages)
        XCTAssertNil(found, "pageByTitle should not trim whitespace in title")
    }

    func testSearchQueryCaseSensitivity() async {
        let pages = [
            KnowledgePage(title: "UPPERCASE", pageType: .entity, content: "Content"),
            KnowledgePage(title: "lowercase", pageType: .concept, content: "Content")
        ]
        let upperResults = await linkService.search(query: "UPPERCASE", in: pages)
        let lowerResults = await linkService.search(query: "uppercase", in: pages)
        XCTAssertEqual(upperResults.count, 1)
        XCTAssertEqual(lowerResults.count, 1)
    }

    func testSearchByTag() async {
        let pages = [
            KnowledgePage(title: "Tagged", pageType: .entity, content: "Content", tags: ["important", "work"])
        ]
        let results = await linkService.search(query: "important", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Tagged" })
    }

    func testAllTagsDeduplication() async {
        let pages = [
            KnowledgePage(title: "A", pageType: .entity, content: "Content", tags: ["shared"]),
            KnowledgePage(title: "B", pageType: .concept, content: "Content", tags: ["shared", "unique"])
        ]
        let tags = await linkService.allTags(in: pages)
        let sharedTagCount = tags.filter { $0.tag == "shared" }.count
        XCTAssertEqual(sharedTagCount, 1, "shared tag should appear only once in allTags")
    }
}
