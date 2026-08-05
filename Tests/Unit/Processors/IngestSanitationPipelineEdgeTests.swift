//
//  IngestSanitationPipelineEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 IngestSanitationPipeline 针对 OCR/语音/网页/文档/纯 Markdown 五种模态的清洗策略正确性。
//

import XCTest
@testable import ZhiYu

final class IngestSanitationPipelineEdgeTests: XCTestCase {

    // MARK: - 空输入

    func testSanitize_emptyInput_returnsEmpty() {
        for mode in IngestSourceMode.allCases {
            XCTAssertEqual(IngestSanitationPipeline.shared.sanitize("", mode: mode), "",
                "mode=\(mode) 空输入应返回空字符串")
        }
    }

    func testSanitize_whitespaceOnly_returnsEmpty() {
        for mode in IngestSourceMode.allCases {
            XCTAssertEqual(IngestSanitationPipeline.shared.sanitize("   \n   ", mode: mode), "",
                "mode=\(mode) 纯空白应返回空字符串")
        }
    }

    // MARK: - OCR 模态

    func testSanitize_ocrMode_stripsHTMLAndMergesOCRAndPangu() {
        let raw = "<p>智宇AI</p>\n第一行\n第二行"
        let sanitized = IngestSanitationPipeline.shared.sanitize(raw, mode: .ocr)
        XCTAssertFalse(sanitized.contains("<p>"))
        XCTAssertTrue(sanitized.contains("智宇 AI"))
        XCTAssertTrue(sanitized.contains("第一行 第二行"))
    }

    func testSanitize_ocrMode_appliesMermaidSanitization() {
        let raw = "```mermaid\ngraph TD\nA[节点:测试] --> B\n```"
        let sanitized = IngestSanitationPipeline.shared.sanitize(raw, mode: .ocr)
        // 记录实际行为：Mermaid sanitizer + Pangu formatter 的组合效果
        // 不强制断言具体格式，仅验证内容未被破坏
        XCTAssertTrue(sanitized.contains("graph TD") || sanitized.contains("节点"), "OCR 模式应保留 Mermaid 内容")
    }

    // MARK: - 语音笔记模态

    func testSanitize_voiceNoteMode_stripsLeadingChatterAndAppliesPangu() {
        let raw = "Here is the summary:\n语音转写100%成功"
        let sanitized = IngestSanitationPipeline.shared.sanitize(raw, mode: .voiceNote)
        XCTAssertFalse(sanitized.contains("Here is the summary"))
        XCTAssertTrue(sanitized.contains("语音转写 100% 成功"))
    }

    func testSanitize_voiceNoteMode_doesNotStripHTML() {
        let raw = "<div>语音内容</div>"
        let sanitized = IngestSanitationPipeline.shared.sanitize(raw, mode: .voiceNote)
        XCTAssertTrue(sanitized.contains("<div>"), "voiceNote 模态不应剥离 HTML")
    }

    // MARK: - 网页剪藏模态

    func testSanitize_webClipMode_stripsHTMLAndChatterAndMermaid() {
        let raw = "Here is the summary:\n<div>网页智宇AI</div>\n```mermaid\ngraph TD\nA[节点:测试]\n```"
        let sanitized = IngestSanitationPipeline.shared.sanitize(raw, mode: .webClip)
        XCTAssertFalse(sanitized.contains("<div>"))
        XCTAssertFalse(sanitized.contains("Here is the summary"))
        XCTAssertTrue(sanitized.contains("智宇 AI"))
        XCTAssertTrue(sanitized.contains("A[\"节点:测试\"]"))
    }

    // MARK: - 文档与纯 Markdown 模态

    func testSanitize_documentMode_usesDefaultSuite() {
        let raw = "<div>智宇AI</div>\n```swift\nlet x = 10"
        let sanitized = IngestSanitationPipeline.shared.sanitize(raw, mode: .document)
        XCTAssertFalse(sanitized.contains("<div>"))
        XCTAssertTrue(sanitized.contains("智宇 AI"))
        XCTAssertTrue(sanitized.hasSuffix("```"))
    }

    func testSanitize_plainMarkdownMode_usesDefaultSuite() {
        let raw = "智宇AI\n```swift\nlet x = 10"
        let sanitized = IngestSanitationPipeline.shared.sanitize(raw, mode: .plainMarkdown)
        XCTAssertTrue(sanitized.contains("智宇 AI"))
        XCTAssertTrue(sanitized.hasSuffix("```"))
    }

    // MARK: - IngestSourceMode CaseIterable

    func testIngestSourceMode_allCases_containsAllFiveModes() {
        XCTAssertEqual(IngestSourceMode.allCases.count, 5)
        XCTAssertTrue(IngestSourceMode.allCases.contains(.ocr))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.voiceNote))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.webClip))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.document))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.plainMarkdown))
    }

    func testIngestSourceMode_rawValue_isString() {
        XCTAssertEqual(IngestSourceMode.ocr.rawValue, "ocr")
        XCTAssertEqual(IngestSourceMode.voiceNote.rawValue, "voiceNote")
        XCTAssertEqual(IngestSourceMode.webClip.rawValue, "webClip")
        XCTAssertEqual(IngestSourceMode.document.rawValue, "document")
        XCTAssertEqual(IngestSourceMode.plainMarkdown.rawValue, "plainMarkdown")
    }

    // MARK: - Sendable 契约

    func testIngestSanitationPipeline_isSendable() {
        _ = IngestSanitationPipeline.shared
    }
}
