//
//  SpacingTokenConsistencyTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Spacing Token 的跨引用一致性，防止重构时遗漏。
//           以 app 版本（medium=12）为准，已删除 SPM 包独有 Tier 2/3 Token 测试。
//

import XCTest
@testable import UFPDesignSystem

final class SpacingTokenConsistencyTests: XCTestCase {

    /// small 必须等于 8.0（HIG 标准最小可触摸间距）
    func testSmallEquals8() {
        XCTAssertEqual(DesignTokens.Spacing.small, 8.0)
    }

    /// medium 必须等于 12.0（app 标准间距）
    func testMediumEquals12() {
        XCTAssertEqual(DesignTokens.Spacing.medium, 12.0)
    }

    /// standardPadding 必须等于 16.0（标准页面内边距）
    func testStandardPaddingEquals16() {
        XCTAssertEqual(DesignTokens.Spacing.standardPadding, 16.0)
    }

    /// atomic < tiny < small < medium < standardPadding < large < wide < giant < huge 递增
    /// 注意：large 与 standardPadding 均为 16，故仅断言 standardPadding < wide
    func testSpacingIncreasing() {
        XCTAssertLessThan(DesignTokens.Spacing.atomic, DesignTokens.Spacing.tiny)
        XCTAssertLessThan(DesignTokens.Spacing.tiny, DesignTokens.Spacing.small)
        XCTAssertLessThan(DesignTokens.Spacing.small, DesignTokens.Spacing.medium)
        XCTAssertLessThan(DesignTokens.Spacing.medium, DesignTokens.Spacing.standardPadding)
        XCTAssertLessThan(DesignTokens.Spacing.standardPadding, DesignTokens.Spacing.wide)
        XCTAssertLessThan(DesignTokens.Spacing.wide, DesignTokens.Spacing.giant)
        XCTAssertLessThan(DesignTokens.Spacing.giant, DesignTokens.Spacing.huge)
    }
}
