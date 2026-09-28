//
//  DesignSystemSystemTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 System 层语义映射的正确性，确保所有 token 正确引用 Reference。
//

import UFPDesignSystem
import XCTest
@testable import ZhiYu

final class DesignSystemSystemTests: XCTestCase {

    // MARK: - SystemSpacing 映射正确性
    func testSystemSpacingMapsToReference() {
        XCTAssertEqual(DesignTokens.SystemSpacing.none, DesignTokens.Reference.Spacing.zero)
        XCTAssertEqual(DesignTokens.SystemSpacing.hairline, DesignTokens.Reference.Spacing.half)
        XCTAssertEqual(DesignTokens.SystemSpacing.divider, DesignTokens.Reference.Spacing.one)
        XCTAssertEqual(DesignTokens.SystemSpacing.atomic, DesignTokens.Reference.Spacing.two)
        XCTAssertEqual(DesignTokens.SystemSpacing.tight, DesignTokens.Reference.Spacing.three)
        XCTAssertEqual(DesignTokens.SystemSpacing.tiny, DesignTokens.Reference.Spacing.four)
        XCTAssertEqual(DesignTokens.SystemSpacing.small, DesignTokens.Reference.Spacing.six)
        XCTAssertEqual(DesignTokens.SystemSpacing.element, DesignTokens.Reference.Spacing.eight)
        XCTAssertEqual(DesignTokens.SystemSpacing.medium, DesignTokens.Reference.Spacing.twelve)
        XCTAssertEqual(DesignTokens.SystemSpacing.content, DesignTokens.Reference.Spacing.sixteen)
    }

    // MARK: - SystemOpacity 映射正确性
    func testSystemOpacityMapsToReference() {
        XCTAssertEqual(DesignTokens.SystemOpacity.hidden, DesignTokens.Reference.Opacity.zero)
        XCTAssertEqual(DesignTokens.SystemOpacity.ghost, DesignTokens.Reference.Opacity.five)
        XCTAssertEqual(DesignTokens.SystemOpacity.faint, DesignTokens.Reference.Opacity.ten)
        XCTAssertEqual(DesignTokens.SystemOpacity.glass, DesignTokens.Reference.Opacity.fifteen)
        XCTAssertEqual(DesignTokens.SystemOpacity.glassStrong, DesignTokens.Reference.Opacity.thirty)
        XCTAssertEqual(DesignTokens.SystemOpacity.overlay, DesignTokens.Reference.Opacity.sixty)
        XCTAssertEqual(DesignTokens.SystemOpacity.disabled, DesignTokens.Reference.Opacity.forty)
        XCTAssertEqual(DesignTokens.SystemOpacity.active, DesignTokens.Reference.Opacity.full)
    }

    func testSystemOpacityTextLevels() {
        XCTAssertEqual(DesignTokens.SystemOpacity.textSecondary, DesignTokens.Reference.Opacity.eighty)
        XCTAssertEqual(DesignTokens.SystemOpacity.textTertiary, DesignTokens.Reference.Opacity.seventy)
    }

    // MARK: - SystemRadius 映射正确性
    func testSystemRadiusMapsToReference() {
        XCTAssertEqual(DesignTokens.SystemRadius.none, DesignTokens.Reference.Radius.zero)
        XCTAssertEqual(DesignTokens.SystemRadius.micro, DesignTokens.Reference.Radius.two)
        XCTAssertEqual(DesignTokens.SystemRadius.chip, DesignTokens.Reference.Radius.four)
        XCTAssertEqual(DesignTokens.SystemRadius.small, DesignTokens.Reference.Radius.eight)
        XCTAssertEqual(DesignTokens.SystemRadius.card, DesignTokens.Reference.Radius.twelve)
        XCTAssertEqual(DesignTokens.SystemRadius.large, DesignTokens.Reference.Radius.sixteen)
        XCTAssertEqual(DesignTokens.SystemRadius.section, DesignTokens.Reference.Radius.twenty)
        XCTAssertEqual(DesignTokens.SystemRadius.capsule, DesignTokens.Reference.Radius.full)
    }

    // MARK: - SystemStroke 映射正确性
    func testSystemStrokeMapsToReference() {
        XCTAssertEqual(DesignTokens.SystemStroke.none, DesignTokens.Reference.Stroke.zero)
        XCTAssertEqual(DesignTokens.SystemStroke.hairline, DesignTokens.Reference.Stroke.half)
        XCTAssertEqual(DesignTokens.SystemStroke.border, DesignTokens.Reference.Stroke.thin)
        XCTAssertEqual(DesignTokens.SystemStroke.divider, DesignTokens.Reference.Stroke.one)
        XCTAssertEqual(DesignTokens.SystemStroke.emphasis, DesignTokens.Reference.Stroke.oneHalf)
        XCTAssertEqual(DesignTokens.SystemStroke.selected, DesignTokens.Reference.Stroke.two)
        XCTAssertEqual(DesignTokens.SystemStroke.heavy, DesignTokens.Reference.Stroke.four)
    }

    // MARK: - SystemFontSize 映射正确性
    func testSystemFontSizeMapsToReference() {
        XCTAssertEqual(DesignTokens.SystemFontSize.micro, DesignTokens.Reference.FontSize.micro)
        XCTAssertEqual(DesignTokens.SystemFontSize.caption, DesignTokens.Reference.FontSize.caption)
        XCTAssertEqual(DesignTokens.SystemFontSize.body, DesignTokens.Reference.FontSize.body)
        XCTAssertEqual(DesignTokens.SystemFontSize.title, DesignTokens.Reference.FontSize.title)
        XCTAssertEqual(DesignTokens.SystemFontSize.display, DesignTokens.Reference.FontSize.display)
        XCTAssertEqual(DesignTokens.SystemFontSize.hero, DesignTokens.Reference.FontSize.hero)
    }
}
