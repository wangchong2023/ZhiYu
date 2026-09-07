//
//  SynthesisProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 SynthesisProcessor 的 Mermaid 格式化、Markdown 清洗、标题提取、演示文稿/报告/测验兜底生成语义。
//

import XCTest
@testable import ZhiYu

final class SynthesisProcessorEdgeTests: XCTestCase {

    // MARK: - sanitizeSourceLines

    func testSanitizeSourceLines_filtersPromptKeywords() {
        let text = "Source: 内容\n---\nFormat: markdown\nRequirements: 需求\n正文"
        let lines = SynthesisProcessor.sanitizeSourceLines(text)
        XCTAssertFalse(lines.contains { $0.contains("Source") })
        XCTAssertFalse(lines.contains { $0.contains("---") })
        XCTAssertFalse(lines.contains { $0.contains("Format:") })
        XCTAssertFalse(lines.contains { $0.contains("Requirements:") })
        XCTAssertTrue(lines.contains("正文"))
    }

    func testSanitizeSourceLines_filtersCodeFences() {
        let text = "```\ncode\n```\n正文"
        let lines = SynthesisProcessor.sanitizeSourceLines(text)
        XCTAssertFalse(lines.contains { $0.hasPrefix("```") })
        XCTAssertTrue(lines.contains("正文"))
    }

    func testSanitizeSourceLines_emptyLines_filtered() {
        let lines = SynthesisProcessor.sanitizeSourceLines("正文\n\n\n内容")
        XCTAssertFalse(lines.contains(""))
    }

    // MARK: - isValidMermaidSyntax

    func testIsValidMermaidSyntax_validGraph_returnsTrue() {
        XCTAssertTrue(SynthesisProcessor.isValidMermaidSyntax("graph TD\nA --> B"))
    }

    func testIsValidMermaidSyntax_validMindmap_returnsTrue() {
        XCTAssertTrue(SynthesisProcessor.isValidMermaidSyntax("mindmap\n  root((Root))\n  child"))
    }

