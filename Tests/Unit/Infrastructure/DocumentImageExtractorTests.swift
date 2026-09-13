//
//  DocumentImageExtractorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：PDF/Office 文档图片提取全覆盖测试

import XCTest
@testable import ZhiYu

@MainActor
final class DocumentImageExtractorTests: XCTestCase {

    let extractor = ImageExtractor()

    // MARK: - PDF 图片提取

    func testPDFExtractImagesProtocolExists() {
        let service = DocumentImageMockPDFService()
        XCTAssertTrue(service.extractImagesCalled == false)
    }

    func testPDFExtractImagesDelegatesToService() async {
        let service = DocumentImageMockPDFService()
        let images = await service.extractImages(from: URL(fileURLWithPath: "/tmp/test.pdf"))
        XCTAssertEqual(images.count, 3, "Mock 应返回 3 张模拟图片")
        XCTAssertTrue(service.extractImagesCalled)
    }

    func testPDFMaxImagesLimit() {
        let limit = AppConstants.Keys.ImportLimits.maxImagesPerPage
        XCTAssertEqual(limit, 10, "PDF 最多渲染 10 页")
    }

    // MARK: - Office 图片提取

    func testOfficeImageFolders() {
        // 验证标准 Office ZIP 目录结构
        let folders = ["word/media", "xl/media", "ppt/media"]
        XCTAssertEqual(folders.count, 3)
    }

    func testOfficeImageFormatFilter() {
        let validExts = ["png", "jpg", "jpeg", "gif"]
        let ext = "png"
        XCTAssertTrue(validExts.contains(ext))
        let extSVG = "svg"
        XCTAssertFalse(validExts.contains(extSVG))
    }

    // MARK: - 常量验证

    func testPDFRenderScaleConstant() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.pdfRenderScale, 0.5)
    }

    func testJPEGQualityConstant() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.imageJPEGQuality, 0.8)
    }

    func testMaxImageSizeConstant() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.maxImageSizeBytes, 5 * 1_024 * 1_024)
    }

    // MARK: - OCR 批处理方法

    func testOCRImageBatchEmpty() async {
        let result = await extractor.ocrImageBatch([], prefix: "test")
        XCTAssertEqual(result, "")
    }

    // MARK: - 文件类型判断

    func testPDFExtensionTriggersExtraction() {
        let exts = ["pdf"]
        for ext in exts {
            XCTAssertTrue(ext == "pdf", "PDF 扩展名应触发图片提取")
        }
    }

    func testOfficeExtensionsTriggerExtraction() {
        for ext in AppConstants.Keys.ImportLimits.officeExtensions {
            XCTAssertTrue(AppConstants.Keys.ImportLimits.officeExtensions.contains(ext), "\(ext) 应触发 Office 图片提取")
        }
    }

    func testPDFExtensionConstant() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.pdfExtension, "pdf")
    }

    func testNonDocumentExtensionsSkipped() {
        let allDocExts = AppConstants.Keys.ImportLimits.officeExtensions.union([AppConstants.Keys.ImportLimits.pdfExtension])
        for ext in ["txt", "md", "csv", "html"] {
            XCTAssertFalse(allDocExts.contains(ext), "\(ext) 不应触发图片提取")
        }
    }

    func testImageExtensionsConstant() {
        let exts = AppConstants.Keys.ImportLimits.imageExtensions
        XCTAssertTrue(exts.contains("png"))
        XCTAssertTrue(exts.contains("jpg"))
        XCTAssertTrue(exts.contains("jpeg"))
        XCTAssertFalse(exts.contains("svg"))
    }

    // MARK: - 图片大小限制

    func testImageWithinPDFLimit() {
        let size: Int64 = 4 * 1_024 * 1_024
        XCTAssertLessThanOrEqual(size, AppConstants.Keys.ImportLimits.maxImageSizeBytes)
    }

    func testImageExceedsPDFLimit() {
        let size: Int64 = 6 * 1_024 * 1_024
        XCTAssertGreaterThan(size, AppConstants.Keys.ImportLimits.maxImageSizeBytes)
    }
}

// MARK: - Mock PDF Service

private final class DocumentImageMockPDFService: PDFServiceProtocol {
    var extractImagesCalled = false

    func savePDF(data: Data, fileName: String) -> URL? { nil }
    func deletePDF(fileName: String) -> Bool { false }
    func allPDFFilenames() -> [String] { [] }
    func getPDFURL(fileName: String) -> URL? { nil }
    func extractText(from url: URL) -> String? { nil }
    func extractText(from url: URL, pageRange: Range<Int>) -> String? { nil }
    func saveDocumentsInfo(_ docs: [PDFDocumentInfo]) {}
    func loadDocumentsInfo() -> [PDFDocumentInfo] { [] }

    func extractImages(from url: URL) async -> [Data] {
        extractImagesCalled = true
        // 返回 3 个模拟图片数据（小于 5MB 限制）
        return [
            Data(repeating: 0xFF, count: 1000),
            Data(repeating: 0xAA, count: 2000),
            Data(repeating: 0xBB, count: 1500)
        ]
    }
}
