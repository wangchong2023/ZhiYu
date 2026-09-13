//
//  DocumentFormatEdgeCaseTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 DocumentFormat 开展查询字符串、空扩展名与数字文件名的边界格式检测单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - DocumentFormat Edge Cases
final class DocumentFormatEdgeCaseTests: XCTestCase {
    func testDetectFormatWithQueryString() {
        let url = URL(string: "file:///path/to/document.pdf?v=1.0")!
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }

    func testDetectFormatEmptyExtension() {
        let url = URL(fileURLWithPath: "/README")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    func testDetectFormatNumbersInFilename() {
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/file123.pdf")), .pdf)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/doc.2024.docx")), .docx)
    }
}
