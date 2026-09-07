//
//  UseCaseTypeConfigurationTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - AI
//  核心职责：验证 UseCaseType 枚举定义完整性。
//

import XCTest
@testable import ZhiYu

final class UseCaseTypeConfigurationTests: XCTestCase {

    /// 验证 UseCaseType.audioScribe 存在且可枚举
    func testUseCaseType_audioScribe_existsInAllCases() {
        let allCases = UseCaseType.allCases
        XCTAssertTrue(allCases.contains(.audioScribe), "UseCaseType.audioScribe 应存在于 allCases 中")
    }
}
