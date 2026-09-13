//
//  IOSPDFServiceSecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台安全测试
//  核心职责：验证 iOSPDFService 对路径穿越文件名的防御与图片抽取最大页数限制。
//

import XCTest
import Foundation
import UFPCore
@testable import ZhiYu

#if !os(watchOS)
@MainActor
final class IOSPDFServiceSecurityTests: XCTestCase {

    /// 验证 getPDFURL 拒绝含路径穿越特征的文件名
    func testGetPDFURL_pathTraversal_isRejected() {
        #if os(iOS)
        let pdfService = iOSPDFService()
        XCTAssertNil(pdfService.getPDFURL(fileName: "../../../etc/passwd"), "应拒绝含 ../ 的路径穿越文件名")
        XCTAssertNil(pdfService.getPDFURL(fileName: "subdir/file.pdf"), "应拒绝含 / 的路径穿越文件名")
        XCTAssertNil(pdfService.getPDFURL(fileName: "nonexistent.pdf"))
        #endif
    }

    /// 验证 maxPagesForImageExtraction 常量配置为 20
    func testMaxPagesForImageExtraction_matchesConstantValue() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.maxPagesForImageExtraction, 20)
    }
}
#endif
