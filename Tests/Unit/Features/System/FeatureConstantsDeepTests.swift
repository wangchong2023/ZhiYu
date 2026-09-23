//
//  FeatureConstantsDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/09/24.
//
//  系统层级：[L2] 业务功能测试 - System
//  核心职责：验证 FeatureConstants 中 AuthErrorTag 与 MockData 常量的存在性、非空性与值正确性。
//

import XCTest
@testable import ZhiYu

final class FeatureConstantsDeepTests: XCTestCase {

    // MARK: - AuthErrorTag 常量

    /// 验证 AuthErrorTag 全部 errorTag 常量非空（用于 TokenManager / PhoneAuthService 日志标记）
    func testAuthErrorTag_全部常量非空() {
        let tags = [
            FeatureConstants.AuthErrorTag.passwordLoginFailed,
            FeatureConstants.AuthErrorTag.smsLoginRegisterFailed,
            FeatureConstants.AuthErrorTag.userProfileFetchFailed,
            FeatureConstants.AuthErrorTag.silentLoginProfileFetchFailed
        ]
        for tag in tags {
            XCTAssertFalse(tag.isEmpty, "AuthErrorTag 常量不应为空字符串")
        }
    }

    /// 验证 silentLoginProfileFetchFailed 常量值正确（修复 A-19 中新增的常量替代硬编码字符串）
    func testAuthErrorTag_silentLoginProfileFetchFailed_值正确() {
        XCTAssertEqual(
            FeatureConstants.AuthErrorTag.silentLoginProfileFetchFailed,
            "Silent login profile fetch failed"
        )
    }

    /// 验证各 errorTag 互不相同，避免日志标记混淆
    func testAuthErrorTag_各常量互不相同() {
        let tags: Set<String> = [
            FeatureConstants.AuthErrorTag.passwordLoginFailed,
            FeatureConstants.AuthErrorTag.smsLoginRegisterFailed,
            FeatureConstants.AuthErrorTag.userProfileFetchFailed,
            FeatureConstants.AuthErrorTag.silentLoginProfileFetchFailed
        ]
        XCTAssertEqual(tags.count, 4, "AuthErrorTag 4 个常量应互不相同")
    }

    // MARK: - MockData 常量

    /// 验证 MockData.notDownloaded 常量值正确（修复中用于替代 DownloadProgressRing 硬编码字符串）
    func testMockData_notDownloaded_值正确() {
        XCTAssertEqual(FeatureConstants.MockData.notDownloaded, "Not Downloaded")
    }

    /// 验证 MockData.notDownloaded 非空
    func testMockData_notDownloaded_非空() {
        XCTAssertFalse(FeatureConstants.MockData.notDownloaded.isEmpty)
    }
}
