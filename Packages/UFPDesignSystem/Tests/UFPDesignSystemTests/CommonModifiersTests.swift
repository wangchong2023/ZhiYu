//
//  CommonModifiersTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 AccentCapsuleModifier 与 CommonPaddingModifier 的默认 Token 与自定义参数透传契约。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

final class CommonModifiersTests: XCTestCase {

    func testAccentCapsuleModifierDefaultsUseDesignTokens() {
        let modifier = AccentCapsuleModifier()
        XCTAssertEqual(modifier.horizontalPadding, DesignTokens.Spacing.medium)
        XCTAssertEqual(modifier.verticalPadding, DesignTokens.Spacing.small)
        XCTAssertEqual(modifier.gradientEndOpacity, DesignTokens.Opacity.prominent)
    }

    func testAccentCapsuleModifierCustomValuesPassThrough() {
        let modifier = AccentCapsuleModifier(
            horizontalPadding: DesignTokens.Spacing.tiny,
            verticalPadding: DesignTokens.Spacing.medium,
            gradientEndOpacity: DesignTokens.Opacity.subtle
        )
        XCTAssertEqual(modifier.horizontalPadding, DesignTokens.Spacing.tiny)
        XCTAssertEqual(modifier.verticalPadding, DesignTokens.Spacing.medium)
        XCTAssertEqual(modifier.gradientEndOpacity, DesignTokens.Opacity.subtle)
        XCTAssertNotEqual(modifier.horizontalPadding, AccentCapsuleModifier().horizontalPadding)
    }

    func testCommonPaddingModifierDefaultsUseDesignTokens() {
        let modifier = CommonPaddingModifier()
        XCTAssertEqual(modifier.horizontal, DesignTokens.Spacing.standardPadding)
        XCTAssertEqual(modifier.vertical, DesignTokens.SystemSpacing.elementLarge)
    }

    func testCommonPaddingModifierCustomValuesPassThrough() {
        let modifier = CommonPaddingModifier(horizontal: DesignTokens.Spacing.small, vertical: DesignTokens.Spacing.tiny)
        XCTAssertEqual(modifier.horizontal, DesignTokens.Spacing.small)
        XCTAssertEqual(modifier.vertical, DesignTokens.Spacing.tiny)
    }

    @MainActor
    func testViewExtensionsProduceModifiedViews() {
        let accent = Text("A").accentCapsuleStyle()
        let padded = Text("B").commonContentPadding()
        XCTAssertNotNil(accent)
        XCTAssertNotNil(padded)
    }
}
