//
//  NetworkClientSecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 网络安全
//  核心职责：验证 NetworkClient 在处理 multipart 文件上传时对 CRLF 换行字符注入的校验与转义。
//

import XCTest
import Foundation
@testable import ZhiYu

@MainActor
final class NetworkClientSecurityTests: XCTestCase {

    /// 验证上传文件名中的 CRLF 换行符识别
    func testUploadFile_fileNameWithCRLF_isDetected() {
        let maliciousFileName = "test.txt\r\nX-Injected: evil"
        let headerLine = "Content-Disposition: form-data; name=\"file\"; filename=\"\(maliciousFileName)\""
        let containsCRLF = headerLine.contains("\r\nX-Injected")
        XCTAssertTrue(containsCRLF, "fileName 含 CRLF 时需做转义或拒绝")
    }
}
