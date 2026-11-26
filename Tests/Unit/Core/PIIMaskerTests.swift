//
//  PIIMaskerTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：测试个人隐私数据 (PII) 自动识别与 [REDACTED_PII] 脱敏覆盖。
//

import XCTest
@testable import ZhiYuUnitTestHost

final class PIIMaskerTests: XCTestCase {

    func testPIIMasker_MasksEmailPhoneAPIKeyAndSSN() {
        let sensitiveInput = "我的邮箱是 test@example.com，手机号 13812345678，API Key 是 sk-abc12345678901234567890"
        let masked = PIIMasker.shared.mask(sensitiveInput)

        XCTAssertFalse(masked.contains("test@example.com"), "应当脱敏邮箱")
        XCTAssertFalse(masked.contains("13812345678"), "应当脱敏手机号")
        XCTAssertFalse(masked.contains("sk-abc12345678901234567890"), "应当脱敏 API Key")
        XCTAssertTrue(masked.contains("[REDACTED_PII]"), "应当使用遮蔽占位符，got: \(masked)")
    }

    /// 缺陷 #120 回归：20 位普通流水号不得被 18 位身份证正则误截断，新版 sk-proj- 含连字符/下划线密钥必须完整脱敏
    func testPIIMasker_PreservesLongOrderIDAndMasksProjectAPIKey() {
        let orderID = "12345678901234567890"
        let projectKey = ["sk", "proj", "AbCdEf123456_7890", "XyZ123456"].joined(separator: "-")
        let input = "订单号 \(orderID) 密钥 \(projectKey)"
        let masked = PIIMasker.shared.mask(input)

        XCTAssertTrue(masked.contains(orderID), "20 位普通数字流水号不得被误判为 18 位身份证截断，got: \(masked)")
        XCTAssertFalse(masked.contains(projectKey), "含连字符与下划线的新版项目密钥必须被完整脱敏，got: \(masked)")
        XCTAssertTrue(masked.contains("[REDACTED_PII]"))
    }
}
