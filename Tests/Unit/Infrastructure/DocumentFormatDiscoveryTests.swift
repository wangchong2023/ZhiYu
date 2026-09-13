//
//  DocumentFormatDiscoveryTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试
//  核心职责：验证 DocumentFormat.detectFormat 对无扩展名、目录点以及双扩展名等文件路径的边界解析行为。
//

import XCTest
@testable import ZhiYu

final class DocumentFormatDiscoveryTests: XCTestCase {

    /// 验证 URL 含路径但无扩展名
    func testDetectFormat_pathWithoutExtension_returnsUnknown() {
        let url = URL(fileURLWithPath: "/path/to/file")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    /// 验证 URL 含目录点但文件无扩展名
    func testDetectFormat_directoryWithDot_returnsUnknown() {
        let url = URL(fileURLWithPath: "/path.to/file")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    /// 验证双扩展名
    func testDetectFormat_doubleExtension_detectsTrueExtension() {
        let url = URL(fileURLWithPath: "test.backup.pdf")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }
}
