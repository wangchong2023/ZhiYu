//
//  UFPDesignSystemTests.swift
//  UFPDesignSystemTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：UFPDesignSystem 通用设计系统包单元测试套件。
//

import XCTest
@testable import UFPDesignSystem

final class UFPDesignSystemTests: XCTestCase {

    func testDesignSystemSpacingTokensIntegrity() {
        XCTAssertEqual(DesignTokens.Spacing.small, 8.0)
        XCTAssertEqual(DesignTokens.Spacing.medium, 16.0)
        XCTAssertEqual(DesignTokens.Spacing.cardPadding, DesignTokens.Spacing.medium)
    }

    func testModuleBundleExistence() {
        XCTAssertNotNil(Bundle.module, "Bundle.module 必须成功装载资源包")
    }
}
