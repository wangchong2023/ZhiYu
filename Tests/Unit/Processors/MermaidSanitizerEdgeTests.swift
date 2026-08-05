//
//  MermaidSanitizerEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 MermaidSanitizer 状态机对节点文本转义、关键字保留、空行过滤的语义正确性。
//

import XCTest
@testable import ZhiYu

final class MermaidSanitizerEdgeTests: XCTestCase {

    // MARK: - 关键字与结构声明保留

    func testSanitize_graphKeyword_preserved() {
        let code = "graph TD\nA --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("graph TD"))
    }

    func testSanitize_flowchartKeyword_preserved() {
        let code = "flowchart LR\nA --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("flowchart LR"))
    }

    func testSanitize_mindmapKeyword_preserved() {
        let code = "mindmap\n  root((Root))"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("mindmap"))
    }

    func testSanitize_titleHash_preserved() {
        let code = "# 标题\ngraph TD\nA --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("# 标题"))
    }

    func testSanitize_codeFence_preserved() {
        let code = "```mermaid\ngraph TD\nA --> B\n```"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("```"))
    }

    // MARK: - 空行过滤

    func testSanitize_emptyLines_removed() {
        let code = "graph TD\n\n\nA --> B\n\n"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertFalse(sanitized.contains("\n\n\n"))
    }

    func testSanitize_whitespaceOnlyLines_removed() {
        let code = "graph TD\n   \n  \nA --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertFalse(sanitized.contains("   \n"))
    }

    // MARK: - 节点文本转义

    func testSanitize_nodeWithColon_autoQuoted() {
        let code = "graph TD\nA[节点:测试] --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("A[\"节点:测试\"]"), "含冒号的节点文本应被双引号包裹, got: \(sanitized)")
    }

    func testSanitize_nodeWithParentheses_autoQuoted() {
        let code = "graph TD\nA[函数(参数)] --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("A[\"函数(参数)\"]"), "含括号的节点文本应被双引号包裹, got: \(sanitized)")
    }

    func testSanitize_nodeWithBrackets_autoQuoted_bug11Fixed() {
        // 缺陷 #11 已修复：正则改为 [^"]+ 允许 ] 字符，含嵌套方括号的标签可被正确匹配
        let code = "graph TD\nA[数组[0]] --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("A[\"数组[0]\"]"),
            "缺陷 #11 已修复：含嵌套方括号的标签应被自动加引号")
    }

    func testSanitize_plainNodeText_notQuoted() {
        let code = "graph TD\nA[普通文本] --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("A[普通文本]"))
        XCTAssertFalse(sanitized.contains("A[\"普通文本\"]"), "无特殊字符的节点不应被加引号")
    }

    // MARK: - 多节点行

    func testSanitize_multipleNodesInLine_allEscaped() {
        let code = "graph TD\nA[节点1:测试] --> B[节点2:验证]"
        let sanitized = MermaidSanitizer.sanitize(code)
        XCTAssertTrue(sanitized.contains("A[\"节点1:测试\"]"))
        XCTAssertTrue(sanitized.contains("B[\"节点2:验证\"]"))
    }

    // MARK: - 边界输入

    func testSanitize_emptyString_returnsEmpty() {
        XCTAssertEqual(MermaidSanitizer.sanitize(""), "")
    }

    func testSanitize_onlyNewlines_returnsEmpty() {
        XCTAssertEqual(MermaidSanitizer.sanitize("\n\n\n"), "")
    }

    func testSanitize_onlyWhitespace_returnsEmpty() {
        XCTAssertEqual(MermaidSanitizer.sanitize("   \n   \n   "), "")
    }

    // MARK: - 已带引号节点不重复转义

    func testSanitize_alreadyQuotedNode_notDoubleQuoted() {
        let code = "graph TD\nA[\"已带引号:文本\"] --> B"
        let sanitized = MermaidSanitizer.sanitize(code)
        // 正则 [^"\]]+ 排除已带引号的节点，应保持原样
        XCTAssertTrue(sanitized.contains("A[\"已带引号:文本\"]"))
    }
}
