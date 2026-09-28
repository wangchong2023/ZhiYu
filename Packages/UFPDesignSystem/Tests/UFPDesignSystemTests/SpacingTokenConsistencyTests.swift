//
//  SpacingTokenConsistencyTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Spacing Token 的跨引用一致性，防止重构时遗漏。
//

import XCTest
@testable import UFPDesignSystem

final class SpacingTokenConsistencyTests: XCTestCase {

    /// cardPadding 必须等于 medium（卡片标准内边距）
    func testCardPaddingEqualsMedium() {
        XCTAssertEqual(DesignTokens.Spacing.cardPadding, DesignTokens.Spacing.medium)
    }

    /// buttonPaddingHorizontal 必须等于 medium
    func testButtonPaddingHorizontalEqualsMedium() {
        XCTAssertEqual(DesignTokens.Spacing.buttonPaddingHorizontal, DesignTokens.Spacing.medium)
    }

    /// buttonPaddingVertical 必须等于 compact（小于水平，符合视觉比例）
    func testButtonPaddingVerticalEqualsCompact() {
        XCTAssertEqual(DesignTokens.Spacing.buttonPaddingVertical, DesignTokens.Spacing.compact)
    }

    /// 按钮垂直间距必须小于水平间距（视觉比例约束）
    func testButtonVerticalLessThanHorizontal() {
        XCTAssertLessThan(DesignTokens.Spacing.buttonPaddingVertical,
                          DesignTokens.Spacing.buttonPaddingHorizontal,
                          "按钮垂直间距必须小于水平间距，符合 HIG 视觉比例")
    }

    /// paddingSmall/Medium/Large 必须形成递增序列
    func testPaddingSmallMediumLargeIncreasing() {
        XCTAssertLessThan(DesignTokens.Spacing.paddingSmall, DesignTokens.Spacing.paddingMedium)
        XCTAssertLessThan(DesignTokens.Spacing.paddingMedium, DesignTokens.Spacing.paddingLarge)
    }

    /// small 必须等于 8.0（HIG 标准最小可触摸间距）
    func testSmallEquals8() {
        XCTAssertEqual(DesignTokens.Spacing.small, 8.0)
    }

    /// medium 必须等于 16.0（HIG 标准间距）
    func testMediumEquals16() {
        XCTAssertEqual(DesignTokens.Spacing.medium, 16.0)
    }
}
