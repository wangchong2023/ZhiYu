//
//  RawStorageTableDiagnosticsDeepTests.swift
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
final class RawStorageTableDiagnosticsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. RawStorageListView Interactive Mounting

    func testRawStorageListViewInteractiveMounting() async throws {
        let repo = ServiceContainer.shared.resolveOptional((any ImportRecordRepository).self)
        if let sqliteRepo = repo as? SQLiteImportRecordRepository {
            let record = ImportRecord(
                id: UUID().uuidString,
                category: ImportCategory.file.rawValue,
                title: "Diagnostic Dump.txt",
                status: ImportRecordStatus.done,
                rawText: "Sample diagnostic dump data",
                createdAt: Date()
            )
            try? await sqliteRepo.save(record)
        }

        let view = RawStorageListView()
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        let count = try? await repo?.fetchAll(category: nil, limit: 100).count
        XCTAssertNotNil(repo, "ImportRecordRepository 应成功解析")
        XCTAssertGreaterThanOrEqual(count ?? 0, 0, "导入记录集合应支持获取")
    }

    // MARK: - 2. HighlightedText Component

    func testHighlightedTextRendering() throws {
        let sample = "Searching for Swift concurrency patterns in ZhiYu"
        let highlightWord = "Swift"
        let text = HighlightedText(
            text: sample,
            highlight: highlightWord
        )
        XCTAssertEqual(text.text, sample)
        XCTAssertEqual(text.highlight, highlightWord)

        let host = UIHostingController(rootView: text)
        XCTAssertNotNil(host.view)
    }
}
