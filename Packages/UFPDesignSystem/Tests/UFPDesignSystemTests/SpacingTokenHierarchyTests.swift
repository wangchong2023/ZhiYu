//
//  SpacingTokenHierarchyTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 DesignTokens.Spacing 三层 Token 体系的语义不变量：
//           Tier 1 物理间距必须单调递增，Tier 2/3 语义 Token 必须引用 Tier 1（非硬编码）。
//

import XCTest
@testable import UFPDesignSystem

final class SpacingTokenHierarchyTests: XCTestCase {

    /// Tier 1 物理间距必须单调递增（nano < micro < tiny < small < compact < medium < large < extraLarge < huge）
    func testTier1PhysicalSpacingMonotonicallyIncreasing() {
        let scale = [
            DesignTokens.Spacing.nano,
            DesignTokens.Spacing.micro,
            DesignTokens.Spacing.tiny,
            DesignTokens.Spacing.small,
            DesignTokens.Spacing.compact,
            DesignTokens.Spacing.medium,
            DesignTokens.Spacing.large,
            DesignTokens.Spacing.extraLarge,
            DesignTokens.Spacing.huge
        ]
        for i in 1..<scale.count {
            XCTAssertGreaterThan(scale[i], scale[i-1],
                                 "Tier 1 间距必须单调递增：index \(i) 应大于 index \(i-1)")
        }
    }

    /// Tier 1 所有间距必须为正数
    func testTier1AllPositive() {
        XCTAssertGreaterThan(DesignTokens.Spacing.nano, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.micro, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.tiny, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.small, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.compact, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.medium, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.large, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.extraLarge, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.huge, 0)
    }

    /// Tier 2 语义 Token 必须等于对应 Tier 1 Token（非硬编码）
    func testTier2SemanticTokensReferenceTier1() {
        XCTAssertEqual(DesignTokens.Spacing.paddingSmall, DesignTokens.Spacing.small)
        XCTAssertEqual(DesignTokens.Spacing.paddingMedium, DesignTokens.Spacing.medium)
        XCTAssertEqual(DesignTokens.Spacing.paddingLarge, DesignTokens.Spacing.large)
    }

    /// Tier 3 组件 Token 必须引用 Tier 1（非硬编码）
    func testTier3ComponentTokensReferenceTier1() {
        XCTAssertEqual(DesignTokens.Spacing.cardPadding, DesignTokens.Spacing.medium)
        XCTAssertEqual(DesignTokens.Spacing.buttonPaddingHorizontal, DesignTokens.Spacing.medium)
        XCTAssertEqual(DesignTokens.Spacing.buttonPaddingVertical, DesignTokens.Spacing.compact)
    }

    /// nano 必须是最小间距（用于 1px 分隔线等场景）
    func testNanoIsMinimum() {
        let all = [DesignTokens.Spacing.nano, DesignTokens.Spacing.micro, DesignTokens.Spacing.tiny,
                   DesignTokens.Spacing.small, DesignTokens.Spacing.compact, DesignTokens.Spacing.medium,
                   DesignTokens.Spacing.large, DesignTokens.Spacing.extraLarge, DesignTokens.Spacing.huge]
        XCTAssertEqual(DesignTokens.Spacing.nano, all.min())
    }

    /// huge 必须是最大间距
    func testHugeIsMaximum() {
        let all = [DesignTokens.Spacing.nano, DesignTokens.Spacing.micro, DesignTokens.Spacing.tiny,
                   DesignTokens.Spacing.small, DesignTokens.Spacing.compact, DesignTokens.Spacing.medium,
                   DesignTokens.Spacing.large, DesignTokens.Spacing.extraLarge, DesignTokens.Spacing.huge]
        XCTAssertEqual(DesignTokens.Spacing.huge, all.max())
    }

    /// 间距值必须是整数（避免亚像素渲染问题）
    func testSpacingValuesAreIntegral() {
        let values = [DesignTokens.Spacing.nano, DesignTokens.Spacing.micro, DesignTokens.Spacing.tiny,
                      DesignTokens.Spacing.small, DesignTokens.Spacing.compact, DesignTokens.Spacing.medium,
                      DesignTokens.Spacing.large, DesignTokens.Spacing.extraLarge, DesignTokens.Spacing.huge]
        for v in values {
            XCTAssertEqual(v.truncatingRemainder(dividingBy: 1), 0,
                           "间距值 \(v) 必须是整数，避免亚像素渲染")
        }
    }

    /// 间距值必须在合理范围（0 < v <= 64）
    func testSpacingValuesInRange() {
        let values = [DesignTokens.Spacing.nano, DesignTokens.Spacing.micro, DesignTokens.Spacing.tiny,
                      DesignTokens.Spacing.small, DesignTokens.Spacing.compact, DesignTokens.Spacing.medium,
                      DesignTokens.Spacing.large, DesignTokens.Spacing.extraLarge, DesignTokens.Spacing.huge]
        for v in values {
            XCTAssertGreaterThan(v, 0)
            XCTAssertLessThanOrEqual(v, 64, "间距 \(v) 不应超过 64pt")
        }
    }
}
