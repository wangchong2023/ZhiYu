//
//  DesignSystemReferenceTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 Reference 层原子值集的完整性与正确性。
//

import XCTest
@testable import ZhiYu

final class DesignSystemReferenceTests: XCTestCase {

    // MARK: - Spacing 完整性
    func testSpacingScaleHas10Levels() {
        XCTAssertEqual(Reference.Spacing.zero, 0)
        XCTAssertEqual(Reference.Spacing.half, 0.5)
        XCTAssertEqual(Reference.Spacing.one, 1)
        XCTAssertEqual(Reference.Spacing.two, 2)
        XCTAssertEqual(Reference.Spacing.three, 3)
        XCTAssertEqual(Reference.Spacing.four, 4)
        XCTAssertEqual(Reference.Spacing.six, 6)
        XCTAssertEqual(Reference.Spacing.eight, 8)
        XCTAssertEqual(Reference.Spacing.twelve, 12)
        XCTAssertEqual(Reference.Spacing.sixteen, 16)
    }

    // MARK: - Opacity 完整性
    func testOpacityScaleHas13Levels() {
        XCTAssertEqual(Reference.Opacity.zero, 0)
        XCTAssertEqual(Reference.Opacity.five, 0.05)
        XCTAssertEqual(Reference.Opacity.ten, 0.1)
        XCTAssertEqual(Reference.Opacity.fifteen, 0.15)
        XCTAssertEqual(Reference.Opacity.twenty, 0.2)
        XCTAssertEqual(Reference.Opacity.thirty, 0.3)
        XCTAssertEqual(Reference.Opacity.forty, 0.4)
        XCTAssertEqual(Reference.Opacity.fifty, 0.5)
        XCTAssertEqual(Reference.Opacity.sixty, 0.6)
        XCTAssertEqual(Reference.Opacity.seventy, 0.7)
        XCTAssertEqual(Reference.Opacity.eighty, 0.8)
        XCTAssertEqual(Reference.Opacity.ninety, 0.9)
        XCTAssertEqual(Reference.Opacity.full, 1.0)
    }

    // MARK: - Radius 完整性
    func testRadiusScaleHas9Levels() {
        XCTAssertEqual(Reference.Radius.zero, 0)
        XCTAssertEqual(Reference.Radius.two, 2)
        XCTAssertEqual(Reference.Radius.four, 4)
        XCTAssertEqual(Reference.Radius.six, 6)
        XCTAssertEqual(Reference.Radius.eight, 8)
        XCTAssertEqual(Reference.Radius.twelve, 12)
        XCTAssertEqual(Reference.Radius.sixteen, 16)
        XCTAssertEqual(Reference.Radius.twenty, 20)
        XCTAssertEqual(Reference.Radius.full, 9999)
    }

    // MARK: - Stroke 完整性
    func testStrokeScaleHas8Levels() {
        XCTAssertEqual(Reference.Stroke.zero, 0)
        XCTAssertEqual(Reference.Stroke.half, 0.5)
        XCTAssertEqual(Reference.Stroke.thin, 0.8)
        XCTAssertEqual(Reference.Stroke.one, 1)
        XCTAssertEqual(Reference.Stroke.oneHalf, 1.5)
        XCTAssertEqual(Reference.Stroke.two, 2)
        XCTAssertEqual(Reference.Stroke.three, 3)
        XCTAssertEqual(Reference.Stroke.four, 4)
    }

    // MARK: - FontSize 完整性
    func testFontSizeScaleHas13Levels() {
        XCTAssertEqual(Reference.FontSize.micro, 10)
        XCTAssertEqual(Reference.FontSize.caption, 12)
        XCTAssertEqual(Reference.FontSize.footnote, 13)
        XCTAssertEqual(Reference.FontSize.subheadline, 14)
        XCTAssertEqual(Reference.FontSize.body, 16)
        XCTAssertEqual(Reference.FontSize.headline, 17)
        XCTAssertEqual(Reference.FontSize.title3, 18)
        XCTAssertEqual(Reference.FontSize.title2, 20)
        XCTAssertEqual(Reference.FontSize.title, 24)
        XCTAssertEqual(Reference.FontSize.largeTitle, 28)
        XCTAssertEqual(Reference.FontSize.display, 32)
        XCTAssertEqual(Reference.FontSize.hero, 40)
        XCTAssertEqual(Reference.FontSize.mega, 48)
    }
}
