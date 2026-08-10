//
//  IngestStoreTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 IngestStore 的 PDF 元数据 CRUD、OCR 转发与文本提取逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class IngestStoreTests: XCTestCase {

    private var store: IngestStore!
    private var mockPDF: MockPDFService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        // 取出已注册的 MockPDFService 实例用于注入 stub
        mockPDF = ServiceContainer.shared.resolve((any PDFServiceProtocol).self) as? MockPDFService
        store = IngestStore()
    }

    override func tearDown() async throws {
        store = nil
        mockPDF = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - PDF 元数据 CRUD

    /// 验证 loadPDFDocuments 初始返回空数组
    func testLoadPDFDocumentsInitiallyEmpty() async {
        let docs = await store.loadPDFDocuments()
        XCTAssertTrue(docs.isEmpty, "初始应无 PDF 文档")
    }

    /// 验证 savePDFDocument 新增文档后可加载
    func testSaveAndLoadPDFDocument() async {
        let doc = PDFDocumentInfo(title: "测试PDF", fileName: "test.pdf", pageCount: 10)
        await store.savePDFDocument(doc)
        let loaded = await store.loadPDFDocuments()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "测试PDF")
    }

    /// 验证 savePDFDocument 更新已存在文档（同 ID）
    func testSavePDFDocumentUpdatesExisting() async {
        let doc = PDFDocumentInfo(title: "原标题", fileName: "test.pdf", pageCount: 5)
        await store.savePDFDocument(doc)

        var updated = doc
        updated.title = "新标题"
        updated.pageCount = 15
        await store.savePDFDocument(updated)

        let loaded = await store.loadPDFDocuments()
        XCTAssertEqual(loaded.count, 1, "同 ID 应更新而非新增")
        XCTAssertEqual(loaded.first?.title, "新标题")
        XCTAssertEqual(loaded.first?.pageCount, 15)
    }

    /// 验证 loadPDFDocument(id:) 按 ID 查找
    func testLoadPDFDocumentByID() async {
        let id = UUID()
        let doc = PDFDocumentInfo(id: id, title: "目标", fileName: "target.pdf", pageCount: 3)
        await store.savePDFDocument(doc)

        let loaded = await store.loadPDFDocument(id: id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.title, "目标")
    }

    /// 验证 loadPDFDocument(id:) 未找到返回 nil
    func testLoadPDFDocumentByIDNotFound() async {
        let loaded = await store.loadPDFDocument(id: UUID())
        XCTAssertNil(loaded)
    }

    /// 验证 loadPDFDocument(fileName:) 返回物理路径
    func testLoadPDFDocumentByFileNameReturnsURL() async {
        let data = Data([0x25, 0x50, 0x44, 0x46])
        _ = await store.savePDFDocument(data: data, fileName: "doc.pdf")

        let url = await store.loadPDFDocument(fileName: "doc.pdf")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.lastPathComponent == "doc.pdf")
    }

    /// 验证 loadPDFDocument(fileName:) 未保存过返回 nil
    func testLoadPDFDocumentByFileNameNotFound() async {
        let url = await store.loadPDFDocument(fileName: "nonexistent.pdf")
        XCTAssertNil(url)
    }

    /// 验证 savePDFDocuments 批量保存
    func testSavePDFDocumentsBatch() async {
        let docs = [
            PDFDocumentInfo(title: "A", fileName: "a.pdf", pageCount: 1),
            PDFDocumentInfo(title: "B", fileName: "b.pdf", pageCount: 2)
        ]
        await store.savePDFDocuments(docs)
        let loaded = await store.loadPDFDocuments()
        XCTAssertEqual(loaded.count, 2)
    }

    /// 验证 deletePDFDocument 删除元数据与物理文件
    func testDeletePDFDocumentRemovesMetadataAndFile() async {
        let data = Data([0x25, 0x50, 0x44, 0x46])
        _ = await store.savePDFDocument(data: data, fileName: "del.pdf")

        let doc = PDFDocumentInfo(title: "待删", fileName: "del.pdf", pageCount: 1)
        await store.savePDFDocument(doc)

        await store.deletePDFDocument(doc)

        let loaded = await store.loadPDFDocuments()
        XCTAssertTrue(loaded.isEmpty, "删除后元数据应清空")

        let url = await store.loadPDFDocument(fileName: "del.pdf")
        XCTAssertNil(url, "删除后物理路径应不可用")
    }

    /// 验证 deletePDFDocument(fileName:) 按 fileName 删除物理文件
    func testDeletePDFDocumentByFileName() async {
        let data = Data([0x25, 0x50, 0x44, 0x46])
        _ = await store.savePDFDocument(data: data, fileName: "byName.pdf")

        let success = await store.deletePDFDocument(fileName: "byName.pdf")
        XCTAssertTrue(success, "已存在文件应删除成功")

        let again = await store.deletePDFDocument(fileName: "byName.pdf")
        XCTAssertFalse(again, "二次删除应返回 false")
    }

    /// 验证 deletePDFDocument(fileName:) 删除不存在的文件返回 false
    func testDeletePDFDocumentByFileNameNotFound() async {
        let success = await store.deletePDFDocument(fileName: "ghost.pdf")
        XCTAssertFalse(success)
    }

    // MARK: - PDF 文本提取

    /// 验证 extractPDFText(from:) 返回文本
    func testExtractPDFTextReturnsText() async {
        mockPDF.stubExtractedText = "Hello PDF"
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let text = await store.extractPDFText(from: url)
        XCTAssertEqual(text, "Hello PDF")
    }

    /// 验证 extractPDFText(from:) 未提取到返回空字符串
    func testExtractPDFTextReturnsEmptyWhenNil() async {
        mockPDF.stubExtractedText = ""
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let text = await store.extractPDFText(from: url)
        XCTAssertEqual(text, "")
    }

    /// 验证 extractPDFText(from:pageRange:) 返回指定页范围文本
    func testExtractPDFTextWithPageRange() async {
        mockPDF.stubExtractedText = "Page range text"
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let text = await store.extractPDFText(from: url, pageRange: 0..<3)
        XCTAssertEqual(text, "Page range text")
    }

    /// 验证 extractPDFText(from:pageRange:) 空范围返回空字符串
    func testExtractPDFTextWithEmptyPageRange() async {
        mockPDF.stubExtractedText = "should not appear"
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let text = await store.extractPDFText(from: url, pageRange: 0..<0)
        XCTAssertEqual(text, "")
    }

    // MARK: - savePDFDocument(data:fileName:)

    /// 验证 savePDFDocument(data:fileName:) 返回 URL
    func testSavePDFDocumentDataReturnsURL() async {
        let data = Data([0x25, 0x50, 0x44, 0x46])
        let url = await store.savePDFDocument(data: data, fileName: "new.pdf")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.lastPathComponent == "new.pdf")
    }
}
