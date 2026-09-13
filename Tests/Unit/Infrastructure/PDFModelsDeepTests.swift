//
//  PDFModelsDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 Infrastructure 层纯数据模型 PDFModels（PDFDocumentInfo / PDFHighlight）
//           的 init 默认值、CodingKeys 映射、Codable 编解码往返。
//

import XCTest
@testable import ZhiYu

// MARK: - PDFModels 测试

final class PDFModelsDeepTests: XCTestCase {

    /// 验证 PDFDocumentInfo init 含默认值
    func testPDFDocumentInfoInitWithDefaults() {
        let doc = PDFDocumentInfo(title: "文档", fileName: "doc.pdf", pageCount: 10)
        XCTAssertNotNil(doc.id)
        XCTAssertEqual(doc.title, "文档")
        XCTAssertEqual(doc.fileName, "doc.pdf")
        XCTAssertEqual(doc.pageCount, 10)
        XCTAssertEqual(doc.lastReadPage, 0)
        XCTAssertTrue(doc.highlights.isEmpty)
        XCTAssertTrue(doc.linkedPageTitles.isEmpty)
    }

    /// 验证 PDFDocumentInfo init 含全部参数
    func testPDFDocumentInfoInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let highlight = PDFHighlight(pageIndex: 0, text: "高亮")
        let doc = PDFDocumentInfo(
            id: id,
            title: "完整",
            fileName: "full.pdf",
            pageCount: 50,
            addedDate: date,
            lastReadPage: 5,
            highlights: [highlight],
            linkedPageTitles: ["页面A"]
        )
        XCTAssertEqual(doc.id, id)
        XCTAssertEqual(doc.addedDate, date)
        XCTAssertEqual(doc.lastReadPage, 5)
        XCTAssertEqual(doc.highlights.count, 1)
        XCTAssertEqual(doc.linkedPageTitles, ["页面A"])
    }

    /// 验证 PDFDocumentInfo Codable 往返
    func testPDFDocumentInfoCodableRoundTrip() throws {
        let highlight = PDFHighlight(pageIndex: 3, text: "重点", color: "blue", note: "备注")
        let original = PDFDocumentInfo(
            title: "PDF",
            fileName: "test.pdf",
            pageCount: 20,
            highlights: [highlight],
            linkedPageTitles: ["链接1", "链接2"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PDFDocumentInfo.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.pageCount, original.pageCount)
        XCTAssertEqual(decoded.highlights.count, 1)
        XCTAssertEqual(decoded.highlights.first?.text, "重点")
        XCTAssertEqual(decoded.linkedPageTitles, ["链接1", "链接2"])
    }

    /// 验证 PDFHighlight init 含默认值
    func testPDFHighlightInitWithDefaults() {
        let highlight = PDFHighlight(pageIndex: 1, text: "文本")
        XCTAssertNotNil(highlight.id)
        XCTAssertEqual(highlight.pageIndex, 1)
        XCTAssertEqual(highlight.text, "文本")
        XCTAssertEqual(highlight.color, "yellow")
        XCTAssertEqual(highlight.note, "")
    }

    /// 验证 PDFHighlight init 含全部参数
    func testPDFHighlightInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let highlight = PDFHighlight(
            id: id,
            pageIndex: 5,
            text: "高亮文本",
            color: "green",
            note: "笔记",
            creationDate: date
        )
        XCTAssertEqual(highlight.id, id)
        XCTAssertEqual(highlight.color, "green")
        XCTAssertEqual(highlight.note, "笔记")
        XCTAssertEqual(highlight.creationDate, date)
    }

    /// 验证 PDFHighlight Codable 往返
    func testPDFHighlightCodableRoundTrip() throws {
        let original = PDFHighlight(pageIndex: 2, text: "内容", color: "pink", note: "注释")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PDFHighlight.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.pageIndex, original.pageIndex)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.color, original.color)
        XCTAssertEqual(decoded.note, original.note)
    }

    /// 验证 PDFHighlight Identifiable
    func testPDFHighlightIdentifiable() {
        let highlight = PDFHighlight(pageIndex: 0, text: "")
        XCTAssertFalse(highlight.id.uuidString.isEmpty)
    }
}
