//
//  SpacingTokenHierarchyTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 DesignSystem.Spacing 三层 Token 体系的语义不变量：
//           Tier 1 物理间距必须单调递增，Tier 2/3 语义 Token 必须引用 Tier 1（非硬编码）。
//

import XCTest
@testable import UFPDesignSystem

final class SpacingTokenHierarchyTests: XCTestCase {

    /// Tier 1 物理间距必须单调递增（nano < micro < tiny < small < compact < medium < large < extraLarge < huge）
    func testTier1PhysicalSpacingMonotonicallyIncreasing() {
        let scale = [
            DesignSystem.Spacing.nano,
            DesignSystem.Spacing.micro,
            DesignSystem.Spacing.tiny,
            DesignSystem.Spacing.small,
            DesignSystem.Spacing.compact,
            DesignSystem.Spacing.medium,
            DesignSystem.Spacing.large,
            DesignSystem.Spacing.extraLarge,
            DesignSystem.Spacing.huge
        ]
        for i in 1..<scale.count {
            XCTAssertGreaterThan(scale[i], scale[i-1],
                                 "Tier 1 间距必须单调递增：index \(i) 应大于 index \(i-1)")
        }
    }

    /// Tier 1 所有间距必须为正数
    func testTier1AllPositive() {
        XCTAssertGreaterThan(DesignSystem.Spacing.nano, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.micro, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.tiny, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.small, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.compact, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.medium, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.large, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.extraLarge, 0)
        XCTAssertGreaterThan(DesignSystem.Spacing.huge, 0)
    }

    /// Tier 2 语义 Token 必须等于对应 Tier 1 Token（非硬编码）
    func testTier2SemanticTokensReferenceTier1() {
        XCTAssertEqual(DesignSystem.Spacing.paddingSmall, DesignSystem.Spacing.small)
        XCTAssertEqual(DesignSystem.Spacing.paddingMedium, DesignSystem.Spacing.medium)
        XCTAssertEqual(DesignSystem.Spacing.paddingLarge, DesignSystem.Spacing.large)
    }

    /// Tier 3 组件 Token 必须引用 Tier 1（非硬编码）
    func testTier3ComponentTokensReferenceTier1() {
        XCTAssertEqual(DesignSystem.Spacing.cardPadding, DesignSystem.Spacing.medium)
        XCTAssertEqual(DesignSystem.Spacing.buttonPaddingHorizontal, DesignSystem.Spacing.medium)
        XCTAssertEqual(DesignSystem.Spacing.buttonPaddingVertical, DesignSystem.Spacing.compact)
    }

    /// nano 必须是最小间距（用于 1px 分隔线等场景）
    func testNanoIsMinimum() {
        let all = [DesignSystem.Spacing.nano, DesignSystem.Spacing.micro, DesignSystem.Spacing.tiny,
                   DesignSystem.Spacing.small, DesignSystem.Spacing.compact, DesignSystem.Spacing.medium,
                   DesignSystem.Spacing.large, DesignSystem.Spacing.extraLarge, DesignSystem.Spacing.huge]
        XCTAssertEqual(DesignSystem.Spacing.nano, all.min())
    }

    /// huge 必须是最大间距
    func testHugeIsMaximum() {
        let all = [DesignSystem.Spacing.nano, DesignSystem.Spacing.micro, DesignSystem.Spacing.tiny,
                   DesignSystem.Spacing.small, DesignSystem.Spacing.compact, DesignSystem.Spacing.medium,
                   DesignSystem.Spacing.large, DesignSystem.Spacing.extraLarge, DesignSystem.Spacing.huge]
        XCTAssertEqual(DesignSystem.Spacing.huge, all.max())
    }

    /// 间距值必须是整数（避免亚像素渲染问题）
    func testSpacingValuesAreIntegral() {
        let values = [DesignSystem.Spacing.nano, DesignSystem.Spacing.micro, DesignSystem.Spacing.tiny,
                      DesignSystem.Spacing.small, DesignSystem.Spacing.compact, DesignSystem.Spacing.medium,
                      DesignSystem.Spacing.large, DesignSystem.Spacing.extraLarge, DesignSystem.Spacing.huge]
        for v in values {
            XCTAssertEqual(v.truncatingRemainder(dividingBy: 1), 0,
                           "间距值 \(v) 必须是整数，避免亚像素渲染")
        }
    }

    /// 间距值必须在合理范围（0 < v <= 64）
    func testSpacingValuesInRange() {
        let values = [DesignSystem.Spacing.nano, DesignSystem.Spacing.micro, DesignSystem.Spacing.tiny,
                      DesignSystem.Spacing.small, DesignSystem.Spacing.compact, DesignSystem.Spacing.medium,
                      DesignSystem.Spacing.large, DesignSystem.Spacing.extraLarge, DesignSystem.Spacing.huge]
        for v in values {
            XCTAssertGreaterThan(v, 0)
            XCTAssertLessThanOrEqual(v, 64, "间距 \(v) 不应超过 64pt")
        }
    }
}
