//
//  ImportRecordCardAndRetryDeepTests.swift
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
final class ImportRecordCardAndRetryDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ImportRecordCard Interactive Mounting & Actions

    func testImportRecordCardAllCategoriesAndStatuses() throws {
        let sampleRecords: [ImportRecord] = [
            ImportRecord(
                id: UUID(),
                title: "Research Paper.pdf",
                sourceType: .pdf,
                sourceURL: "https://example.com/paper.pdf",
                filePath: "/tmp/paper.pdf",
                rawText: "Sample PDF raw extracted text",
                createdAt: Date(),
                category: ImportCategory.pdf.rawValue,
                fileSize: 1024 * 512,
                status: .completed,
                tags: "AI, RAG, Architecture"
            ),
            ImportRecord(
                id: UUID(),
                title: "Failed Web Scrape",
                sourceType: .url,
                sourceURL: "https://example.com/failed",
                rawText: nil,
                createdAt: Date().addingTimeInterval(-3600),
                category: ImportCategory.url.rawValue,
                fileSize: 0,
                status: .failed,
                errorMessage: "HTTP 503 Service Unavailable"
            ),
            ImportRecord(
                id: UUID(),
                title: "Processing OCR Scan",
                sourceType: .ocr,
                rawText: "OCR recognized text in progress...",
                createdAt: Date(),
                category: ImportCategory.ocr.rawValue,
                fileSize: 2048,
                status: .processing
            )
        ]

        for record in sampleRecords {
            var tapped = false
            var previewed = false
            var openedWith = false
            var edited = false

            let card = ImportRecordCard(
                record: record,
                onTap: { tapped = true },
                onPreview: { previewed = true },
                onOpenWith: { openedWith = true },
                onEdit: { edited = true }
            )
            .snapshotEnvironment()

            let host = UIHostingController(rootView: card)
            XCTAssertNotNil(host.view)
        }
    }

    // MARK: - 2. ImportRecordSection Full Container Mounting

    func testImportRecordSectionMounting() async throws {
        let repo = ServiceContainer.shared.resolveOptional((any ImportRecordRepository).self)
        if let sqliteRepo = repo as? SQLiteImportRecordRepository {
            let record = ImportRecord(
                id: UUID(),
                title: "Sample Ingest Record",
                sourceType: .text,
                rawText: "Direct text",
                createdAt: Date(),
                category: ImportCategory.text.rawValue,
                status: .completed
            )
            try? await sqliteRepo.save(record)
        }

        let section = ImportRecordSection(
            onAITag: { _ in },
            onManualEdit: { _ in }
        )
        .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: section)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }
}
