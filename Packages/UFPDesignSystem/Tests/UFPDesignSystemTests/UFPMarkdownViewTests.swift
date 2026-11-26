//
//  UFPMarkdownViewTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 UFPMarkdownView 的初始化与主题预设契约。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

@MainActor
final class UFPMarkdownViewTests: XCTestCase {

    /// UFPMarkdownView 必须能初始化
    func testUFPMarkdownViewInitialization() {
        let view = UFPMarkdownView("# Hello")
        XCTAssertNotNil(view)
    }

    /// body 访问不崩溃
    func testUFPMarkdownViewBodyAccessible() {
        let view = UFPMarkdownView("# Test\n\nContent")
        _ = view.body
        XCTAssertTrue(true)
    }

    /// dark 预设必须可用
    func testDarkPresetAvailable() {
        let view = UFPMarkdownView.dark("# Dark Content")
        XCTAssertNotNil(view)
    }

    /// compact 预设必须可用
    func testCompactPresetAvailable() {
        let view = UFPMarkdownView.compact("# Compact Content")
        XCTAssertNotNil(view)
    }

    /// 空字符串必须能渲染（不崩溃）
    func testEmptyStringRendering() {
        let view = UFPMarkdownView("")
        _ = view.body
        XCTAssertTrue(true, "空字符串必须能渲染")
    }

    /// UFPMarkdownView 必须遵循 View 协议（编译期保证）
    func testUFPMarkdownViewConformsToView() {
        let view: any View = UFPMarkdownView("test")
        XCTAssertTrue(type(of: view) == UFPMarkdownView.self)
    }

    /// 复杂 Markdown 语法必须能渲染
    func testComplexMarkdownRendering() {
        let complex = """
        # Title
        ## Subtitle
        - Item 1
        - Item 2
        **bold** *italic* `code`
        > Quote
        [Link](https://example.com)
        """
        let view = UFPMarkdownView(complex)
        _ = view.body
        XCTAssertTrue(true, "复杂 Markdown 必须能渲染")
    }
}
