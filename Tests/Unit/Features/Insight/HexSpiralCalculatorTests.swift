//
//  HexSpiralCalculatorTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证六角蜂窝螺旋排布算法的坐标生成、物理坐标转换、边界条件等语义。
//

import XCTest
import CoreGraphics
@testable import ZhiYu

final class HexSpiralCalculatorTests: XCTestCase {

    // MARK: - generateSpiralCoordinates 边界

    func testGenerateSpiralCoordinates_zeroCount_returnsEmpty() {
        let result = HexSpiralCalculator.generateSpiralCoordinates(count: 0)
        XCTAssertTrue(result.isEmpty)
    }

    func testGenerateSpiralCoordinates_negativeCount_returnsEmpty() {
        let result = HexSpiralCalculator.generateSpiralCoordinates(count: -5)
        XCTAssertTrue(result.isEmpty)
    }

    func testGenerateSpiralCoordinates_countOne_returnsOrigin() {
        let result = HexSpiralCalculator.generateSpiralCoordinates(count: 1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], HexCoordinate(axialQ: 0, axialR: 0))
    }

    // MARK: - generateSpiralCoordinates 数量

    func testGenerateSpiralCoordinates_countSeven_returnsSevenCoords() {
        let result = HexSpiralCalculator.generateSpiralCoordinates(count: 7)
        XCTAssertEqual(result.count, 7, "7 个坐标 = 中心 + 第一圈 6 个")
    }

    func testGenerateSpiralCoordinates_countNineteen_returnsNineteenCoords() {
        let result = HexSpiralCalculator.generateSpiralCoordinates(count: 19)
        XCTAssertEqual(result.count, 19, "19 个坐标 = 中心 + 第一圈 6 + 第二圈 12")
    }

    func testGenerateSpiralCoordinates_exactRingBoundary() {
        // 第一圈 7 个（含中心），第二圈 19 个（含中心+第一圈+第二圈）
        let result7 = HexSpiralCalculator.generateSpiralCoordinates(count: 7)
        XCTAssertEqual(result7.count, 7)

        let result19 = HexSpiralCalculator.generateSpiralCoordinates(count: 19)
        XCTAssertEqual(result19.count, 19)
    }

    // MARK: - generateSpiralCoordinates 去重

    func testGenerateSpiralCoordinates_allCoordsUnique() {
        let result = HexSpiralCalculator.generateSpiralCoordinates(count: 37)
        let uniqueCoords = Set(result)
        XCTAssertEqual(result.count, uniqueCoords.count, "所有坐标应唯一")
    }

    func testGenerateSpiralCoordinates_firstCoordIsOrigin() {
        let result = HexSpiralCalculator.generateSpiralCoordinates(count: 10)
        XCTAssertEqual(result[0], HexCoordinate(axialQ: 0, axialR: 0), "第一个坐标应为原点")
    }

    // MARK: - convertToPhysicalPoint

    func testConvertToPhysicalPoint_origin_returnsZero() {
        let coord = HexCoordinate(axialQ: 0, axialR: 0)
        let point = HexSpiralCalculator.convertToPhysicalPoint(coord: coord, stepSize: 50)
        XCTAssertEqual(point, CGPoint(x: 0, y: 0))
    }

    func testConvertToPhysicalPoint_qAxis_onlyQContributes() {
        let coord = HexCoordinate(axialQ: 1, axialR: 0)
        let stepSize: CGFloat = 10
        let point = HexSpiralCalculator.convertToPhysicalPoint(coord: coord, stepSize: stepSize)
        let expectedX = stepSize * CGFloat(sqrt(3.0))
        XCTAssertEqual(point.x, expectedX, accuracy: 0.001)
        XCTAssertEqual(point.y, 0, accuracy: 0.001)
    }

    func testConvertToPhysicalPoint_rAxis_bothContribute() {
        let coord = HexCoordinate(axialQ: 0, axialR: 1)
        let stepSize: CGFloat = 10
        let point = HexSpiralCalculator.convertToPhysicalPoint(coord: coord, stepSize: stepSize)
        let expectedX = stepSize * (sqrt(3.0) / 2.0)
        let expectedY = stepSize * 1.5
        XCTAssertEqual(point.x, expectedX, accuracy: 0.001)
        XCTAssertEqual(point.y, expectedY, accuracy: 0.001)
    }

    func testConvertToPhysicalPoint_stepSizeScales() {
        let coord = HexCoordinate(axialQ: 2, axialR: 3)
        let point1 = HexSpiralCalculator.convertToPhysicalPoint(coord: coord, stepSize: 10)
        let point2 = HexSpiralCalculator.convertToPhysicalPoint(coord: coord, stepSize: 20)
        XCTAssertEqual(point2.x, point1.x * 2, accuracy: 0.001, "步长翻倍 x 应翻倍")
        XCTAssertEqual(point2.y, point1.y * 2, accuracy: 0.001, "步长翻倍 y 应翻倍")
    }

    // MARK: - HexCoordinate Hashable

    func testHexCoordinate_hashableAndEquatable() {
        let c1 = HexCoordinate(axialQ: 1, axialR: -1)
        let c2 = HexCoordinate(axialQ: 1, axialR: -1)
        XCTAssertEqual(c1, c2)
        XCTAssertEqual(c1.hashValue, c2.hashValue)
    }

    func testHexCoordinate_differentValues_notEqual() {
        let c1 = HexCoordinate(axialQ: 1, axialR: 0)
        let c2 = HexCoordinate(axialQ: 0, axialR: 1)
        XCTAssertNotEqual(c1, c2)
    }
}