    func testIsValidMermaidSyntax_emptyString_returnsFalse() {
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax(""))
    }

    func testIsValidMermaidSyntax_singleKeywordOnly_returnsFalse() {
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax("mindmap"))
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax("graph"))
    }

    func testIsValidMermaidSyntax_invalidPrefix_returnsFalse() {
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax("invalid syntax\nA --> B"))
    }

    func testIsValidMermaidSyntax_sequenceDiagram_returnsTrue() {
        XCTAssertTrue(SynthesisProcessor.isValidMermaidSyntax("sequenceDiagram\nA->>B: msg"))
    }

    // MARK: - safeMermaidSyntax

    func testSafeMermaidSyntax_dangerChars_quoted() {
        let result = SynthesisProcessor.safeMermaidSyntax("节点:测试")
        XCTAssertTrue(result.hasPrefix("\""))
        XCTAssertTrue(result.hasSuffix("\""))
    }

    func testSafeMermaidSyntax_plainText_unchanged() {
        let result = SynthesisProcessor.safeMermaidSyntax("普通节点")
        XCTAssertEqual(result, "普通节点")
    }

    func testSafeMermaidSyntax_emptyString_returnsEmpty() {
        XCTAssertEqual(SynthesisProcessor.safeMermaidSyntax(""), "")
    }

    func testSafeMermaidSyntax_alreadyQuoted_notDoubleQuoted() {
        let result = SynthesisProcessor.safeMermaidSyntax("\"已带引号:文本\"")
        XCTAssertEqual(result, "\"已带引号:文本\"")
    }

    // MARK: - extractTitle

    func testExtractTitle_validH1_returnsTitle() {
        let title = SynthesisProcessor.extractTitle(from: "# 知识标题\n\n正文")
        XCTAssertEqual(title, "知识标题")
    }

    func testExtractTitle_noH1_returnsNil() {
        XCTAssertNil(SynthesisProcessor.extractTitle(from: "正文无标题"))
    }

    func testExtractTitle_promptHeader_filtered() {
        let title = SynthesisProcessor.extractTitle(from: "# 【篇幅要求】\n正文")
        XCTAssertNil(title, "Prompt 控制参数标头应被过滤")
    }

    func testExtractTitle_emptyContent_returnsNil() {
        XCTAssertNil(SynthesisProcessor.extractTitle(from: ""))
    }

    // MARK: - cleanMarkdown

    func testCleanMarkdown_stripsPromptPatterns() {
        let text = "【篇幅要求:500字】\n正文内容"
        let cleaned = SynthesisProcessor.cleanMarkdown(text)
        XCTAssertFalse(cleaned.contains("篇幅要求"))
        XCTAssertTrue(cleaned.contains("正文内容"))
    }

    func testCleanMarkdown_unescapesBackslashes() {
        let text = "转义\\[\\[双链\\]\\]"
        let cleaned = SynthesisProcessor.cleanMarkdown(text)
        XCTAssertTrue(cleaned.contains("[[双链]]"))
    }

    // MARK: - formatMermaid

    func testFormatMermaid_validMermaidWithCodeFence_cleanedAndFormatted() {
        let text = "```mermaid\ngraph TD\nA --> B\n```"
        let result = SynthesisProcessor.formatMermaid(text, fallbackPrefix: "graph TD")
        XCTAssertTrue(result.contains("graph TD"))
        XCTAssertFalse(result.contains("```mermaid"))
    }

    func testFormatMermaid_emptyString_returnsEmpty() {
        XCTAssertEqual(SynthesisProcessor.formatMermaid("", fallbackPrefix: "graph TD"), "")
    }

    func testFormatMermaid_whitespaceOnly_returnsEmpty() {
        XCTAssertEqual(SynthesisProcessor.formatMermaid("   \n   ", fallbackPrefix: "graph TD"), "")
    }

    // MARK: - convertMarkdownToListMindmap

    func testConvertMarkdownToListMindmap_generatesValidMindmap() {
        let text = "# 标题\n- 要点1\n- 要点2"
        let result = SynthesisProcessor.convertMarkdownToListMindmap(text, title: "标题")
        XCTAssertTrue(result.contains("mindmap"))
        XCTAssertTrue(result.contains("root((标题))"))
        XCTAssertTrue(result.contains("要点1"))
    }

    func testConvertMarkdownToListMindmap_emptyTitle_usesDefault() {
        let result = SynthesisProcessor.convertMarkdownToListMindmap("内容", title: "")
        XCTAssertTrue(result.contains("mindmap"))
    }

    // MARK: - generateFallbackInfographic

    func testGenerateFallbackInfographic_generatesGraphTD() {
        let result = SynthesisProcessor.generateFallbackInfographic(from: "要点1\n要点2", title: "标题")
        XCTAssertTrue(result.contains("graph TD"))
        XCTAssertTrue(result.contains("Root[\"标题\"]"))
    }

    func testGenerateFallbackInfographic_emptyTitle_usesDefault() {
        let result = SynthesisProcessor.generateFallbackInfographic(from: "内容", title: "")
        XCTAssertTrue(result.contains("graph TD"))
    }

    // MARK: - generateFallbackReport

    func testGenerateFallbackReport_generatesStructuredReport() {
        let result = SynthesisProcessor.generateFallbackReport(from: "要点1\n要点2", title: "标题")
        XCTAssertTrue(result.contains("# 标题"))
        XCTAssertTrue(result.contains("要点1"))
    }

    // MARK: - generateFallbackQuiz

    func testGenerateFallbackQuiz_generatesValidJSON() {
        let result = SynthesisProcessor.generateFallbackQuiz(from: "要点1\n要点2\n要点3", title: "标题")
        XCTAssertTrue(result.contains("quizTitle"))
        XCTAssertTrue(result.contains("questions"))

        guard let data = result.data(using: .utf8) else {
            XCTFail("结果无法转为 UTF-8 Data")
            return
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["questions"])
    }

    // MARK: - formatSlidesIfNeeded

    func testFormatSlidesIfNeeded_alreadyHasSeparator_unchanged() {
        let text = "# 标题\n\n---\n\n## 第二页"
        let result = SynthesisProcessor.formatSlidesIfNeeded(text, fallbackTitle: "标题")
        XCTAssertTrue(result.contains("---"))
    }

    func testFormatSlidesIfNeeded_noSeparator_autoGenerated() {
        let text = "# 标题\n## 章节1\n- 要点1\n- 要点2"
        let result = SynthesisProcessor.formatSlidesIfNeeded(text, fallbackTitle: "标题")
        XCTAssertTrue(result.contains("---"))
    }
}
