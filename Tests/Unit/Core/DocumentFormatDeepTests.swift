//
//  DocumentFormatDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L0] 底层基座层测试
//  核心职责：验证 DocumentFormat 文档格式检测工具的完整性。
//           覆盖 markdown / plainText / docx / xlsx / pdf / unknown 等格式
//           及大小写扩展名、无扩展名等边界场景。
//

import XCTest
@testable import ZhiYu

// MARK: - DocumentFormat 测试

final class DocumentFormatSupplementTests: XCTestCase {

    /// 验证 detectFormat markdown
    func testDetectFormatMarkdown() {
        let url = URL(fileURLWithPath: "test.md")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }

    /// 验证 detectFormat markdownLong
    func testDetectFormatMarkdownLong() {
        let url = URL(fileURLWithPath: "test.markdown")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }

    /// 验证 detectFormat plainText
    func testDetectFormatPlainText() {
        let url = URL(fileURLWithPath: "test.txt")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
    }

    /// 验证 detectFormat textLong
    func testDetectFormatTextLong() {
        let url = URL(fileURLWithPath: "test.text")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
    }

    /// 验证 detectFormat docx
    func testDetectFormatDocx() {
        let url = URL(fileURLWithPath: "test.docx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .docx)
    }

    /// 验证 detectFormat xlsx
    func testDetectFormatXlsx() {
        let url = URL(fileURLWithPath: "test.xlsx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .xlsx)
    }

    /// 验证 detectFormat pdf
    func testDetectFormatPDF() {
        let url = URL(fileURLWithPath: "test.pdf")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }

    /// 验证 detectFormat unknown
    func testDetectFormatUnknown() {
        let url = URL(fileURLWithPath: "test.xyz")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    /// 验证 detectFormat 大写扩展名
    func testDetectFormatUppercaseExtension() {
        let url = URL(fileURLWithPath: "test.PDF")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }

    /// 验证 detectFormat 混合大小写扩展名
    func testDetectFormatMixedCaseExtension() {
        let url = URL(fileURLWithPath: "test.Md")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }

    /// 验证 detectFormat 无扩展名
    func testDetectFormatNoExtension() {
        let url = URL(fileURLWithPath: "test")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }
}
