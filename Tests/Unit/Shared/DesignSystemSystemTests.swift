//
//  DesignSystemSystemTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 System 层语义映射的正确性，确保所有 token 正确引用 Reference。
//

import XCTest
@testable import ZhiYu

final class DesignSystemSystemTests: XCTestCase {

    // MARK: - SystemSpacing 映射正确性
    func testSystemSpacingMapsToReference() {
        XCTAssertEqual(SystemSpacing.none, Reference.Spacing.zero)
        XCTAssertEqual(SystemSpacing.hairline, Reference.Spacing.half)
        XCTAssertEqual(SystemSpacing.divider, Reference.Spacing.one)
        XCTAssertEqual(SystemSpacing.atomic, Reference.Spacing.two)
        XCTAssertEqual(SystemSpacing.tight, Reference.Spacing.three)
        XCTAssertEqual(SystemSpacing.tiny, Reference.Spacing.four)
        XCTAssertEqual(SystemSpacing.small, Reference.Spacing.six)
        XCTAssertEqual(SystemSpacing.element, Reference.Spacing.eight)
        XCTAssertEqual(SystemSpacing.medium, Reference.Spacing.twelve)
        XCTAssertEqual(SystemSpacing.content, Reference.Spacing.sixteen)
    }

    // MARK: - SystemOpacity 映射正确性
    func testSystemOpacityMapsToReference() {
        XCTAssertEqual(SystemOpacity.hidden, Reference.Opacity.zero)
        XCTAssertEqual(SystemOpacity.ghost, Reference.Opacity.five)
        XCTAssertEqual(SystemOpacity.faint, Reference.Opacity.ten)
        XCTAssertEqual(SystemOpacity.glass, Reference.Opacity.fifteen)
        XCTAssertEqual(SystemOpacity.glassStrong, Reference.Opacity.thirty)
        XCTAssertEqual(SystemOpacity.overlay, Reference.Opacity.sixty)
        XCTAssertEqual(SystemOpacity.disabled, Reference.Opacity.forty)
        XCTAssertEqual(SystemOpacity.active, Reference.Opacity.full)
    }

    func testSystemOpacityTextLevels() {
        XCTAssertEqual(SystemOpacity.textSecondary, Reference.Opacity.eighty)
        XCTAssertEqual(SystemOpacity.textTertiary, Reference.Opacity.seventy)
    }

    // MARK: - SystemRadius 映射正确性
    func testSystemRadiusMapsToReference() {
        XCTAssertEqual(SystemRadius.none, Reference.Radius.zero)
        XCTAssertEqual(SystemRadius.micro, Reference.Radius.two)
        XCTAssertEqual(SystemRadius.chip, Reference.Radius.four)
        XCTAssertEqual(SystemRadius.small, Reference.Radius.eight)
        XCTAssertEqual(SystemRadius.card, Reference.Radius.twelve)
        XCTAssertEqual(SystemRadius.large, Reference.Radius.sixteen)
        XCTAssertEqual(SystemRadius.section, Reference.Radius.twenty)
        XCTAssertEqual(SystemRadius.capsule, Reference.Radius.full)
    }

    // MARK: - SystemStroke 映射正确性
    func testSystemStrokeMapsToReference() {
        XCTAssertEqual(SystemStroke.none, Reference.Stroke.zero)
        XCTAssertEqual(SystemStroke.hairline, Reference.Stroke.half)
        XCTAssertEqual(SystemStroke.border, Reference.Stroke.thin)
        XCTAssertEqual(SystemStroke.divider, Reference.Stroke.one)
        XCTAssertEqual(SystemStroke.emphasis, Reference.Stroke.oneHalf)
        XCTAssertEqual(SystemStroke.selected, Reference.Stroke.two)
        XCTAssertEqual(SystemStroke.heavy, Reference.Stroke.four)
    }

    // MARK: - SystemFontSize 映射正确性
    func testSystemFontSizeMapsToReference() {
        XCTAssertEqual(SystemFontSize.micro, Reference.FontSize.micro)
        XCTAssertEqual(SystemFontSize.caption, Reference.FontSize.caption)
        XCTAssertEqual(SystemFontSize.body, Reference.FontSize.body)
        XCTAssertEqual(SystemFontSize.title, Reference.FontSize.title)
        XCTAssertEqual(SystemFontSize.display, Reference.FontSize.display)
        XCTAssertEqual(SystemFontSize.hero, Reference.FontSize.hero)
    }
}
