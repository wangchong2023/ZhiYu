//
//  NetworkClientSecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 网络安全
//  核心职责：验证 NetworkClient 在处理 multipart 文件上传时对 CRLF 换行字符注入的校验与转义。
//

import XCTest
import Foundation
@testable import ZhiYuUnitTestHost

@MainActor
final class NetworkClientSecurityTests: XCTestCase {

    private struct UploadHeaderCase {
        let fileName: String
        let mimeType: String
        let label: String
    }

    /// 验证上传文件名中的 CRLF 换行符、双引号逃逸以及 mimeType CRLF 注入均被 uploadFile 拒绝
    func testUploadFile_fileNameWithCRLFOrQuoteAndMimeTypeCRLF_throwsInvalidFileName() async {
        let maliciousCases: [UploadHeaderCase] = [
            UploadHeaderCase(fileName: "test.txt\r\nX-Injected: evil", mimeType: "image/png", label: "fileName CRLF 注入"),
            UploadHeaderCase(fileName: "evil\"; name=\"admin", mimeType: "image/png", label: "fileName 双引号属性逃逸"),
            UploadHeaderCase(fileName: "clean.png", mimeType: "image/png\r\nX-Injected: true", label: "mimeType CRLF 注入"),
            UploadHeaderCase(fileName: "", mimeType: "image/png", label: "空 fileName")
        ]

        for item in maliciousCases {
            do {
                _ = try await NetworkClient.shared.uploadFile(
                    path: "/api/v1/upload",
                    fileData: Data([0x01, 0x02]),
                    fileName: item.fileName,
                    mimeType: item.mimeType,
                    requiresAuth: false
                )
                XCTFail("\(item.label) 应抛出 NetworkError.invalidFileName")
            } catch NetworkError.invalidFileName {
                // 预期拦截
            } catch {
                XCTFail("\(item.label) 应抛出 NetworkError.invalidFileName，实际：\(error)")
            }
        }
    }

    /// 验证 ModelDownloadManager 对含路径穿越字符的 modelId 进行安全清洗
    func testModelDownloadManager_sanitizedDestinationFileName_blocksTraversal() {
        let sanitized = ModelDownloadManager.sanitizedDestinationFileName(for: "../../etc/passwd")
        XCTAssertFalse(sanitized.contains(".."), "清洗后的文件名不得含 ..")
        XCTAssertFalse(sanitized.contains("/"), "清洗后的文件名不得含 /")
        XCTAssertTrue(sanitized.hasSuffix(".bin"))
    }
}
