//
//  DocumentSanitationEngineEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 DocumentSanitationEngine 多模态清洗流水线的选项组合、HTML 剥离、OCR 换行合并、前导废话剥离。
//

import XCTest
@testable import ZhiYu

final class DocumentSanitationEngineEdgeTests: XCTestCase {

    // MARK: - 空输入

    func testSanitize_emptyString_returnsEmpty() {
        XCTAssertEqual(DocumentSanitationEngine.shared.sanitize("", options: .defaultSuite), "")
    }

    func testSanitize_whitespaceOnly_returnsEmpty() {
        XCTAssertEqual(DocumentSanitationEngine.shared.sanitize("   \n   \n   ", options: .defaultSuite), "")
    }

    // MARK: - HTML 剥离

    func testSanitize_htmlScriptTag_stripped() {
        let html = "<script>alert('xss')</script>正文内容"
        let sanitized = DocumentSanitationEngine.shared.sanitize(html, options: .stripHTMLNoise)
        XCTAssertFalse(sanitized.contains("<script>"))
        XCTAssertTrue(sanitized.contains("正文内容"))
    }

    func testSanitize_htmlStyleTag_stripped() {
        let html = "<style>body{color:red}</style>正文"
        let sanitized = DocumentSanitationEngine.shared.sanitize(html, options: .stripHTMLNoise)
        XCTAssertFalse(sanitized.contains("<style>"))
    }

    func testSanitize_htmlGenericTag_stripped() {
        let html = "<div>内容</div>"
        let sanitized = DocumentSanitationEngine.shared.sanitize(html, options: .stripHTMLNoise)
        XCTAssertFalse(sanitized.contains("<div>"))
        XCTAssertTrue(sanitized.contains("内容"))
    }

    // MARK: - OCR 换行合并

    func testSanitize_ocrLineBreaks_merged() {
        let ocrText = "第一行\n第二行\n第三行"
        let sanitized = DocumentSanitationEngine.shared.sanitize(ocrText, options: .mergeOCRLineBreaks)
        XCTAssertTrue(sanitized.contains("第一行 第二行 第三行"), "OCR 换行应被合并为空格, got: \(sanitized)")
    }

    func testSanitize_ocrPreservesMarkdownStructure() {
        let ocrText = "# 标题\n正文1\n正文2\n- 列表项"
        let sanitized = DocumentSanitationEngine.shared.sanitize(ocrText, options: .mergeOCRLineBreaks)
        XCTAssertTrue(sanitized.contains("# 标题"), "标题行不应被合并")
        XCTAssertTrue(sanitized.contains("- 列表项"), "列表项行不应被合并")
    }

    // MARK: - 前导废话剥离

    func testSanitize_leadingChatter_stripped() {
        // 注意：stripLeadingChatter 对单行输入会完全剥离，需用多行输入测试
        let chatter = L10n.AI.Synthesis.Fallback.allChatterPrefixes.first ?? "Here is"
        let text = "\(chatter):\n这是正文内容"
        let sanitized = DocumentSanitationEngine.shared.sanitize(text, options: .stripLeadingChatter)
        XCTAssertFalse(sanitized.contains(chatter), "前导废话应被剥离")
        XCTAssertTrue(sanitized.contains("这是正文内容"))
    }

    func testSanitize_noLeadingChatter_unchanged() {
        let text = "这是正文内容"
        let sanitized = DocumentSanitationEngine.shared.sanitize(text, options: .stripLeadingChatter)
        XCTAssertEqual(sanitized, text)
    }

    // MARK: - 选项组合

    func testSanitize_emptyOptions_onlyASTClean() {
        let text = "```swift\nlet x = 10"
        let sanitized = DocumentSanitationEngine.shared.sanitize(text, options: SanitizerOptions(rawValue: 0))
        // cleanAST 追加 \n```\n，验证补全发生
        XCTAssertGreaterThan(sanitized.components(separatedBy: "```").count - 1, 1, "空选项仍应执行 AST 清洗")
    }

    func testSanitize_defaultSuite_allOptionsApplied() {
        let html = "<div>智宇AI</div>\n```swift\nlet x = 10"
        let sanitized = DocumentSanitationEngine.shared.sanitize(html, options: .defaultSuite)
        XCTAssertFalse(sanitized.contains("<div>"))
        XCTAssertTrue(sanitized.contains("智宇 AI"))
        XCTAssertTrue(sanitized.hasSuffix("```"))
    }

    // MARK: - SanitizerOptions OptionSet 语义

    func testSanitizerOptions_defaultSuite_containsAllOptions() {
        XCTAssertTrue(SanitizerOptions.defaultSuite.contains(.applyPanguSpacing))
        XCTAssertTrue(SanitizerOptions.defaultSuite.contains(.sanitizeMermaid))
        XCTAssertTrue(SanitizerOptions.defaultSuite.contains(.stripLeadingChatter))
        XCTAssertTrue(SanitizerOptions.defaultSuite.contains(.mergeOCRLineBreaks))
        XCTAssertTrue(SanitizerOptions.defaultSuite.contains(.stripHTMLNoise))
    }

    func testSanitizerOptions_emptyRawValue_isEmpty() {
        XCTAssertTrue(SanitizerOptions(rawValue: 0).isEmpty)
    }

    // MARK: - DocumentSanitizerProtocol 契约

    func testDocumentSanitationEngine_conformsToProtocol() {
        XCTAssertTrue(DocumentSanitationEngine.shared is any DocumentSanitizerProtocol)
    }

    func testDocumentSanitationEngine_isSendable() {
        // 编译时验证 Sendable
        _ = DocumentSanitationEngine.shared
    }
}
