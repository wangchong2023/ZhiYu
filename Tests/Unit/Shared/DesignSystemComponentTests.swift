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

    // MARK: - 组件语义映射
    func testComponentSemanticMapping() {
        XCTAssertEqual(ComponentSpacing.cardPadding, SystemSpacing.content)
        XCTAssertEqual(ComponentSpacing.listRowGap, SystemSpacing.element)
        XCTAssertEqual(ComponentSpacing.iconTextGap, SystemSpacing.small)
        XCTAssertEqual(ComponentSpacing.buttonInternalPadding, SystemSpacing.medium)
        XCTAssertEqual(ComponentSpacing.chipPadding, SystemSpacing.tiny)
    }

    // MARK: - 组件特定尺寸
    func testComponentSpecificDimensions() {
        XCTAssertEqual(ComponentSpacing.toolbarHeight, 44)
        XCTAssertEqual(ComponentSpacing.buttonHeight, 44)
        XCTAssertEqual(ComponentSpacing.compactButtonHeight, 32)
        XCTAssertEqual(ComponentSpacing.inputFieldHeight, 50)
        XCTAssertEqual(ComponentSpacing.minTouchTarget, 44)
        XCTAssertEqual(ComponentSpacing.capsuleHeight, 28)
        XCTAssertEqual(ComponentSpacing.inputBarHeight, 54)
    }

    // MARK: - 图标尺寸
    func testIconSizes() {
        XCTAssertEqual(ComponentSpacing.iconCompact, 18)
        XCTAssertEqual(ComponentSpacing.iconStandard, 22)
        XCTAssertEqual(ComponentSpacing.iconLarge, 24)
        XCTAssertEqual(ComponentSpacing.iconDisplay, 48)
        XCTAssertEqual(ComponentSpacing.iconHuge, 64)
    }
}
