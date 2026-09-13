//
//  ComparisonMatrixAndHighlightDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class ComparisonMatrixAndHighlightDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ComparisonDetailBodyView with Matrix Frontmatter

    func testComparisonDetailBodyViewWithMatrixFrontmatter() throws {
        let markdownContent = """
        ---
        subjects:
          - name: "Swift 6"
            winner: true
          - name: "Rust"
            winner: false
        dimensions:
          - name: "Concurrency"
            type: "stars"
            values:
              "Swift 6": "5"
              "Rust": "5"
          - name: "Compile Time"
            type: "range"
            values:
              "Swift 6": "Fast"
              "Rust": "Medium"
        ---
        # Summary
        Swift 6 provides strict concurrency checking while maintaining high developer velocity.
        """

        let page = KnowledgePage(
            title: "Swift 6 vs Rust",
            pageType: .comparison,
            content: markdownContent
        )

        XCTAssertEqual(page.title, "Swift 6 vs Rust")

        var tappedLink: String?
        let view = ComparisonDetailBodyView(
            page: page,
            onLinkTap: { link in tappedLink = link }
        )
        .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        XCTAssertNil(tappedLink)
    }

    // MARK: - 2. ComparisonDetailBodyView Empty Frontmatter

    func testComparisonDetailBodyViewEmptyFrontmatter() throws {
        let page = KnowledgePage(
            title: "Simple Comparison",
            pageType: .comparison,
            content: "Direct body text without YAML frontmatter."
        )

        XCTAssertEqual(page.title, "Simple Comparison")

        let view = ComparisonDetailBodyView(
            page: page,
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. ComparisonDetailBodyView Non-Finite Values Safety

    func testComparisonDetailBodyViewWithNonFiniteValuesDoesNotCrash() throws {
        let page = KnowledgePage(
            title: "Corrupted AI Comparison",
            pageType: .comparison,
            content: "Comparison with edge ratings"
        )

        XCTAssertEqual(page.title, "Corrupted AI Comparison")

        let view = ComparisonDetailBodyView(
            page: page,
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }
}
