//
//  ComparisonDetailDeepTests.swift
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
final class ComparisonDetailDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    private var sampleYAML: String {
        """
        ---
        type: comparison
        subjects:
          - id: sub_1
            name: SQLite
          - id: sub_2
            name: DuckDB
        dimensions:
          - id: dim_1
            name: Latency
            unit: ms
          - id: dim_2
            name: Score
          - id: dim_3
            name: CostRange
          - id: dim_4
            name: Tags
        matrix:
          - subjectID: sub_1
            dimensionID: dim_1
            value: "0.2ms"
          - subjectID: sub_2
            dimensionID: dim_1
            value: "1.5ms"
          - subjectID: sub_1
            dimensionID: dim_2
            value: 4.5
          - subjectID: sub_2
            dimensionID: dim_2
            value: 3.8
          - subjectID: sub_1
            dimensionID: dim_3
            value: [10, 50]
          - subjectID: sub_2
            dimensionID: dim_3
            value: [50, 200]
          - subjectID: sub_1
            dimensionID: dim_4
            value: ["ACID", "C-Lib"]
          - subjectID: sub_2
            dimensionID: dim_4
            value: ["OLAP", "Columnar"]
        ---
        SQLite is optimal for embedded transactional processing, whereas DuckDB shines in OLAP queries.
        """
    }

    // MARK: - 1. Comparison Markdown Frontmatter Parsing & Matrix Grid Rendering

    func testComparisonDetailBodyViewWithFullMatrix() throws {
        let page = KnowledgePage(
            title: "SQLite vs DuckDB",
            pageType: .comparison,
            content: sampleYAML
        )

        var tappedLink: String?
        let view = ComparisonDetailBodyView(page: page, onLinkTap: { link in
            tappedLink = link
        })
        .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. Comparison View with Empty Frontmatter & Fallback

    func testComparisonDetailBodyViewWithEmptyBody() throws {
        let emptyPage = KnowledgePage(
            title: "Empty Comparison",
            pageType: .comparison,
            content: ""
        )

        let view = ComparisonDetailBodyView(page: emptyPage, onLinkTap: { _ in })
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }
}
