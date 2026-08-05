//
//  SystemConstantsTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 SystemConstants 常量值的正确性与回归保护。
//           发现问题 #11：SystemConstants 无任何测试，纯常量也需回归保护防止误改。
//

import XCTest
@testable import UFPCore

final class SystemConstantsTests: XCTestCase {

    // MARK: - 时间换算常量

    func testMillisecondsPerSecond() {
        XCTAssertEqual(SystemConstants.millisecondsPerSecond, 1000.0)
    }

    func testMicrosecondsPerSecond() {
        XCTAssertEqual(SystemConstants.microsecondsPerSecond, 1_000_000.0)
    }

    func testSecondsPerMinute() {
        XCTAssertEqual(SystemConstants.secondsPerMinute, 60.0)
        XCTAssertEqual(SystemConstants.secondsPerMinuteInt, 60)
    }

    func testMicrosecondThreshold() {
        XCTAssertEqual(SystemConstants.microsecondThreshold, 0.001)
    }

    func testSecondThreshold() {
        XCTAssertEqual(SystemConstants.secondThreshold, 1.0)
    }

    // MARK: - 字节换算常量

    func testBytesPerKB() {
        XCTAssertEqual(SystemConstants.bytesPerKB, 1024.0)
    }

    func testBytesPerMB() {
        XCTAssertEqual(SystemConstants.bytesPerMB, 1024.0 * 1024.0)
        XCTAssertEqual(SystemConstants.bytesPerMB, SystemConstants.bytesPerKB * SystemConstants.bytesPerKB)
    }

    func testBytesPerGB() {
        XCTAssertEqual(SystemConstants.bytesPerGB, 1024.0 * 1024.0 * 1024.0)
        XCTAssertEqual(SystemConstants.bytesPerGB,
                       SystemConstants.bytesPerKB * SystemConstants.bytesPerKB * SystemConstants.bytesPerKB)
    }

    func testBytesPerIntegerT() {
        XCTAssertEqual(SystemConstants.bytesPerIntegerT, 4)
    }

    // MARK: - HTTP 状态码

    func testHTTPStatusCodes() {
        XCTAssertEqual(SystemConstants.HTTPStatusCode.ok, 200)
        XCTAssertEqual(SystemConstants.HTTPStatusCode.unauthorized, 401)
        XCTAssertEqual(SystemConstants.HTTPStatusCode.notFound, 404)
        XCTAssertEqual(SystemConstants.HTTPStatusCode.rateLimited, 429)
        XCTAssertEqual(SystemConstants.HTTPStatusCode.internalServerError, 500)
        XCTAssertEqual(SystemConstants.HTTPStatusCode.notImplemented, 501)
    }

    // MARK: - HTTP 请求头

    func testHTTPHeaders() {
        XCTAssertEqual(SystemConstants.HTTPHeader.contentType, "Content-Type")
        XCTAssertEqual(SystemConstants.HTTPHeader.authorization, "Authorization")
        XCTAssertEqual(SystemConstants.HTTPHeader.accept, "Accept")
        XCTAssertEqual(SystemConstants.HTTPHeader.userAgent, "User-Agent")
    }

    // MARK: - HTTP 内容类型

    func testContentTypes() {
        XCTAssertEqual(SystemConstants.ContentType.applicationJSON, "application/json")
        XCTAssertEqual(SystemConstants.ContentType.applicationXML, "application/xml")
        XCTAssertEqual(SystemConstants.ContentType.textPlain, "text/plain")
        XCTAssertEqual(SystemConstants.ContentType.textHTML, "text/html")
        XCTAssertEqual(SystemConstants.ContentType.formURLEncoded, "application/x-www-form-urlencoded")
    }

    // MARK: - 文件扩展名

    func testFileExtensions() {
        XCTAssertEqual(SystemConstants.FileExtension.json, "json")
        XCTAssertEqual(SystemConstants.FileExtension.mlmodelC, "mlmodelc")
        XCTAssertEqual(SystemConstants.FileExtension.mlmodel, "mlmodel")
        XCTAssertEqual(SystemConstants.FileExtension.markdown, "md")
        XCTAssertEqual(SystemConstants.FileExtension.text, "txt")
        XCTAssertEqual(SystemConstants.FileExtension.sqlite, "sqlite")
    }

    // MARK: - URL 协议

    func testURLSchemes() {
        XCTAssertEqual(SystemConstants.URLScheme.https, "https://")
        XCTAssertEqual(SystemConstants.URLScheme.http, "http://")
    }

    // MARK: - 基础字符常量

    func testBaseCharacters() {
        XCTAssertEqual(SystemConstants.Character.hash, "#")
        XCTAssertEqual(SystemConstants.Character.dash, "-")
        XCTAssertEqual(SystemConstants.Character.asterisk, "*")
        XCTAssertEqual(SystemConstants.Character.dot, ".")
        XCTAssertEqual(SystemConstants.Character.comma, ",")
        XCTAssertEqual(SystemConstants.Character.colon, ":")
        XCTAssertEqual(SystemConstants.Character.semicolon, ";")
        XCTAssertEqual(SystemConstants.Character.doubleQuote, "\"")
        XCTAssertEqual(SystemConstants.Character.singleQuote, "'")
        XCTAssertEqual(SystemConstants.Character.slash, "/")
        XCTAssertEqual(SystemConstants.Character.doubleSlash, "//")
        XCTAssertEqual(SystemConstants.Character.backslash, "\\")
        XCTAssertEqual(SystemConstants.Character.underscore, "_")
        XCTAssertEqual(SystemConstants.Character.equals, "=")
        XCTAssertEqual(SystemConstants.Character.space, " ")
        XCTAssertEqual(SystemConstants.Character.newline, "\n")
        XCTAssertEqual(SystemConstants.Character.tab, "\t")
        XCTAssertEqual(SystemConstants.Character.carriageReturn, "\r")
        XCTAssertEqual(SystemConstants.Character.plus, "+")
        XCTAssertEqual(SystemConstants.Character.questionMark, "?")
    }

    // MARK: - 字节换算一致性（复合验证）

    /// 验证 bytesPerMB = bytesPerKB²，bytesPerGB = bytesPerKB³
    /// 防止未来修改 bytesPerKB 后 bytesPerMB/bytesPerGB 未同步更新
    func testByteConversionConsistency() {
        let kb = SystemConstants.bytesPerKB
        XCTAssertEqual(SystemConstants.bytesPerMB, kb * kb,
                       "bytesPerMB 必须等于 bytesPerKB 的平方")
        XCTAssertEqual(SystemConstants.bytesPerGB, kb * kb * kb,
                       "bytesPerGB 必须等于 bytesPerKB 的立方")
    }
}
