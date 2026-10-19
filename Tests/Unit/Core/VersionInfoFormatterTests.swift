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

    // MARK: - 构建信息时效性与非陈旧性防线 (Build Freshness Gate)

    /// 验证 AppConstants.Version 中的构建信息必须为真实有效、且不得落后于 2026-10-01 的最新构建时间
    /// 严禁构建信息回退到 2026-08 或更早的历史时间戳
    func testBuildTimestamp_isFreshAndNotStale() {
        let timestamp = AppConstants.Version.buildTimestamp
        XCTAssertFalse(timestamp.isEmpty, "构建时间戳不能为空")

        // 验证必须符合 ISO 8601 标准格式
        let formatter = ISO8601DateFormatter()
        guard let buildDate = formatter.date(from: timestamp) else {
            XCTFail("构建时间戳必须为合法 ISO 8601 格式，实际值: \(timestamp)")
            return
        }

        // 验证不能回退到 2026-08 历史陈旧时间戳（基线门禁：必须晚于 2026-10-01）
        let staleThreshold = formatter.date(from: "2026-10-01T00:00:00Z") ?? Date.distantPast
        XCTAssertGreaterThan(buildDate, staleThreshold, "构建时间戳绝不能为 2026-08 等陈旧历史时间，实际为: \(timestamp)")

        // 验证短提交哈希非空且至少为 7 位有效十六进制字符
        let gitHash = AppConstants.Version.gitShortHash
        XCTAssertFalse(gitHash.isEmpty, "Git 短提交哈希不能为空")
        let hexPattern = #"^[0-9a-fA-F]{7,12}$"#
        XCTAssertTrue(gitHash.range(of: hexPattern, options: .regularExpression) != nil, "Git 短哈希必须为 7-12 位 Hex 字符，实际为: \(gitHash)")

        // 验证在 About 视图格式化下能成功渲染为标准年月日时间
        let formatted = VersionInfoFormatter.buildTimestampString(from: ["BUILD_TIMESTAMP": timestamp])
        XCTAssertFalse(formatted.isEmpty, "格式化后的构建时间字符串不能为空")
        XCTAssertTrue(formatted.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil, "格式化后的构建时间格式不正确: \(formatted)")
    }

    /// 验证当从真实 Bundle.main 读取构建时间时，格式化能够正确处理而不崩溃
    func testBundleBuildTimestamp_formatsCorrectlyOrGracefully() {
        let result = VersionInfoFormatter.buildTimestampString(from: Bundle.main.infoDictionary)
        if let raw = Bundle.main.infoDictionary?["BUILD_TIMESTAMP"] as? String, !raw.isEmpty {
            XCTAssertFalse(result.isEmpty)
        }
    }
}
