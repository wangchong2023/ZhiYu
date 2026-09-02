//
//  RawStorageListViewDeepTests.swift
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
final class RawStorageListViewDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. RawCategoryType & Domain Helpers

    func testRawCategoryTypeProperties() {
        for category in RawCategoryType.allCases {
            XCTAssertEqual(category.id, category.rawValue)
            XCTAssertFalse(category.systemIconName.isEmpty)
            XCTAssertNotNil(category.defaultColor)
            XCTAssertFalse(category.displayName.isEmpty)
        }
    }

    // MARK: - 2. HighlightedText & RawPageRow Deep Tests

    func testHighlightedTextAndRawPageRow() {
        let highlighted = HighlightedText(text: "Karpathy LLM Wiki Architecture", highlight: "LLM")
        let hostHighlight = UIHostingController(rootView: highlighted)
        XCTAssertNotNil(hostHighlight.view)

        let emptyHighlight = HighlightedText(text: "Plain Text Note", highlight: "")
        let hostEmpty = UIHostingController(rootView: emptyHighlight)
        XCTAssertNotNil(hostEmpty.view)

        let rawPage = KnowledgePage(
            title: "Recorded Lecture.m4a",
            pageType: .source,
            content: "Audio transcript content...",
            sourceURL: "file:///vault/audio/lecture.m4a",
            fileSize: 1024 * 1024 * 5,
            sourceType: "m4a"
        )

        let row = RawPageRow(page: rawPage, searchText: "Lecture")
        let hostRow = UIHostingController(rootView: row)
        XCTAssertNotNil(hostRow.view)
    }

    // MARK: - 3. RawStorageListView Mount & Categories Tests

    func testRawStorageListViewEmptyAndPopulated() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()

        // 1. 空状态测试
        store.pages = []
        let emptyView = RawStorageListView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hostEmpty = UIHostingController(rootView: emptyView)
        window.rootViewController = hostEmpty
        window.makeKeyAndVisible()
        hostEmpty.view.layoutIfNeeded()
        XCTAssertNotNil(hostEmpty.view)

        // 2. 填充 6 大分类原始页面
        let docPage = KnowledgePage(
            title: "Requirements.pdf",
            pageType: .source,
            content: "System requirements",
            sourceURL: "file:///doc.pdf",
            sourceType: "pdf"
        )
        let audioPage = KnowledgePage(
            title: "VoiceMemo.mp3",
            pageType: .source,
            content: "Voice note",
            sourceURL: "file:///memo.mp3",
            sourceType: "mp3"
        )
        let ocrPage = KnowledgePage(
            title: "Whiteboard.png",
            pageType: .source,
            content: "OCR extracted text",
            sourceURL: "file:///board.png",
            sourceType: "png"
        )
        let webPage = KnowledgePage(
            title: "Karpathy Article",
            pageType: .source,
            content: "Web article text",
            sourceURL: "https://karpathy.ai",
            sourceType: "web"
        )
        let clipPage = KnowledgePage(
            title: "Clipboard Snippet",
            pageType: .source,
            content: "Copied code snippet",
            sourceURL: "clipboard://snippet",
            sourceType: "clipboard"
        )
        let manualPage = KnowledgePage(
            title: "Manual Page",
            pageType: .source,
            content: "Manual entry without extension",
            sourceURL: "manual://page",
            sourceType: "custom_ext"
        )

        store.pages = [docPage, audioPage, ocrPage, webPage, clipPage, manualPage]

        let populatedView = RawStorageListView()
            .snapshotEnvironment()
        let hostPopulated = UIHostingController(rootView: populatedView)
        window.rootViewController = hostPopulated
        hostPopulated.view.layoutIfNeeded()
        XCTAssertNotNil(hostPopulated.view)
    }
}
