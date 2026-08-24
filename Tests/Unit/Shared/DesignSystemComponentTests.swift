//
//  DesignSystemComponentTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 Component 层组件特定尺寸的正确性。
//

import XCTest
@testable import ZhiYu

final class DesignSystemComponentTests: XCTestCase {

    // MARK: - 大值
    func testLargeValues() {
        XCTAssertEqual(ComponentSpacing.section, 20)
        XCTAssertEqual(ComponentSpacing.sectionLarge, 24)
        XCTAssertEqual(ComponentSpacing.huge, 32)
        XCTAssertEqual(ComponentSpacing.ultra, 40)
        XCTAssertEqual(ComponentSpacing.massive, 48)
        XCTAssertEqual(ComponentSpacing.colossal, 64)
    }

    // MARK: - 组件特定尺寸
    func testComponentSpecificDimensions() {
        XCTAssertEqual(ComponentSpacing.buttonHeight, 44)
        XCTAssertEqual(ComponentSpacing.chartHeight, 220)
        XCTAssertEqual(ComponentSpacing.chartHeightCompact, 160)
        XCTAssertEqual(ComponentSpacing.chartHalfHeight, 110)
        XCTAssertEqual(ComponentSpacing.metricChipWidth, 80)
        XCTAssertEqual(ComponentSpacing.emptyStateImageHalf, 120)
    }

    // MARK: - 图标尺寸
    func testIconSizes() {
        XCTAssertEqual(ComponentSpacing.iconCompact, 18)
        XCTAssertEqual(ComponentSpacing.iconStandard, 22)
        XCTAssertEqual(ComponentSpacing.iconDisplay, 48)
    }
}
