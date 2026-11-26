//
//  MermaidCrossPlatformRenderingTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：TC-LEGACY-02 跨平台 Mermaid 渲染 HTML 生成与字符转义安全性验证。
//

import XCTest
@testable import ZhiYuUnitTestHost

final class MermaidCrossPlatformRenderingTests: XCTestCase {

    private enum TestData {
        static let simpleGraph = "graph TD\n  A[开始] --> B[结束]"
        static let codeWithSpecialChars = "graph TD\n  A[`var x = $100`] --> B[特殊符号 \\ 反斜杠]"
        static let iosTheme = "neutral"
        static let macTheme = "dark"
        static let macBodyExtra = " overflow: auto;"
        static let macBulletPrefix = "• "
    }

    /// 验证 iOS 平台模板生成：包含 viewport meta 标签，使用 neutral 主题
    func testGenerateMermaidHTML_ForIOS_IncludesViewportAndNeutralTheme() {
        let html = generateMermaidHTML(
            mermaidCode: TestData.simpleGraph,
            theme: TestData.iosTheme,
            viewportMeta: true
        )

        XCTAssertTrue(html.contains("name=\"viewport\""), "iOS 平台应包含 viewport meta 标签")
        XCTAssertTrue(html.contains("theme: 'neutral'"), "iOS 平台应配置 neutral 主题")
        XCTAssertTrue(html.contains("mermaid.min.js"), "应包含 mermaid.min.js 引用")
        XCTAssertTrue(html.contains("A[开始]"), "应包含节点代码")
    }

    /// 验证 macOS 平台模板生成：无 viewport meta，使用 dark 主题与自定义 body 样式
    func testGenerateMermaidHTML_ForMacOS_IncludesDarkThemeAndExtraStyle() {
        let html = generateMermaidHTML(
            mermaidCode: TestData.simpleGraph,
            theme: TestData.macTheme,
            viewportMeta: false,
            bodyExtraStyle: TestData.macBodyExtra,
            fallbackBulletPrefix: TestData.macBulletPrefix
        )

        XCTAssertFalse(html.contains("name=\"viewport\""), "macOS 平台无需移动端 viewport meta")
        XCTAssertTrue(html.contains("theme: 'dark'"), "macOS 平台应配置 dark 主题")
        XCTAssertTrue(html.contains(TestData.macBodyExtra), "应包含额外追加的 body 样式")
    }

    /// 验证特殊字符安全转义（反斜杠、反引号、美元符号、换行符）
    func testGenerateMermaidHTML_EscapesSpecialCharactersSafely() {
        let html = generateMermaidHTML(
            mermaidCode: TestData.codeWithSpecialChars,
            theme: TestData.macTheme
        )

        // 反斜杠应被双重转义，反引号应被转义
        XCTAssertTrue(html.contains("\\`var x = \\$100\\`"), "反引号与美元符号应被安全转义")
        XCTAssertTrue(html.contains("\\\\ 反斜杠"), "反斜杠应被转义为双反斜杠")
        XCTAssertFalse(html.contains("\r"), "回车符应被彻底消除")
    }
}
