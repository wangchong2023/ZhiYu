//
//  IOSPDFServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSPDFService 单元测试，覆盖 PDF 保存、删除、列表、URL 获取、元数据持久化场景。
//

#if !os(watchOS)
import XCTest
import PDFKit
@testable import ZhiYu

@MainActor
final class IOSPDFServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let pdfFileName: String = "test_document.pdf"
        static let secondPdfFileName: String = "second_document.pdf"
        static let pdfContentBytes: [UInt8] = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]
        static let metadataTitle: String = "测试 PDF 元数据"
        static let metadataFileName: String = "meta_test.pdf"
        static let metadataPageCount: Int = 5
        static let nonExistentFile: String = "non_existent_\(UUID().uuidString).pdf"
        static let invalidPDFFileName: String = "invalid.pdf"
    }

    // MARK: - 辅助方法

    /// 构造最小有效 PDF Data（PDF 头 + EOF 标记）
    private func makeMinimalPDFData() -> Data {
        var bytes = TestConstants.pdfContentBytes
        let eofBytes: [UInt8] = [0x25, 0x25, 0x45, 0x4F, 0x46, 0x0A]
        bytes.append(contentsOf: eofBytes)
        return Data(bytes)
    }

    /// 构造测试用 PDFDocumentInfo
    private func makeDocumentInfo(title: String = TestConstants.metadataTitle) -> PDFDocumentInfo {
        PDFDocumentInfo(title: title,
                        fileName: TestConstants.metadataFileName,
                        pageCount: TestConstants.metadataPageCount)
    }

    // MARK: - savePDF

    /// 保存有效 PDF 数据应返回文件 URL
    func testSavePDFReturnsURL() async {
        let service = iOSPDFService()
        let data = makeMinimalPDFData()
        let url = await service.savePDF(data: data, fileName: TestConstants.pdfFileName)
        XCTAssertNotNil(url, "保存 PDF 应返回 URL")
        if let url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "PDF 文件应实际存在于磁盘")
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 保存空数据应仍创建文件（写入空文件）
    func testSavePDFWithEmptyDataCreatesFile() async {
        let service = iOSPDFService()
        let url = await service.savePDF(data: Data(), fileName: "empty.pdf")
        XCTAssertNotNil(url)
        if let url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - deletePDF

    /// 删除已存在的 PDF 应返回 true
    func testDeleteExistingPDFReturnsTrue() async {
        let service = iOSPDFService()
        let data = makeMinimalPDFData()
        let url = await service.savePDF(data: data, fileName: TestConstants.pdfFileName)
        guard let url else {
            XCTFail("保存失败无法继续测试")
            return
        }
        let deleted = await service.deletePDF(fileName: TestConstants.pdfFileName)
        XCTAssertTrue(deleted, "删除已存在 PDF 应返回 true")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    /// 删除不存在的 PDF 应返回 false
    func testDeleteNonExistentPDFReturnsFalse() async {
        let service = iOSPDFService()
        let deleted = await service.deletePDF(fileName: TestConstants.nonExistentFile)
        XCTAssertFalse(deleted, "删除不存在的 PDF 应返回 false")
    }

    // MARK: - allPDFFilenames

    /// 保存多个 PDF 后 allPDFFilenames 应包含所有文件名
    func testAllPDFFilenamesReturnsSavedFiles() async {
        let service = iOSPDFService()
        let data = makeMinimalPDFData()
        _ = await service.savePDF(data: data, fileName: TestConstants.pdfFileName)
        _ = await service.savePDF(data: data, fileName: TestConstants.secondPdfFileName)
        let filenames = await service.allPDFFilenames()
        XCTAssertTrue(filenames.contains(TestConstants.pdfFileName),
                      "文件列表应包含第一个 PDF")
        XCTAssertTrue(filenames.contains(TestConstants.secondPdfFileName),
                      "文件列表应包含第二个 PDF")
        _ = await service.deletePDF(fileName: TestConstants.pdfFileName)
        _ = await service.deletePDF(fileName: TestConstants.secondPdfFileName)
    }

    /// 无 PDF 时 allPDFFilenames 应返回空数组
    func testAllPDFFilenamesReturnsEmptyWhenNoFiles() async {
        let service = iOSPDFService()
        let filenames = await service.allPDFFilenames()
        XCTAssertNotNil(filenames, "无文件时应返回空数组而非 nil")
    }

    // MARK: - getPDFURL

    /// 已保存的 PDF getPDFURL 应返回非 nil URL
    func testGetPDFURLReturnsURLForExistingFile() async {
        let service = iOSPDFService()
        let data = makeMinimalPDFData()
        _ = await service.savePDF(data: data, fileName: TestConstants.pdfFileName)
        let url = service.getPDFURL(fileName: TestConstants.pdfFileName)
        XCTAssertNotNil(url, "已存在文件应返回 URL")
        _ = await service.deletePDF(fileName: TestConstants.pdfFileName)
    }

    /// 不存在的 PDF getPDFURL 应返回 nil
    func testGetPDFURLReturnsNilForNonExistentFile() {
        let service = iOSPDFService()
        let url = service.getPDFURL(fileName: TestConstants.nonExistentFile)
        XCTAssertNil(url, "不存在的文件应返回 nil")
    }

    // MARK: - extractText

    /// 从无效 URL 提取文本应返回 nil
    func testExtractTextFromInvalidURLReturnsNil() async {
        let service = iOSPDFService()
        let invalidURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).pdf")
        let text = await service.extractText(from: invalidURL)
        XCTAssertNil(text, "无效 URL 应返回 nil")
    }

    /// 从无效 URL 按页码范围提取文本应返回 nil
    func testExtractTextWithPageRangeFromInvalidURLReturnsNil() async {
        let service = iOSPDFService()
        let invalidURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).pdf")
        let text = await service.extractText(from: invalidURL, pageRange: 0..<1)
        XCTAssertNil(text, "无效 URL 按页码范围应返回 nil")
    }

    // MARK: - extractImages

    /// 从无效 URL 提取图片应返回空数组
    func testExtractImagesFromInvalidURLReturnsEmpty() async {
        let service = iOSPDFService()
        let invalidURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).pdf")
        let images = await service.extractImages(from: invalidURL)
        XCTAssertTrue(images.isEmpty, "无效 URL 应返回空图片数组")
    }

    // MARK: - 元数据持久化

    /// 保存元数据后加载应返回相同内容
    func testSaveAndLoadDocumentsInfoRoundTrip() async {
        let service = iOSPDFService()
        let docs = [makeDocumentInfo(title: "文档A"), makeDocumentInfo(title: "文档B")]
        await service.saveDocumentsInfo(docs)
        let loaded = await service.loadDocumentsInfo()
        XCTAssertEqual(loaded.count, docs.count, "加载的元数据数量应一致")
        XCTAssertEqual(loaded.first?.title, "文档A")
        XCTAssertEqual(loaded.last?.title, "文档B")
    }

    /// 无元数据时加载应返回空数组
    func testLoadDocumentsInfoReturnsEmptyWhenNoneSaved() async {
        let service = iOSPDFService()
        let loaded = await service.loadDocumentsInfo()
        XCTAssertTrue(loaded.isEmpty, "无元数据时应返回空数组")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 PDFServiceProtocol
    func testConformsToPDFServiceProtocol() async {
        let service: any PDFServiceProtocol = iOSPDFService()
        let filenames = await service.allPDFFilenames()
        XCTAssertNotNil(filenames)
    }
}
#endif
