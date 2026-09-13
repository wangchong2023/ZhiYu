//
//  ImportRecordSectionSubviewsTests.swift
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
final class ImportRecordSectionSubviewsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 5. ImportPreviewHandler 动作决议完整覆盖

    func testImportPreviewHandlerResolutions() async throws {
        let router = Router()
        let urlOpener = MockURLOpener()
        let shareSheet = MockShareSheet()
        let handler = ImportPreviewHandler(urlOpener: urlOpener, shareSheet: shareSheet, router: router)

        // 1. 手动录入类别 -> .manualEdit (forceRaw 为 false 时)
        let manualRecord = ImportRecord(
            category: ImportCategory.manual.rawValue,
            title: "Quick Scratchpad",
            status: ImportRecordStatus.done,
            rawText: "Manual text content"
        )
        let action1 = handler.resolveAction(for: manualRecord, forceRaw: false)
        XCTAssertEqual(action1, .manualEdit)

        // 2. 手动录入类别 -> .rawTextPreview (forceRaw 为 true 时)
        let action2 = handler.resolveAction(for: manualRecord, forceRaw: true)
        XCTAssertEqual(action2, .rawTextPreview(text: "Manual text content"))

        // 3. 本地纯文本文件 (如 .txt, .md, .swift)
        let tempDir = FileManager.default.temporaryDirectory
        let sampleTxt = tempDir.appendingPathComponent("sample_preview.txt")
        try? "Sample Text Content".write(to: sampleTxt, atomically: true, encoding: .utf8)

        let textFileRecord = ImportRecord(
            category: "file",
            title: "sample_preview.txt",
            status: ImportRecordStatus.done,
            filePath: sampleTxt.path
        )
        let action3 = handler.resolveAction(for: textFileRecord)
        XCTAssertEqual(action3, .localTextFile(path: sampleTxt.path))

        // 4. 本地二进制文件 (如 .zip, .dat)
        let sampleBin = tempDir.appendingPathComponent("sample_archive.zip")
        try? Data([0x50, 0x4B, 0x03, 0x04]).write(to: sampleBin)

        let binFileRecord = ImportRecord(
            category: "file",
            title: "sample_archive.zip",
            status: ImportRecordStatus.done,
            filePath: sampleBin.path
        )
        let action4 = handler.resolveAction(for: binFileRecord)
        XCTAssertEqual(action4, .localBinaryFile(url: URL(fileURLWithPath: sampleBin.path)))

        // 5. 网页链接
        let linkRecord = ImportRecord(
            category: "link",
            title: "Swift Docs",
            status: ImportRecordStatus.done,
            sourceURL: "https://developer.apple.com/swift/"
        )
        let action5 = handler.resolveAction(for: linkRecord)
        XCTAssertEqual(action5, .openURL(url: URL(string: "https://developer.apple.com/swift/")!))

        // 6. 已关联页面 UUID
        let pageUUID = UUID()
        let pageRecord = ImportRecord(
            category: "file",
            title: "Linked Concept",
            status: ImportRecordStatus.done,
            pageID: pageUUID.uuidString
        )
        let action6 = handler.resolveAction(for: pageRecord)
        XCTAssertEqual(action6, .navigateToPage(id: pageUUID))

        // 7. 无任何内容的空白记录
        let emptyRecord = ImportRecord(
            category: "file",
            title: "Empty Record",
            status: ImportRecordStatus.done
        )
        let action7 = handler.resolveAction(for: emptyRecord)
        XCTAssertEqual(action7, .none)
    }

    // MARK: - 6. ImportRecordCard 状态与回调
    // MARK: - 7. ImportRecordSection.handlePreview 静态全分支覆盖
}
