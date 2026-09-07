//
//  VersionInfoFormatterTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/27.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 测试层
//  核心职责：验证 VersionInfoFormatter 在所有输入组合下的格式化输出正确性，
//          覆盖完整链路 Bundle.infoDictionary → UI 展示字符串。

import XCTest
@testable import ZhiYu

final class VersionInfoFormatterTests: XCTestCase {

    // MARK: - semVerString

    func testSemVerString_fullValidData_formatsCorrectly() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.3"]
        XCTAssertEqual(VersionInfoFormatter.semVerString(from: info), "1.2.3")
    }

    func testSemVerString_missingKey_usesFallback() {
        let info: [String: Any] = ["CFBundleVersion": "10"]
        XCTAssertEqual(VersionInfoFormatter.semVerString(from: info), "0.0.0")
    }

    func testSemVerString_nilDictionary_usesFallback() {
        XCTAssertEqual(VersionInfoFormatter.semVerString(from: nil), "0.0.0")
    }

    func testSemVerString_emptyDictionary_usesFallback() {
        XCTAssertEqual(VersionInfoFormatter.semVerString(from: [:]), "0.0.0")
    }

    // MARK: - buildDetailString

    func testBuildDetailString_fullData_formatsCorrectly() {
        let info: [String: Any] = [
            "CFBundleVersion": "342",
            "GIT_SHORT_HASH": "abc1234"
        ]
        XCTAssertEqual(VersionInfoFormatter.buildDetailString(from: info), "342 · abc1234")
    }

    func testBuildDetailString_nilDictionary_usesFallback() {
        XCTAssertEqual(VersionInfoFormatter.buildDetailString(from: nil), "? · unknown")
    }

    func testBuildDetailString_emptyDictionary_usesFallback() {
        XCTAssertEqual(VersionInfoFormatter.buildDetailString(from: [:]), "? · unknown")
    }

    // MARK: - buildTimestampString

    func testBuildTimestampString_validISO8601_formatsToLocalShort() {
        let info: [String: Any] = ["BUILD_TIMESTAMP": "2026-06-27T15:30:00Z"]
        let result = VersionInfoFormatter.buildTimestampString(from: info)
        let pattern = #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"#
        XCTAssertTrue(result.range(of: pattern, options: .regularExpression) != nil, "实际: '\(result)'")
        XCTAssertFalse(result.isEmpty)
    }

    func testBuildTimestampString_nilDictionary_returnsEmpty() {
        XCTAssertEqual(VersionInfoFormatter.buildTimestampString(from: nil), "")
    }

    func testBuildTimestampString_missingKey_returnsEmpty() {
        XCTAssertEqual(VersionInfoFormatter.buildTimestampString(from: ["CFBundleShortVersionString": "1.0"]), "")
    }

    func testBuildTimestampString_invalidFormat_returnsRawValue() {
        XCTAssertEqual(VersionInfoFormatter.buildTimestampString(from: ["BUILD_TIMESTAMP": "not-valid"]), "not-valid")
    }

    func testBuildTimestampString_emptyString_returnsEmpty() {
        XCTAssertEqual(VersionInfoFormatter.buildTimestampString(from: ["BUILD_TIMESTAMP": ""]), "")
    }

    // MARK: - 穿通场景

    func testEndToEnd_injectScriptOutput_fullInfoDictionary() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "342",
            "GIT_SHORT_HASH": "abc1234",
            "BUILD_TIMESTAMP": "2026-06-27T15:30:00Z"
        ]
        XCTAssertEqual(VersionInfoFormatter.semVerString(from: info), "1.2.3")
        XCTAssertEqual(VersionInfoFormatter.buildDetailString(from: info), "342 · abc1234")
        let buildTime = VersionInfoFormatter.buildTimestampString(from: info)
        XCTAssertTrue(buildTime.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil)
    }
}
