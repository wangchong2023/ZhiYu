//
//  HexSpiralCalculatorBoundaryTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：HexSpiralCalculator 六角网格螺旋排布数学边界、中心点生成、去重与坐标映射测试
//

import XCTest
import CoreGraphics
import UFPCore
@testable import ZhiYu

final class HexSpiralCalculatorBoundaryTests: XCTestCase {

    // MARK: - 1. 边界数量生成测试 (0 与负数保护)

    func testGenerateSpiralCoordinatesZeroAndNegativeReturnsEmpty() {
        let zeroResult = HexSpiralCalculator.generateSpiralCoordinates(count: 0)
        XCTAssertTrue(zeroResult.isEmpty, "count <= 0 时应返回空坐标数组")

        let negativeResult = HexSpiralCalculator.generateSpiralCoordinates(count: -10)
        XCTAssertTrue(negativeResult.isEmpty, "负数 count 应返回空坐标数组")
    }

    // MARK: - 2. 单点原点生成测试

    func testGenerateSpiralCoordinatesCountOneReturnsOrigin() {
        let singleResult = HexSpiralCalculator.generateSpiralCoordinates(count: 1)
        XCTAssertEqual(singleResult.count, 1)
        XCTAssertEqual(singleResult[0].axialQ, 0)
        XCTAssertEqual(singleResult[0].axialR, 0)
    }

    // MARK: - 3. 多环绕圈坐标互斥无重叠 (Uniqueness) 变异测试

    func testGenerateSpiralCoordinatesUniquenessNoOverlappingCoordinates() {
        let count = 50
        let coords = HexSpiralCalculator.generateSpiralCoordinates(count: count)
        XCTAssertEqual(coords.count, count)

        // 验证没有两点坐标相同
        let uniqueSet = Set(coords)
        XCTAssertEqual(uniqueSet.count, count, "螺旋展开的轴向坐标序列中任意两点不能发生坐标重叠碰撞")
    }

    // MARK: - 4. 物理平面点映射测试

    func testConvertToPhysicalPointCalculations() {
        let origin = HexCoordinate(axialQ: 0, axialR: 0)
        let originPoint = HexSpiralCalculator.convertToPhysicalPoint(coord: origin, stepSize: 40.0)
        XCTAssertEqual(originPoint.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(originPoint.y, 0.0, accuracy: 0.001)

        let eastCoord = HexCoordinate(axialQ: 1, axialR: 0)
        let eastPoint = HexSpiralCalculator.convertToPhysicalPoint(coord: eastCoord, stepSize: 50.0)
        XCTAssertGreaterThan(eastPoint.x, 0.0)
        XCTAssertEqual(eastPoint.y, 0.0, accuracy: 0.001)
    }
}
