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

    /// 验证 ModelDownloadManager 对含路径穿越、隐藏文件点号与控制字符的 modelId 进行安全清洗（缺陷 #262）
    func testModelDownloadManager_sanitizedDestinationFileName_blocksTraversal() {
        let sanitized = ModelDownloadManager.sanitizedDestinationFileName(for: "../../etc/passwd")
        XCTAssertFalse(sanitized.contains(".."), "清洗后的文件名不得含 ..")
        XCTAssertFalse(sanitized.contains("/"), "清洗后的文件名不得含 /")
        XCTAssertTrue(sanitized.hasSuffix(".bin"))

        let hidden = ModelDownloadManager.sanitizedDestinationFileName(for: ".secret")
        XCTAssertFalse(hidden.hasPrefix("."), "不得生成以点号开头的隐藏文件名")
        XCTAssertEqual(hidden, "secret.bin")

        let onlyDots = ModelDownloadManager.sanitizedDestinationFileName(for: "...")
        XCTAssertFalse(onlyDots.hasPrefix("."))
        XCTAssertTrue(onlyDots.hasSuffix(".bin"))

        let withControl = ModelDownloadManager.sanitizedDestinationFileName(for: "gemma\r\n-4\u{0000}")
        XCTAssertEqual(withControl, "gemma-4.bin")
    }

    /// 验证 ModelDownloadManager.startDownload 拦截空白 modelId（缺陷 #262）
    func testModelDownloadManager_startDownload_rejectsBlankModelID() async throws {
        let manager = ModelDownloadManager(configuration: .ephemeral)
        let validURL = try XCTUnwrap(URL(string: "https://example.com/model.bin"))
        do {
            try await manager.startDownload(modelId: "   \n", remoteURL: validURL)
            XCTFail("空白 modelId 应被拦截抛出 URLError.badURL")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badURL)
        }
    }

    /// 验证 NetworkClient 同源 URL 守卫拦截权威段劫持并清洗 Bearer Token 控制字符（缺陷 #261）
    func testNetworkClient_buildSafeBackendURL_blocksHostOverrideAndSanitizesBearerToken() throws {
        let base = "https://api.zhiyu.app"
        let valid = try NetworkClient.buildSafeBackendURL(baseURLString: base, path: "/api/v1/pages")
        XCTAssertEqual(valid.absoluteString, "https://api.zhiyu.app/api/v1/pages")

        let maliciousPaths = [
            "@evil.com/steal",
            ".evil.com/api",
            "//evil.com/api",
            "https://evil.com/api",
            ""
        ]
        for badPath in maliciousPaths {
            XCTAssertThrowsError(
                try NetworkClient.buildSafeBackendURL(baseURLString: base, path: badPath),
                "恶意跨源路径应被拦截: \(badPath)"
            )
        }

        XCTAssertNil(NetworkClient.sanitizedBearerToken("  \r\n\0 "))
        XCTAssertEqual(NetworkClient.sanitizedBearerToken(" jwt.token\r\n "), "jwt.token")
    }
}
