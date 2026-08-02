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
@testable import ZhiYu

final class PIIMaskerTests: XCTestCase {

    func testPIIMasker_MasksEmailPhoneAPIKeyAndSSN() {
        let sensitiveInput = "我的邮箱是 test@example.com，手机号 13812345678，API Key 是 sk-abc12345678901234567890"
        let masked = PIIMasker.shared.mask(sensitiveInput)

        XCTAssertFalse(masked.contains("test@example.com"), "应当脱敏邮箱")
        XCTAssertFalse(masked.contains("13812345678"), "应当脱敏手机号")
        XCTAssertFalse(masked.contains("sk-abc12345678901234567890"), "应当脱敏 API Key")
        XCTAssertTrue(masked.contains("[REDACTED_PII]"), "应当使用遮蔽占位符，got: \(masked)")
    }
}
