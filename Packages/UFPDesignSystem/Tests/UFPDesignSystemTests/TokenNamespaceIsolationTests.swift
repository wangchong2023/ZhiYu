//
//  TokenNamespaceIsolationTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 DesignTokens 命名空间完整性，确保 Token 迁移后无遗漏。
//

import XCTest
@testable import UFPDesignSystem

final class TokenNamespaceIsolationTests: XCTestCase {

    // MARK: - DesignTokens 命名空间完整性

    /// DesignTokens.Spacing 必须存在且可访问
    func testDesignTokensSpacingExists() {
        let _ = DesignTokens.Spacing.small
        let _ = DesignTokens.Spacing.medium
        let _ = DesignTokens.Spacing.standardPadding
    }

    /// DesignTokens.Typography 必须存在且可访问
    func testDesignTokensTypographyExists() {
        let _ = DesignTokens.Typography.bodyFontSize
        let _ = DesignTokens.Typography.titleFont
        let _ = DesignTokens.Typography.HeadingLevel.h1
    }

    /// DesignTokens.Colors 必须存在且可访问
    func testDesignTokensColorsExists() {
        let _ = DesignTokens.Colors.glassOpacity
        let _ = DesignTokens.Colors.Opacity.fullOpacity
    }

    /// DesignTokens.Animations 必须存在且可访问
    func testDesignTokensAnimationsExists() {
        let _ = DesignTokens.Animations.Interaction.standardAnimation
    }

    // MARK: - Token 值不变量验证

    /// Spacing.medium 必须等于 12（app 原始值，非 SPM 包的 16）
    func testSpacingMediumIs12() {
        XCTAssertEqual(DesignTokens.Spacing.medium, 12)
    }

    /// Spacing.standardPadding 必须等于 16
    func testSpacingStandardPaddingIs16() {
        XCTAssertEqual(DesignTokens.Spacing.standardPadding, 16)
    }

    /// Typography.bodyFontSize 必须等于 16
    func testTypographyBodyFontSizeIs16() {
        XCTAssertEqual(DesignTokens.Typography.bodyFontSize, 16)
    }
}
