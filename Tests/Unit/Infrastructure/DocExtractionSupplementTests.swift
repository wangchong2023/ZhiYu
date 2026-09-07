//
//  DocExtractionSupplementTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：DocumentExtractionService 补充测试 — canExtract 全格式覆盖、extractText 纯文本与错误路径
//

import XCTest
import Foundation
import Dependencies
import UFPCore
@testable import ZhiYu

// MARK: - DocumentExtractionService 补充测试

final class DocumentExtractionServiceSupplementTests: XCTestCase {

    private var service: DocumentExtractionService!

    override func setUp() {
        super.setUp()
        service = DocumentExtractionService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - canExtract 全格式覆盖

    func testCanExtract_pdf_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .pdf))
    }

    func testCanExtract_docx_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .docx))
    }

    func testCanExtract_xlsx_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .xlsx))
    }

    func testCanExtract_markdown_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .markdown))
    }

    func testCanExtract_plainText_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .plainText))
    }

    func testCanExtract_unknown_returnsFalse() {
        XCTAssertFalse(service.canExtract(format: .unknown))
    }

    // MARK: - extractText 纯文本路径

    func testExtractText_markdownFile_returnsContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).md")
        let expectedContent = "# Test Markdown\n\nThis is test content."
        try expectedContent.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = try await service.extractText(from: tempFile)
        XCTAssertEqual(result, expectedContent)
    }

    func testExtractText_plainTextFile_returnsContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).txt")
        let expectedContent = "Plain text content"
        try expectedContent.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = try await service.extractText(from: tempFile)
        XCTAssertEqual(result, expectedContent)
    }

    // MARK: - extractText 错误路径

    func testExtractText_unsupportedFormat_throwsExtractionFailed() async {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).xyz")
        try? "content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        do {
            _ = try await service.extractText(from: tempFile)
            XCTFail("应抛出 extractionFailed 错误")
        } catch {
            // 预期抛出错误
        }
    }

    func testExtractText_nonExistentFile_throwsError() async {
        let nonExistent = URL(fileURLWithPath: "/tmp/non_existent_file_\(UUID().uuidString).txt")

        do {
            _ = try await service.extractText(from: nonExistent)
            XCTFail("应抛出错误")
        } catch {
            // 预期抛出错误
        }
    }
}
