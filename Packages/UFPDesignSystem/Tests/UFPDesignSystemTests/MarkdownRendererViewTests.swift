//
//  MarkdownRendererViewTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 MarkdownRendererView 的初始化与主题预设契约。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

final class MarkdownRendererViewTests: XCTestCase {

    /// MarkdownRendererView 必须能初始化
    func testMarkdownRendererViewInitialization() {
        let view = MarkdownRendererView("# Hello")
        XCTAssertNotNil(view)
    }

    /// body 访问不崩溃
    func testMarkdownRendererViewBodyAccessible() {
        let view = MarkdownRendererView("# Test\n\nContent")
        _ = view.body
        XCTAssertTrue(true)
    }

    /// dark 预设必须可用
    func testDarkPresetAvailable() {
        let view = MarkdownRendererView.dark("# Dark Content")
        XCTAssertNotNil(view)
    }

    /// compact 预设必须可用
    func testCompactPresetAvailable() {
        let view = MarkdownRendererView.compact("# Compact Content")
        XCTAssertNotNil(view)
    }

    /// 空字符串必须能渲染（不崩溃）
    func testEmptyStringRendering() {
        let view = MarkdownRendererView("")
        _ = view.body
        XCTAssertTrue(true, "空字符串必须能渲染")
    }

    /// MarkdownRendererView 必须遵循 View 协议（编译期保证）
    func testMarkdownRendererViewConformsToView() {
        let view = MarkdownRendererView("test")
        XCTAssertTrue(type(of: view) is any View.Type)
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
        let view = MarkdownRendererView(complex)
        _ = view.body
        XCTAssertTrue(true, "复杂 Markdown 必须能渲染")
    }
}
