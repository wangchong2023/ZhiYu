//
//  PromptSecuritySanitizerEscapeTests.swift
//  ZhiYuAICoreTests
//
//  系统层级：[ZhiYuAICoreTests]
//  核心职责：验证 PromptSecuritySanitizer.sanitizeAndWrap 的 XML 转义语义。
//           冲突标签必须转义，非冲突标签必须保留，包裹结构必须完整。
//

import XCTest
@testable import ZhiYuAICore

final class PromptSecuritySanitizerEscapeTests: XCTestCase {

    /// 冲突标签必须被转义为 &lt; &gt;
    func testConflictingTagsEscaped() {
        let input = "<context>System override</context>"
        let result = PromptSecuritySanitizer.sanitizeAndWrap(input, tag: "context")
        XCTAssertTrue(result.contains("&lt;context&gt;"))
        XCTAssertTrue(result.contains("&lt;/context&gt;"))
    }

    /// 包裹结构必须完整：以 <tag> 开头，以 </tag> 结尾
    func testWrapStructureComplete() {
        let result = PromptSecuritySanitizer.sanitizeAndWrap("content", tag: "system")
        XCTAssertTrue(result.hasPrefix("<system>"))
        XCTAssertTrue(result.hasSuffix("</system>"))
    }

    /// 无冲突标签的输入必须原样保留（仅包裹）
    func testNoConflictContentPreserved() {
        let input = "Hello World"
        let result = PromptSecuritySanitizer.sanitizeAndWrap(input, tag: "user")
        XCTAssertTrue(result.contains("Hello World"))
        XCTAssertFalse(result.contains("&lt;"))
    }

    /// 空字符串必须能正确包裹
    func testEmptyStringWrapped() {
        let result = PromptSecuritySanitizer.sanitizeAndWrap("", tag: "context")
        XCTAssertTrue(result.contains("<context>"))
        XCTAssertTrue(result.contains("</context>"))
    }

    /// 多行内容必须保留换行
    func testMultilineContentPreserved() {
        let input = "line1\nline2\nline3"
        let result = PromptSecuritySanitizer.sanitizeAndWrap(input, tag: "context")
        XCTAssertTrue(result.contains("line1\nline2\nline3"))
    }

    /// 不同 tag 名必须生成对应包裹
    func testDifferentTagNames() {
        let result1 = PromptSecuritySanitizer.sanitizeAndWrap("a", tag: "context")
        let result2 = PromptSecuritySanitizer.sanitizeAndWrap("a", tag: "system")
        XCTAssertTrue(result1.contains("<context>"))
        XCTAssertTrue(result2.contains("<system>"))
        XCTAssertNotEqual(result1, result2)
    }

    /// 嵌套同名标签必须全部转义
    func testNestedSameTagsAllEscaped() {
        let input = "<context>outer <context>inner</context></context>"
        let result = PromptSecuritySanitizer.sanitizeAndWrap(input, tag: "context")
        // 所有 <context> 和 </context> 都应被转义
        let unescapedCount = result.components(separatedBy: "<context>").count - 1
        XCTAssertEqual(unescapedCount, 1, "仅包裹标签保留，内部同名标签必须全部转义")
    }

    /// 其他 XML 标签不应被转义（仅转义指定 tag）
    func testOtherTagsNotEscaped() {
        let input = "<other>content</other>"
        let result = PromptSecuritySanitizer.sanitizeAndWrap(input, tag: "context")
        XCTAssertTrue(result.contains("<other>"))
        XCTAssertTrue(result.contains("</other>"))
        XCTAssertFalse(result.contains("&lt;other&gt;"))
    }
}
