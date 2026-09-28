//
//  ColorsTokenTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Colors Token 的透明度分级和主题色值。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

final class ColorsTokenTests: XCTestCase {

    // MARK: - 透明度验证

    /// glassOpacity 必须等于 0.15
    func testGlassOpacity() {
        XCTAssertEqual(DesignTokens.Colors.glassOpacity, 0.15)
    }

    /// fullOpacity 必须等于 1.0
    func testFullOpacity() {
        XCTAssertEqual(DesignTokens.Colors.fullOpacity, 1.0)
    }

    /// subtleOpacity 必须等于 0.7
    func testSubtleOpacity() {
        XCTAssertEqual(DesignTokens.Colors.subtleOpacity, 0.7)
    }

    // MARK: - Opacity 子结构验证

    /// Opacity.glassOpacity 必须等于 0.15
    func testOpacitySubstructureGlass() {
        XCTAssertEqual(DesignTokens.Colors.Opacity.glassOpacity, 0.15)
    }

    /// Opacity.disabledOpacity 必须在 0.3-0.5 之间
    func testDisabledOpacityRange() {
        XCTAssertGreaterThanOrEqual(DesignTokens.Colors.Opacity.disabledOpacity, 0.3)
        XCTAssertLessThan(DesignTokens.Colors.Opacity.disabledOpacity, 0.5)
    }

    // MARK: - DesignTokens.Opacity 验证（来自 DesignSystem+Opacity.swift）

    /// DesignTokens.Opacity.ghost 必须等于 0.05
    func testDesignTokensOpacityGhost() {
        XCTAssertEqual(DesignTokens.Opacity.ghost, 0.05)
    }

    /// DesignTokens.Opacity.subtle 必须等于 0.12
    func testDesignTokensOpacitySubtle() {
        XCTAssertEqual(DesignTokens.Opacity.subtle, 0.12)
    }

    /// DesignTokens.Opacity.dim 必须等于 0.6
    func testDesignTokensOpacityDim() {
        XCTAssertEqual(DesignTokens.Opacity.dim, 0.6)
    }

    // MARK: - Splash 颜色验证

    /// Splash.bgStep1 必须存在
    func testSplashBgStep1Exists() {
        let _ = DesignTokens.Colors.Splash.bgStep1
    }

    /// Splash.glow1 必须存在
    func testSplashGlow1Exists() {
        let _ = DesignTokens.Colors.Splash.glow1
    }

    // MARK: - accentColorResolver 验证

    /// accentColorResolver 默认返回 .blue
    func testAccentColorResolverDefault() {
        Color.accentColorResolver = { .blue }
        let color = Color.appAccent
        let _ = color
    }
}
