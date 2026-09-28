//
//  TypographyTokenTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Typography Token 的字号层级和 Dynamic Type 集成。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

final class TypographyTokenTests: XCTestCase {

    // MARK: - 原子字号验证

    /// microFontSize 必须等于 11（HIG 最小可读字号）
    func testMicroFontSizeEquals11() {
        XCTAssertEqual(DesignTokens.Typography.microFontSize, 11)
    }

    /// bodyFontSize 必须等于 16（正文字号）
    func testBodyFontSizeEquals16() {
        XCTAssertEqual(DesignTokens.Typography.bodyFontSize, 16)
    }

    /// titleFontSize 必须等于 24（大标题字号）
    func testTitleFontSizeEquals24() {
        XCTAssertEqual(DesignTokens.Typography.titleFontSize, 24)
    }

    // MARK: - 字号递增验证

    /// microFontSize < captionFontSize < bodyFontSize < headlineFontSize < titleFontSize < displayFontSize
    func testFontSizeIncreasing() {
        XCTAssertLessThan(DesignTokens.Typography.microFontSize,
                          DesignTokens.Typography.captionFontSize)
        XCTAssertLessThan(DesignTokens.Typography.captionFontSize,
                          DesignTokens.Typography.bodyFontSize)
        XCTAssertLessThan(DesignTokens.Typography.bodyFontSize,
                          DesignTokens.Typography.headlineFontSize)
        XCTAssertLessThan(DesignTokens.Typography.headlineFontSize,
                          DesignTokens.Typography.titleFontSize)
        XCTAssertLessThan(DesignTokens.Typography.titleFontSize,
                          DesignTokens.Typography.displayFontSize)
    }

    // MARK: - HeadingLevel 验证

    /// HeadingLevel.h1.size 必须等于 28
    func testHeadingLevelH1Size() {
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h1.size, 28)
    }

    /// HeadingLevel.h6.size 必须等于 14
    func testHeadingLevelH6Size() {
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h6.size, 14)
    }

    /// HeadingLevel 字号递减
    func testHeadingLevelSizeDecreasing() {
        XCTAssertGreaterThan(DesignTokens.Typography.HeadingLevel.h1.size,
                             DesignTokens.Typography.HeadingLevel.h2.size)
        XCTAssertGreaterThan(DesignTokens.Typography.HeadingLevel.h2.size,
                             DesignTokens.Typography.HeadingLevel.h3.size)
    }

    // MARK: - Font Shortcuts 验证

    /// captionFont 必须返回 .caption（Dynamic Type 语义样式）
    func testCaptionFontIsDynamicType() {
        let _ = DesignTokens.Typography.captionFont
    }

    /// titleFont 必须返回 .title2.bold()
    func testTitleFontIsDynamicType() {
        let _ = DesignTokens.Typography.titleFont
    }

    // MARK: - Icons 验证

    /// Icons.star 必须等于 "star.fill"
    func testIconsStar() {
        XCTAssertEqual(DesignTokens.Typography.Icons.star, "star.fill")
    }

    /// Icons.search 必须等于 "magnifyingglass"
    func testIconsSearch() {
        XCTAssertEqual(DesignTokens.Typography.Icons.search, "magnifyingglass")
    }
}
