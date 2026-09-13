//
//  LintServiceEdgeCaseTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LintService 开展原始页面、自引用链接、循环链接、空页面与重复标题的边界单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - LintService Edge Cases
@MainActor
final class LintServiceEdgeCasesTests: XCTestCase {

    var lintService: LintService!
    var linkService: LinkService!

    override func setUp() async throws {
        try await super.setUp()
        lintService = LintService()
        linkService = LinkService()
    }

    func testNoFalsePositivesForRawPages() async {
        // raw pages should not be flagged as orphans
        let pages = [
            KnowledgePage(title: "DataDump", pageType: .raw, content: String(repeating: "x ", count: 50))
        ]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let orphanIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("orphan") ||
            $0.message.localizedCaseInsensitiveContains("孤立")
        }
        XCTAssertTrue(orphanIssues.isEmpty, "raw type pages should not be flagged as orphans")
    }

    func testSelfReferencingLinkNotFlaggedAsBroken() async {
        let page = KnowledgePage(title: "SelfRef", pageType: .entity, content: "Links to [[SelfRef]]")
        let issues = await lintService.runLint(pages: [page], linkService: linkService)
        let brokenIssues = issues.filter { $0.severity == .error && ($0.message.localizedCaseInsensitiveContains("broken") || $0.message.localizedCaseInsensitiveContains("不存在")) }
        XCTAssertTrue(brokenIssues.isEmpty, "Self-referencing link should not be broken")
    }

    func testCircularLinksHandledGracefully() {
        let pageA = KnowledgePage(title: "A", pageType: .entity, content: "Links to [[B]]")
        let pageB = KnowledgePage(title: "B", pageType: .concept, content: "Links to [[A]]")

        let result = GraphLayoutProcessor.layout(
            pages: [pageA, pageB],
            linkResolver: { title in
                if title == "A" { return pageA }
                if title == "B" { return pageB }
                return nil
            },
            canvasSize: CGSize(width: DesignSystem.Metrics.snapshotGraphCanvasWidth, height: DesignSystem.Metrics.snapshotGraphCanvasHeight)
        )
        XCTAssertEqual(result.edges.count, 2, "Circular links should produce 2 edges")
    }

    func testEmptyPageLintResult() async {
        let issues = await lintService.runLint(pages: [], linkService: linkService)
        XCTAssertTrue(issues.isEmpty, "Empty page should produce no lint issues")
    }

    func testDuplicatePageTitlesDetected() async {
        let pages = [
            KnowledgePage(title: "Duplicate", pageType: .entity, content: String(repeating: "x ", count: 30)),
            KnowledgePage(title: "Duplicate", pageType: .concept, content: String(repeating: "y ", count: 30))
        ]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let dupIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("duplicate") ||
            $0.message.localizedCaseInsensitiveContains("重复")
        }
        XCTAssertFalse(dupIssues.isEmpty, "Duplicate titles should be flagged")
    }
}
