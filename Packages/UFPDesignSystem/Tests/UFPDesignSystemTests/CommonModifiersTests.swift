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

@MainActor
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
        let gradientCard = Text("C").accentGradientCardStyle()
        let subtleCapsule = Text("D").accentSubtleCapsule()
        let card = Text("E").cardStyle()
        let borderedCard = Text("F").borderedCardStyle()
        let infoCard = Text("G").infoCardStyle(useBorder: true)
        let smallBorder = Text("H").smallCardBorder()
        let containerCard = Text("I").containerCardStyle()
        let gradientBorder = Text("J").gradientBorderCardStyle()
        XCTAssertNotNil(accent)
        XCTAssertNotNil(padded)
        XCTAssertNotNil(gradientCard)
        XCTAssertNotNil(subtleCapsule)
        XCTAssertNotNil(card)
        XCTAssertNotNil(borderedCard)
        XCTAssertNotNil(infoCard)
        XCTAssertNotNil(smallBorder)
        XCTAssertNotNil(containerCard)
        XCTAssertNotNil(gradientBorder)
    }

    func testCardAndBorderModifiersDefaultTokens() {
        let cardMod = CardStyleModifier()
        XCTAssertEqual(cardMod.horizontalPadding, DesignTokens.Spacing.standardPadding)
        XCTAssertFalse(cardMod.showBorder)

        let containerMod = ContainerCardStyleModifier()
        XCTAssertEqual(containerMod.cornerRadius, DesignTokens.Spacing.cardRadius)
        XCTAssertEqual(containerMod.borderWidth, DesignTokens.Spacing.borderWidth)

        let gradientMod = GradientBorderCardModifier()
        XCTAssertEqual(gradientMod.padding, DesignTokens.Spacing.standardPadding)
        XCTAssertEqual(gradientMod.cornerRadius, DesignTokens.Spacing.standardRadius)
    }
}
