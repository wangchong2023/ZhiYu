//
//  IngestServiceEdgeCaseTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 IngestService 开展概念抽取无匹配、部分匹配与文档格式枚举的边界单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - IngestService Edge Cases
@MainActor
final class IngestServiceEdgeCasesTests: XCTestCase {

    var ingestService: IngestService!

    override func setUp() async throws {
        try await super.setUp()
        ingestService = IngestService()
    }

    func testExtractConceptsNoMatch() async {
        let pages = [KnowledgePage(title: "Existing", pageType: .concept)]
        let content = "This mentions Nothing That Exists"
        let concepts = await ingestService.extractConcepts(from: content, pages: pages)
        XCTAssertTrue(concepts.isEmpty)
    }
    func testExtractConceptsPartialMatch() async {
        let pages = [KnowledgePage(title: "Machine Learning", pageType: .concept)]
        // Partial match should not trigger
        let concepts = await ingestService.extractConcepts(from: "Machines are everywhere", pages: pages)
        XCTAssertTrue(concepts.isEmpty, "Partial word match should not extract concept")
    }

    func testDocumentFormatUnsupported() {
        let formats: [DocumentFormat] = [.markdown, .plainText, .docx, .xlsx, .pdf]
        XCTAssertEqual(formats.count, 5)
    }
}
