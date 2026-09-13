//
//  IngestCoordinatorDeepMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class IngestCoordinatorDeepMutationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Ingest IngestCoordinator LifeCycle & Preparation

    func testIngestCoordinatorFormAndPreparation() async throws {
        let coordinator = IngestCoordinator()

        // 1. 测试未达冷却时间时的 performIngest
        coordinator.newTitle = "Test Document Title"
        coordinator.newContent = "# Hello\n\nIngest Content Body"
        coordinator.sourceHint = .manual
        coordinator.performIngest()

        XCTAssertTrue(coordinator.isIngesting)

        // 2. 连续触发触发冷却保护拦截
        coordinator.performIngest()
        XCTAssertTrue(coordinator.isImporting)

        // 3. OCR 大图片超限变异注入
        coordinator.lastImportTime = .distantPast
        coordinator.sourceHint = .ocr
        let limit = Int(AppConstants.Keys.ImportLimits.maxOCRImageSizeBytes)
        coordinator.pendingImageData = Data(repeating: 0xFF, count: limit + 1024)
        let prepResult = coordinator.prepareImportFiles(recordID: UUID().uuidString)
        XCTAssertNil(prepResult)
        XCTAssertTrue(coordinator.showError)
        XCTAssertEqual(coordinator.errorMessage, L10n.Ingest.imageTooLarge)

        // 4. 重置表单
        coordinator.resetForm()
        XCTAssertEqual(coordinator.newTitle, "")
        XCTAssertEqual(coordinator.newContent, "")
        XCTAssertNil(coordinator.newCustomIcon)
        XCTAssertFalse(coordinator.useSmartIngest)
    }

    // MARK: - 2. AI Tagging & JSON Extraction

    func testAITaggingAndJSONExtraction() async throws {
        let coordinator = IngestCoordinator()

        // 1. 测试标准 JSON 提取
        let validJSON = """
        ```json
        {
          "tags": ["Swift", "iOS", "Concurrency"],
          "aliasTitle": "Concurrency In Depth"
        }
        ```
        """
        let extracted = coordinator.extractJSON(from: validJSON)
        XCTAssertEqual(extracted["aliasTitle"] as? String, "Concurrency In Depth")
        let tags = extracted["tags"] as? [String]
        XCTAssertEqual(tags?.count, 3)

        // 2. 测试坏损 JSON 提取容错
        let corruptedJSON = "Here is some text with invalid { tags: [ missing brackets"
        let fallback = coordinator.extractJSON(from: corruptedJSON)
        XCTAssertTrue(fallback.isEmpty)

        // 3. 触发 triggerAITagging
        let record = ImportRecord(
            id: UUID().uuidString,
            category: "manual",
            title: "Test Ingest Record",
            status: ImportRecordStatus.processing,
            rawText: "Some raw text for AI tagging pipeline"
        )
        coordinator.triggerAITagging(for: record)
    }

    // MARK: - 3. Open Manual Form With Historical Record

    func testOpenManualFormWithHistoricalRecord() async throws {
        let coordinator = IngestCoordinator()
        let store = AppStore()
        let testPage = KnowledgePage(
            title: "Historical Page",
            pageType: .concept,
            customIcon: "star.fill",
            content: "Concept content"
        )
        await store.savePage(testPage)

        let record = ImportRecord(
            id: UUID().uuidString,
            category: "manual",
            title: "Historical Title",
            status: ImportRecordStatus.done,
            rawText: "> Source: Manual | 2026-09-02\n\nBody content of page",
            pageID: testPage.id.uuidString
        )

        coordinator.openManualForm(with: record)
        XCTAssertTrue(coordinator.showManualForm)
        XCTAssertEqual(coordinator.newTitle, "Historical Title")
        XCTAssertEqual(coordinator.newContent, "Body content of page")
    }
}
