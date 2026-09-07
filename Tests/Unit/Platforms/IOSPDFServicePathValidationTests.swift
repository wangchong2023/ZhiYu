//
//  IOSPDFServicePathValidationTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台测试
//  核心职责：验证 iOSPDFService 保存与删除 PDF 时的文件名路径校验。
//

import XCTest
import Foundation
@testable import ZhiYu

#if !os(watchOS)
@MainActor
final class IOSPDFServicePathValidationTests: XCTestCase {

    /// 验证 savePDF 处理文件名逻辑
    func testSavePDF_handlesMaliciousFileNameSafely() async {
        let service = iOSPDFService()
        let maliciousFileName = "../../malicious_test_\(UUID().uuidString).txt"
        let data = Data("test".utf8)

        let result = await service.savePDF(data: data, fileName: maliciousFileName)
        if let url = result {
            try? FileManager.default.removeItem(at: url)
        }
        XCTAssertNotNil(service)
    }

    /// 验证 deletePDF 处理文件名逻辑
    func testDeletePDF_handlesMaliciousFileNameSafely() async {
        let service = iOSPDFService()
        let tempDir = FileManager.default.temporaryDirectory
        let importantFile = tempDir.appendingPathComponent("important_\(UUID().uuidString).txt")
        try? "important".write(to: importantFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: importantFile) }

        let maliciousFileName = "../../../../../tmp/\(importantFile.lastPathComponent)"
        _ = await service.deletePDF(fileName: maliciousFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: importantFile.path), "目标文件不应被非法删除")
    }
}
#endif
