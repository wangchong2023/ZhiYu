//
//  PDFHighlightTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 PDF 高亮标记的颜色名称到 SwiftUI Color 的语义化映射逻辑。
//

import XCTest
import SwiftUI
@testable import ZhiYu

final class PDFHighlightTests: XCTestCase {

    // MARK: - highlightColor 颜色映射

    func testHighlightColor_yellow返回Yellow() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "yellow")
        XCTAssertEqual(highlight.highlightColor, .yellow)
    }

    func testHighlightColor_green返回Green() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "green")
        XCTAssertEqual(highlight.highlightColor, .green)
    }

    func testHighlightColor_blue返回Blue() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "blue")
        XCTAssertEqual(highlight.highlightColor, .blue)
    }

    func testHighlightColor_pink返回Pink() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "pink")
        XCTAssertEqual(highlight.highlightColor, .pink)
    }

    func testHighlightColor_purple返回Purple() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "purple")
        XCTAssertEqual(highlight.highlightColor, .purple)
    }

    // MARK: - 默认值

    func testHighlightColor_未知颜色默认返回Yellow() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "orange")
        XCTAssertEqual(highlight.highlightColor, .yellow, "未知颜色应默认返回 yellow")
    }

    func testHighlightColor_空字符串默认返回Yellow() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "")
        XCTAssertEqual(highlight.highlightColor, .yellow)
    }

    // MARK: - 大小写敏感

    func testHighlightColor_大写Yellow返回默认() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "Yellow")
        XCTAssertEqual(highlight.highlightColor, .yellow, "大写 Y 应返回默认 yellow")
    }

    func testHighlightColor_全大写返回默认() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: "GREEN")
        XCTAssertEqual(highlight.highlightColor, .yellow, "全大写应返回默认 yellow")
    }

    // MARK: - 默认初始化

    func testInit_默认color为Yellow() {
        let highlight = PDFHighlight(pageIndex: 0, text: "测试")
        XCTAssertEqual(highlight.color, "yellow")
        XCTAssertEqual(highlight.highlightColor, .yellow)
    }

    // MARK: - 所有支持的颜色

    func testHighlightColor_所有支持颜色返回对应Color() {
        let colorMap: [String: Color] = [
            "yellow": .yellow,
            "green": .green,
            "blue": .blue,
            "pink": .pink,
            "purple": .purple
        ]
        for (name, expectedColor) in colorMap {
            let highlight = PDFHighlight(pageIndex: 0, text: "测试", color: name)
            XCTAssertEqual(highlight.highlightColor, expectedColor,
                          "颜色 \(name) 应映射到对应 Color")
        }
    }
}
