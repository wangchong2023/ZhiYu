//
//  DesignSystemComponentTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 Component 层组件特定尺寸的正确性。
//

import UFPDesignSystem
import XCTest
@testable import ZhiYu

final class DesignSystemComponentTests: XCTestCase {

    // MARK: - 大值
    func testLargeValues() {
        XCTAssertEqual(DesignTokens.ComponentSpacing.section, 20)
        XCTAssertEqual(DesignTokens.ComponentSpacing.sectionLarge, 24)
        XCTAssertEqual(DesignTokens.ComponentSpacing.huge, 32)
        XCTAssertEqual(DesignTokens.ComponentSpacing.ultra, 40)
        XCTAssertEqual(DesignTokens.ComponentSpacing.massive, 48)
        XCTAssertEqual(DesignTokens.ComponentSpacing.colossal, 64)
    }

    // MARK: - 组件特定尺寸
    func testComponentSpecificDimensions() {
        XCTAssertEqual(DesignTokens.ComponentSpacing.buttonHeight, 44)
        XCTAssertEqual(DesignTokens.ComponentSpacing.chartHeight, 220)
        XCTAssertEqual(DesignTokens.ComponentSpacing.chartHeightCompact, 160)
        XCTAssertEqual(DesignTokens.ComponentSpacing.chartHalfHeight, 110)
        XCTAssertEqual(DesignTokens.ComponentSpacing.metricChipWidth, 80)
        XCTAssertEqual(DesignTokens.ComponentSpacing.emptyStateImageHalf, 120)
    }

    // MARK: - 图标尺寸
    func testIconSizes() {
        XCTAssertEqual(DesignTokens.ComponentSpacing.iconCompact, 18)
        XCTAssertEqual(DesignTokens.ComponentSpacing.iconStandard, 22)
        XCTAssertEqual(DesignTokens.ComponentSpacing.iconDisplay, 48)
    }
}
