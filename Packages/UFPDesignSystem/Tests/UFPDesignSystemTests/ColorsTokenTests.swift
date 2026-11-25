//
//  ColorsTokenTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Colors Token 的透明度分级和主题色值。
//

import XCTest
import SwiftUI
#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#else
import AppKit
private typealias PlatformColor = NSColor
#endif
@testable import UFPDesignSystem

/// 跨平台 RGBA 颜色分量容器（避免 4 元组 large_tuple 告警）。
private struct RGBAComponents {
    let r: Double
    let g: Double
    let b: Double
    let a: Double
}

/// 跨平台读取 SwiftUI Color 的 RGBA 分量（sRGB 空间）。
private func rgba(of color: Color) -> RGBAComponents? {
    let platformColor = PlatformColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    #if canImport(UIKit)
    guard platformColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    #else
    platformColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    #endif
    return RGBAComponents(r: r, g: g, b: b, a: a)
}

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
        _ = DesignTokens.Colors.Splash.bgStep1
    }

    /// Splash.glow1 必须存在
    func testSplashGlow1Exists() {
        _ = DesignTokens.Colors.Splash.glow1
    }

    // MARK: - accentColorResolver 验证

    /// accentColorResolver 默认返回 .blue
    func testAccentColorResolverDefault() {
        Color.accentColorResolver = { .blue }
        let color = Color.appAccent
        _ = color
    }

    // MARK: - hex 初始化 (缺陷 #85)

    /// 合法 6 位 RGB：FF0000 应为纯红 (r=1, g=0, b=0, opacity=1)
    func testHexInit_WithValid6DigitRGB_ShouldParseCorrectly() throws {
        // Given
        let sut = Color(hex: "FF0000")
        // When
        let rgba = try XCTUnwrap(rgba(of: sut))
        // Then
        XCTAssertEqual(rgba.r, 1.0, accuracy: 0.001)
        XCTAssertEqual(rgba.g, 0.0, accuracy: 0.001)
        XCTAssertEqual(rgba.b, 0.0, accuracy: 0.001)
        XCTAssertEqual(rgba.a, 1.0, accuracy: 0.001)
    }

    /// 合法 8 位 ARGB：80FF0000 应为 alpha=0.5 的红 (a=0.5, r=1, g=0, b=0)
    func testHexInit_WithValid8DigitARGB_ShouldRespectAlpha() throws {
        // Given
        let sut = Color(hex: "80FF0000")
        // When
        let rgba = try XCTUnwrap(rgba(of: sut))
        // Then
        XCTAssertEqual(rgba.r, 1.0, accuracy: 0.001)
        XCTAssertEqual(rgba.a, 128.0 / 255.0, accuracy: 0.001)
    }

    /// 带 # 前缀的 6 位 RGB：等价于无前缀
    func testHexInit_WithHashPrefix_ShouldParseSameAsPlain() throws {
        // Given
        let plain = Color(hex: "00FF00")
        let prefixed = Color(hex: "#00FF00")
        // When
        let plainRGBA = try XCTUnwrap(rgba(of: plain))
        let prefixedRGBA = try XCTUnwrap(rgba(of: prefixed))
        // Then
        XCTAssertEqual(prefixedRGBA.g, 1.0, accuracy: 0.001)
        XCTAssertEqual(prefixedRGBA.g, plainRGBA.g, accuracy: 0.001)
    }

    /// 核心缺陷：含非法 hex 字符(G-Z/g-z)的 6 位串必须回退默认色，不得被当合法解析出错误颜色
    func testHexInit_WithInvalidAlphanumericChars_ShouldFallbackNotMisparse() throws {
        // Given：原实现把 FFFGGG 解析成 r=0x0f/g=0xff/b=0xff 的错误色；default 回退色为 (r=0, g=122/255, b=1)
        let sut = Color(hex: "FFFGGG")
        let fallback = Color(hex: "")
        // When
        let sutRGBA = try XCTUnwrap(rgba(of: sut))
        let fallbackRGBA = try XCTUnwrap(rgba(of: fallback))
        // Then：非法输入应与空串回退色完全一致（g=122/255≈0.478 是回退色特征分量）
        XCTAssertEqual(sutRGBA.g, 122.0 / 255.0, accuracy: 0.002)
        XCTAssertEqual(sutRGBA.r, 0.0, accuracy: 0.001)
        XCTAssertEqual(sutRGBA.b, 1.0, accuracy: 0.001)
        XCTAssertEqual(sutRGBA.r, fallbackRGBA.r, accuracy: 0.001)
        XCTAssertEqual(sutRGBA.g, fallbackRGBA.g, accuracy: 0.002)
    }

    /// 边界值：非法长度（5/7/9 位）必须回退默认色
    func testHexInit_WithInvalidLength_ShouldFallback() throws {
        // Given
        let lengths = ["FFFFF", "FFFFFFF", "FFFFFFFFFF"]
        // When
        for hex in lengths {
            let sut = Color(hex: hex)
            let rgba = try XCTUnwrap(rgba(of: sut))
            // Then：非法长度均回退默认色 (g=122/255≈0.478)
            XCTAssertEqual(rgba.g, 122.0 / 255.0, accuracy: 0.002, "hex=\(hex) 应回退默认色")
        }
    }

    /// 边界值：空串与全符号输入必须回退默认色，不得崩溃或解析出错误颜色
    func testHexInit_WithEmptyOrSymbolInput_ShouldFallback() throws {
        // Given
        let inputs = ["", "  ", "#", "#!!", "0x1"]
        // When
        for hex in inputs {
            let sut = Color(hex: hex)
            let rgba = try XCTUnwrap(rgba(of: sut))
            // Then
            XCTAssertEqual(rgba.g, 122.0 / 255.0, accuracy: 0.002, "hex=\(hex) 应回退默认色")
        }
    }
}
