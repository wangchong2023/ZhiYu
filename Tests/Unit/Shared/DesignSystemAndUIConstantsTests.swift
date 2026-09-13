//
//  DesignSystemAndUIConstantsTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 设计系统与UI常量测试
//  核心职责：验证 MockColorName、SystemShadow、Color.theme 颜色令牌及通用 UI 符号与占位符完整性。
//

import XCTest
import SwiftUI
@testable import ZhiYu

@MainActor
final class DesignSystemAndUIConstantsTests: XCTestCase {

    /// 验证 MockColorName 颜色字面量常量映射
    func testMockColorName_constants_matchExpectedValues() {
        XCTAssertEqual(FeatureConstants.MockColorName.cyan, "cyan")
        XCTAssertEqual(FeatureConstants.MockColorName.purple, "purple")
        XCTAssertEqual(FeatureConstants.MockColorName.blue, "blue")
        XCTAssertEqual(FeatureConstants.MockColorName.green, "green")
        XCTAssertEqual(FeatureConstants.MockColorName.red, "red")
        XCTAssertEqual(FeatureConstants.MockColorName.orange, "orange")
        XCTAssertEqual(FeatureConstants.MockColorName.yellow, "yellow")
    }

    /// 验证 SystemShadow.radiusSmall 为正值
    func testSystemShadow_radiusSmall_isPositive() {
        XCTAssertGreaterThan(SystemShadow.radiusSmall, 0)
    }

    /// 验证 Color.theme 包含所有标准颜色令牌且正常可访问
    func testColorTheme_standardTokens_areAccessible() {
        let theme = Color.theme
        XCTAssertNotNil(theme.red)
        XCTAssertNotNil(theme.orange)
        XCTAssertNotNil(theme.yellow)
        XCTAssertNotNil(theme.green)
        XCTAssertNotNil(theme.blue)
        XCTAssertNotNil(theme.purple)
        XCTAssertNotNil(theme.pink)
        XCTAssertNotNil(theme.gray)
        XCTAssertNotNil(theme.teal)
        XCTAssertNotNil(theme.cyan)
        XCTAssertNotNil(theme.indigo)
        XCTAssertNotNil(theme.mint)
        XCTAssertNotNil(theme.brown)
    }

    /// 验证 FeatureConstants.Decorator UI 装饰符号
    func testFeatureConstants_decorator_symbolsMatch() {
        XCTAssertEqual(FeatureConstants.Decorator.middleDot, "·")
        XCTAssertEqual(FeatureConstants.Decorator.hash, "#")
        XCTAssertEqual(FeatureConstants.Decorator.percent, "%")
        XCTAssertEqual(FeatureConstants.Decorator.dash, "--")
    }

    /// 验证 FeatureConstants.Placeholder 输入占位符非空
    func testFeatureConstants_placeholder_nonEmpty() {
        XCTAssertFalse(FeatureConstants.Placeholder.apiBaseURL.isEmpty)
        XCTAssertFalse(FeatureConstants.Placeholder.modelName.isEmpty)
    }

    /// 验证 AppConstants.displayName 品牌名称
    func testAppConstants_displayName_isZhiYu() {
        XCTAssertEqual(AppConstants.displayName, "ZhiYu")
    }
}
