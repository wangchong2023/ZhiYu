//
//  DesignSystemReferenceTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 Reference 层原子值集的完整性与正确性。
//

import UFPDesignSystem
import XCTest
@testable import ZhiYu

final class DesignSystemReferenceTests: XCTestCase {

    // MARK: - Spacing 完整性
    func testSpacingScaleHas10Levels() {
        XCTAssertEqual(DesignTokens.Reference.Spacing.zero, 0)
        XCTAssertEqual(DesignTokens.Reference.Spacing.half, 0.5)
        XCTAssertEqual(DesignTokens.Reference.Spacing.one, 1)
        XCTAssertEqual(DesignTokens.Reference.Spacing.two, 2)
        XCTAssertEqual(DesignTokens.Reference.Spacing.three, 3)
        XCTAssertEqual(DesignTokens.Reference.Spacing.four, 4)
        XCTAssertEqual(DesignTokens.Reference.Spacing.six, 6)
        XCTAssertEqual(DesignTokens.Reference.Spacing.eight, 8)
        XCTAssertEqual(DesignTokens.Reference.Spacing.twelve, 12)
        XCTAssertEqual(DesignTokens.Reference.Spacing.sixteen, 16)
    }

    // MARK: - Opacity 完整性
    func testOpacityScaleHas13Levels() {
        XCTAssertEqual(DesignTokens.Reference.Opacity.zero, 0)
        XCTAssertEqual(DesignTokens.Reference.Opacity.five, 0.05)
        XCTAssertEqual(DesignTokens.Reference.Opacity.ten, 0.1)
        XCTAssertEqual(DesignTokens.Reference.Opacity.fifteen, 0.15)
        XCTAssertEqual(DesignTokens.Reference.Opacity.twenty, 0.2)
        XCTAssertEqual(DesignTokens.Reference.Opacity.thirty, 0.3)
        XCTAssertEqual(DesignTokens.Reference.Opacity.forty, 0.4)
        XCTAssertEqual(DesignTokens.Reference.Opacity.fifty, 0.5)
        XCTAssertEqual(DesignTokens.Reference.Opacity.sixty, 0.6)
        XCTAssertEqual(DesignTokens.Reference.Opacity.seventy, 0.7)
        XCTAssertEqual(DesignTokens.Reference.Opacity.eighty, 0.8)
        XCTAssertEqual(DesignTokens.Reference.Opacity.ninety, 0.9)
        XCTAssertEqual(DesignTokens.Reference.Opacity.full, 1.0)
    }

    // MARK: - Radius 完整性
    func testRadiusScaleHas9Levels() {
        XCTAssertEqual(DesignTokens.Reference.Radius.zero, 0)
        XCTAssertEqual(DesignTokens.Reference.Radius.two, 2)
        XCTAssertEqual(DesignTokens.Reference.Radius.four, 4)
        XCTAssertEqual(DesignTokens.Reference.Radius.six, 6)
        XCTAssertEqual(DesignTokens.Reference.Radius.eight, 8)
        XCTAssertEqual(DesignTokens.Reference.Radius.twelve, 12)
        XCTAssertEqual(DesignTokens.Reference.Radius.sixteen, 16)
        XCTAssertEqual(DesignTokens.Reference.Radius.twenty, 20)
        XCTAssertEqual(DesignTokens.Reference.Radius.full, 9999)
    }

    // MARK: - Stroke 完整性
    func testStrokeScaleHas8Levels() {
        XCTAssertEqual(DesignTokens.Reference.Stroke.zero, 0)
        XCTAssertEqual(DesignTokens.Reference.Stroke.half, 0.5)
        XCTAssertEqual(DesignTokens.Reference.Stroke.thin, 0.8)
        XCTAssertEqual(DesignTokens.Reference.Stroke.one, 1)
        XCTAssertEqual(DesignTokens.Reference.Stroke.oneHalf, 1.5)
        XCTAssertEqual(DesignTokens.Reference.Stroke.two, 2)
        XCTAssertEqual(DesignTokens.Reference.Stroke.three, 3)
        XCTAssertEqual(DesignTokens.Reference.Stroke.four, 4)
    }

    // MARK: - FontSize 完整性
    func testFontSizeScaleHas13Levels() {
        XCTAssertEqual(DesignTokens.Reference.FontSize.micro, 10)
        XCTAssertEqual(DesignTokens.Reference.FontSize.caption, 12)
        XCTAssertEqual(DesignTokens.Reference.FontSize.footnote, 13)
        XCTAssertEqual(DesignTokens.Reference.FontSize.subheadline, 14)
        XCTAssertEqual(DesignTokens.Reference.FontSize.body, 16)
        XCTAssertEqual(DesignTokens.Reference.FontSize.headline, 17)
        XCTAssertEqual(DesignTokens.Reference.FontSize.title3, 18)
        XCTAssertEqual(DesignTokens.Reference.FontSize.title2, 20)
        XCTAssertEqual(DesignTokens.Reference.FontSize.title, 24)
        XCTAssertEqual(DesignTokens.Reference.FontSize.largeTitle, 28)
        XCTAssertEqual(DesignTokens.Reference.FontSize.display, 32)
        XCTAssertEqual(DesignTokens.Reference.FontSize.hero, 40)
        XCTAssertEqual(DesignTokens.Reference.FontSize.mega, 48)
    }
}
