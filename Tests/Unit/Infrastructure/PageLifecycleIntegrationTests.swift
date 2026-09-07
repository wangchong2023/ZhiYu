//
//  PageLifecycleIntegrationTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对页面生命周期开展创建链接、反向链接、Lint、撤销与类型分类的集成单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - Page Lifecycle Integration Tests
@MainActor
final class PageLifecycleIntegrationTests: XCTestCase {

    var linkService: LinkService!
    var lintService: LintService!
    var undoService: UndoService!

    override func setUp() async throws {
        try await super.setUp()
        linkService = LinkService()
        lintService = LintService()
        undoService = UndoService()
    }

    func testCreateAndLinkPagesFullLifecycle() async {
        // 1. Create pages
        var pageA = KnowledgePage(title: "Machine Learning", pageType: .concept, content: "Related to [[Neural Network]]")
        let pageB = KnowledgePage(title: "Neural Network", pageType: .entity, content: "Part of [[Machine Learning]]")
        var pageC = KnowledgePage(title: "Data Science", pageType: .concept, content: "Uses machine learning")

        // 2. Add related page
        pageC.relatedPageIDs = [pageA.id]

        let pages = [pageA, pageB, pageC]

        // 3. Verify backlinks
        let mlBacklinks = await linkService.backlinks(for: pageA.id, in: pages)
        XCTAssertEqual(mlBacklinks.count, 2, "ML should have 2 backlinks: from Neural Network and Data Science relatedPageIDs")

        // 4. Verify outgoing links
        XCTAssertEqual(pageA.outgoingLinks, ["Neural Network"])
        XCTAssertEqual(pageB.outgoingLinks, ["Machine Learning"])

        // 5. Verify lint - no broken links
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let brokenCount = issues.filter { $0.severity == .error }.count
        XCTAssertEqual(brokenCount, 0, "All links are valid — no broken links")

        // 6. Undo service integration
        undoService.pushSnapshot(pages)
        XCTAssertTrue(undoService.canUndo)

        // 7. Simulate content update
        pageA.content = "Updated [[Neural Network]] content"
        var updatedPages = pages
        updatedPages[0] = pageA

        // 8. Undo should restore original
        let restored = undoService.undo(currentPages: updatedPages)
        XCTAssertEqual(restored?.first?.content, "Related to [[Neural Network]]")
    }

    func testPageTypeClassificationAffectsStubDetection() {
        // raw pages with lots of content should not be stub
        let rawPage = KnowledgePage(title: "RawData", pageType: .raw, content: String(repeating: "x ", count: 80))
        XCTAssertFalse(rawPage.isStub, "raw page with 80 words should not be stub")

        // But entity with < 100 chars is stub
        let entityPage = KnowledgePage(title: "ShortEntity", pageType: .entity, content: "Too short")
        XCTAssertTrue(entityPage.isStub)
    }

    func testWordCountForMixedCJKAndEnglish() {
        let page = KnowledgePage(title: "Mixed", pageType: .concept, content: "Hello世界123测试")
        // English words: Hello(1), 123(1) = 2, CJK chars: 世界测试 = 4
        // Total = 6
        XCTAssertEqual(page.wordCount, 6)
    }

    func testFolderNamePerType() {
        let typeFolderPairs: [(PageType, String)] = [
            (.entity, "entities"),
            (.concept, "concepts"),
            (.source, "sources"),
            (.comparison, "comparisons"),
            (.raw, "raw")
        ]
        for (type, expected) in typeFolderPairs {
            XCTAssertEqual(KnowledgePage(title: "", pageType: type).folderName, expected)
        }
    }
}
