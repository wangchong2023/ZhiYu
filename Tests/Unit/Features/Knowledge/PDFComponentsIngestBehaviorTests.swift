//
//  PDFComponentsIngestBehaviorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 PDFComponents、PDFPageRangeCalculator 页码安全计算与 PDFDocumentRow 渲染行为。
//

#if !os(watchOS)
import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class PDFComponentsIngestBehaviorTests: XCTestCase {

    // MARK: - 1. PDFPageRangeCalculator 页码安全计算测试

    func testCalculateSafeRange_NormalRange_ReturnsExpectedRange() {
        let range = PDFPageRangeCalculator.calculateSafeRange(pageStart: 1, pageEnd: 5, pageCount: 10)
        XCTAssertEqual(range, 0..<5)
    }

    func testCalculateSafeRange_SinglePage_ReturnsSinglePageRange() {
        // 用户指定提取第 3 页 (从 3 到 3)
        let range = PDFPageRangeCalculator.calculateSafeRange(pageStart: 3, pageEnd: 3, pageCount: 10)
        XCTAssertEqual(range, 2..<3)
    }

    func testCalculateSafeRange_InvertedRange_ReturnsNilToPreventCrash() {
        // 用户输入倒置页码（起始页 > 终止页）
        let range = PDFPageRangeCalculator.calculateSafeRange(pageStart: 6, pageEnd: 3, pageCount: 10)
        XCTAssertNil(range, "当起始页大于终止页时必须返回 nil，杜绝 Swift Range lowerBound > upperBound 致命闪退")
    }

    func testCalculateSafeRange_ZeroOrNegativeStart_ClampsToZero() {
        let zeroStart = PDFPageRangeCalculator.calculateSafeRange(pageStart: 0, pageEnd: 5, pageCount: 10)
        XCTAssertEqual(zeroStart, 0..<5)

        let negativeStart = PDFPageRangeCalculator.calculateSafeRange(pageStart: -3, pageEnd: 4, pageCount: 10)
        XCTAssertEqual(negativeStart, 0..<4)
    }

    func testCalculateSafeRange_ZeroOrNegativeEnd_ReturnsNil() {
        let zeroEnd = PDFPageRangeCalculator.calculateSafeRange(pageStart: 1, pageEnd: 0, pageCount: 10)
        XCTAssertNil(zeroEnd)

        let negativeEnd = PDFPageRangeCalculator.calculateSafeRange(pageStart: 1, pageEnd: -5, pageCount: 10)
        XCTAssertNil(negativeEnd)
    }

    func testCalculateSafeRange_ZeroOrNegativePageCount_ReturnsNil() {
        XCTAssertNil(PDFPageRangeCalculator.calculateSafeRange(pageStart: 1, pageEnd: 5, pageCount: 0))
        XCTAssertNil(PDFPageRangeCalculator.calculateSafeRange(pageStart: 1, pageEnd: 5, pageCount: -1))
    }

    func testCalculateSafeRange_EndExceedsTotalPages_ClampsToTotalPages() {
        let clampedRange = PDFPageRangeCalculator.calculateSafeRange(pageStart: 2, pageEnd: 100, pageCount: 15)
        XCTAssertEqual(clampedRange, 1..<15)
    }

    func testCalculateSafeRange_FuzzPseudoRandomInputs_NeverProducesInvalidRange() {
        // 100 次 Fuzz 混沌极值注入，检验绝对无崩溃发生且返回的 Range 必然满足 lowerBound < upperBound
        let testStarts = [-100, -1, 0, 1, 2, 5, 10, 50, 100, 999]
        let testEnds = [-50, 0, 1, 3, 5, 10, 20, 100, 1000]
        let testCounts = [-5, 0, 1, 5, 10, 50, 100]

        for testStart in testStarts {
            for testEnd in testEnds {
                for testCount in testCounts {
                    if let safeRange = PDFPageRangeCalculator.calculateSafeRange(pageStart: testStart, pageEnd: testEnd, pageCount: testCount) {
                        XCTAssertLessThan(safeRange.lowerBound, safeRange.upperBound, "计算出的 Range 必须严格满足下界小于上界")
                        XCTAssertGreaterThanOrEqual(safeRange.lowerBound, 0, "下界必须大于等于 0")
                        XCTAssertLessThanOrEqual(safeRange.upperBound, max(0, testCount), "上界不能超过总页数")
                    }
                }
            }
        }
    }

    // MARK: - 2. Color.pdfHighlight 高亮色彩映射测试

    func testPdfHighlight_PresetColors_MapsCorrectThemes() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let resolvedYellow = UIColor(Color.pdfHighlight("yellow")).resolvedColor(with: lightTraits)
        let expectedYellow = UIColor(Color.theme.yellow).resolvedColor(with: lightTraits)
        XCTAssertEqual(resolvedYellow, expectedYellow)

        let resolvedGreen = UIColor(Color.pdfHighlight("green")).resolvedColor(with: lightTraits)
        let expectedGreen = UIColor(Color.theme.green).resolvedColor(with: lightTraits)
        XCTAssertEqual(resolvedGreen, expectedGreen)

        let resolvedBlue = UIColor(Color.pdfHighlight("blue")).resolvedColor(with: lightTraits)
        let expectedBlue = UIColor(Color.theme.blue).resolvedColor(with: lightTraits)
        XCTAssertEqual(resolvedBlue, expectedBlue)

        let resolvedUnknown = UIColor(Color.pdfHighlight("unknown_custom_color")).resolvedColor(with: lightTraits)
        XCTAssertEqual(resolvedUnknown, expectedYellow, "未预设高亮色应优雅保底为黄色")
    }

    // MARK: - 3. PDFDocumentRow 视图组件渲染测试

    func testPDFDocumentRow_InitializationAndRender_DoesNotCrash() {
        let highlight = PDFHighlight(
            id: UUID(),
            pageIndex: 1,
            text: "检索增强生成技术的核心是在本地完成语义召回",
            color: "green",
            note: "关键架构点"
        )
        let docInfo = PDFDocumentInfo(
            title: "端侧 RAG 架构指南",
            fileName: "sample.pdf",
            pageCount: 18,
            addedDate: Date(),
            highlights: [highlight]
        )

        let row = PDFDocumentRow(doc: docInfo)
        let hostingController = UIHostingController(rootView: row)
        XCTAssertNotNil(hostingController.view, "PDFDocumentRow 必须能够成功完成 UIHosting 渲染")
    }
}
#endif
