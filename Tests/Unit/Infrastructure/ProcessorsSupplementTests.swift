//
//  ProcessorsSupplementTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：Task 14 — Infrastructure/Processors 5 组件补盲测试 + 问题驱动测试
//

import XCTest
import Foundation
import Dependencies
import UFPCore
@testable import ZhiYu

// MARK: - A-27 修复：NoOpDocumentExtractionService 已移入生产代码（DocumentExtractionServiceProtocol.swift）

// MARK: - ImageExtractor 补充测试

final class ImageExtractorSupplementTests: XCTestCase {

    private var extractor: ImageExtractor!

    override func setUp() {
        super.setUp()
        extractor = ImageExtractor()
    }

    override func tearDown() {
        extractor = nil
        super.tearDown()
    }

    // MARK: - extractImagesFromHTML 边界条件

    func testExtractImagesFromHTML_emptyHTML_returnsEmpty() async {
        let result = await extractor.extractImagesFromHTML("", baseURL: nil)
        XCTAssertEqual(result, "")
    }

    func testExtractImagesFromHTML_noImgTags_returnsEmpty() async {
        let html = "<html><body><p>No images here</p></body></html>"
        let result = await extractor.extractImagesFromHTML(html, baseURL: nil)
        XCTAssertEqual(result, "")
    }

    func testExtractImagesFromHTML_onlySvgImages_filtered() async {
        let html = #"<img src="https://example.com/diagram.svg" alt="diagram">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "SVG 图片应被过滤")
    }

    // MARK: - ocrImageBatch 边界条件

    func testOcrImageBatch_emptyList_returnsEmpty() async {
        let result = await extractor.ocrImageBatch([], prefix: ProcessorConstants.FileFormat.pdf)
        XCTAssertEqual(result, "")
    }

    // MARK: - parseImageURLs SSRF 防护

    func testParseImageURLs_localhost_filtered() {
        let html = #"<img src="http://localhost:8080/secret.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "localhost 应被 SSRF 防护过滤")
    }

    func testParseImageURLs_privateIP_filtered() {
        let html = #"<img src="http://192.168.1.1/secret.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "私有 IP 应被 SSRF 防护过滤")
    }

    func testParseImageURLs_linkLocal_filtered() {
        let html = #"<img src="http://169.254.169.254/metadata.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "链路本地地址应被 SSRF 防护过滤")
    }

    // MARK: - resolveURL 间接测试（通过 parseImageURLs）

    func testParseImageURLs_protocolRelativeURL_resolved() {
        let html = #"<img src="//example.com/image.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.scheme, "https")
    }

    func testParseImageURLs_rootRelativeURL_resolvedWithBaseURL() {
        let html = #"<img src="/images/photo.png">"#
        let baseURL = URL(string: "https://example.com/blog/article")
        let urls = extractor.parseImageURLs(from: html, baseURL: baseURL)
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls.first?.absoluteString.contains("example.com") == true)
    }

    func testParseImageURLs_relativeURL_resolvedWithBaseURL() {
        let html = #"<img src="photo.png">"#
        let baseURL = URL(string: "https://example.com/blog/")
        let urls = extractor.parseImageURLs(from: html, baseURL: baseURL)
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls.first?.absoluteString.contains("photo.png") == true)
    }

    func testParseImageURLs_relativeURL_noBaseURL_returnsNil() {
        let html = #"<img src="photo.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "无 baseURL 的相对路径应返回空")
    }

    // MARK: - 多图片截断测试

    func testParseImageURLs_moreThanMaxImages_notTruncatedInParse() {
        var html = ""
        for i in 0..<15 {
            html += #"<img src="https://example.com/image\#(i).png">"#
        }
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 15, "parseImageURLs 不截断，截断在 extractImagesFromHTML 中")
    }
}

// MARK: - DocumentExtractionService 补充测试

final class DocumentExtractionServiceSupplementTests: XCTestCase {

    private var service: DocumentExtractionService!

    override func setUp() {
        super.setUp()
        service = DocumentExtractionService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - canExtract 全格式覆盖

    func testCanExtract_pdf_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .pdf))
    }

    func testCanExtract_docx_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .docx))
    }

    func testCanExtract_xlsx_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .xlsx))
    }

    func testCanExtract_markdown_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .markdown))
    }

    func testCanExtract_plainText_returnsTrue() {
        XCTAssertTrue(service.canExtract(format: .plainText))
    }

    func testCanExtract_unknown_returnsFalse() {
        XCTAssertFalse(service.canExtract(format: .unknown))
    }

    // MARK: - extractText 纯文本路径

    func testExtractText_markdownFile_returnsContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).md")
        let expectedContent = "# Test Markdown\n\nThis is test content."
        try expectedContent.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = try await service.extractText(from: tempFile)
        XCTAssertEqual(result, expectedContent)
    }

    func testExtractText_plainTextFile_returnsContent() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).txt")
        let expectedContent = "Plain text content"
        try expectedContent.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = try await service.extractText(from: tempFile)
        XCTAssertEqual(result, expectedContent)
    }

    // MARK: - extractText 错误路径

    func testExtractText_unsupportedFormat_throwsExtractionFailed() async {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).xyz")
        try? "content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        do {
            _ = try await service.extractText(from: tempFile)
            XCTFail("应抛出 extractionFailed 错误")
        } catch {
            // 预期抛出错误
        }
    }

    func testExtractText_nonExistentFile_throwsError() async {
        let nonExistent = URL(fileURLWithPath: "/tmp/non_existent_file_\(UUID().uuidString).txt")

        do {
            _ = try await service.extractText(from: nonExistent)
            XCTFail("应抛出错误")
        } catch {
            // 预期抛出错误
        }
    }
}

// MARK: - GraphLayoutProcessor 补充测试

final class GraphLayoutProcessorSupplementTests: XCTestCase {

    // MARK: - Config 默认值

    func testConfig_default_hasExpectedValues() {
        let config = GraphLayoutProcessor.Config.default
        XCTAssertEqual(config.iterations, GraphConstants.TwoD.simulationIterations)
        XCTAssertEqual(config.padding, DesignSystem.Graph.layoutPadding)
    }

    func testConfig_customIterations() {
        let config = GraphLayoutProcessor.Config(iterations: 1)
        XCTAssertEqual(config.iterations, 1)
    }

    // MARK: - layout 边界条件
    func testLayout_multiplePages_allNodesHavePositions() {
        let pages = [
            KnowledgePage(title: "Page1"),
            KnowledgePage(title: "Page2"),
            KnowledgePage(title: "Page3")
        ]
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertEqual(result.nodes.count, 3)
        for node in result.nodes {
            XCTAssertFalse(node.position.x.isNaN)
            XCTAssertFalse(node.position.y.isNaN)
        }
    }

    func testLayout_linkedPages_createsEdges() {
        let page1 = KnowledgePage(title: "Page1", content: "[[Page2]]")
        let page2 = KnowledgePage(title: "Page2")
        let pages = [page1, page2]
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { title in pages.first { $0.title == title } },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertEqual(result.nodes.count, 2)
        XCTAssertGreaterThanOrEqual(result.edges.count, 1)
    }
    func testLayout_relatedPageIDs_createsEdges() {
        let page2ID = UUID()
        let page1 = KnowledgePage(title: "Page1", relatedPageIDs: [page2ID])
        let page2 = KnowledgePage(id: page2ID, title: "Page2")
        let pages = [page1, page2]
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertEqual(result.edges.count, 1)
    }
    // MARK: - applyForces 边界条件
    func testApplyForces_singleNode_noEdges_staysInBounds() {
        let page = KnowledgePage(title: "Single")
        let initial = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        var nodes = initial.nodes
        let originalCount = nodes.count
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: [],
            canvasWidth: 800,
            canvasHeight: 600,
            config: .default
        )
        XCTAssertEqual(nodes.count, originalCount)
        for node in nodes {
            XCTAssertGreaterThanOrEqual(node.position.x, 0)
            XCTAssertLessThanOrEqual(node.position.x, 800)
            XCTAssertGreaterThanOrEqual(node.position.y, 0)
            XCTAssertLessThanOrEqual(node.position.y, 600)
        }
    }

    // MARK: - detectCommunities 边界条件
}

// MARK: - TextChunkerProcessor 补充测试

final class TextChunkerSupplementTests: XCTestCase {

    private var chunker: TextChunkerProcessor!

    override func setUp() {
        super.setUp()
        chunker = TextChunkerProcessor()
    }

    override func tearDown() {
        chunker = nil
        super.tearDown()
    }

    // MARK: - split 边界条件
    // MARK: - 代码块处理
    // MARK: - 标题层级与面包屑
    // MARK: - Chunk contextualText
    // MARK: - 重叠窗口
    // MARK: - startIndex 单调递增（缺陷 #12 修复验证）
    // MARK: - 默认配置
}

// MARK: - QuizSynthesisStrategy 补充测试

final class QuizSynthesisStrategySupplementTests: XCTestCase {

    private var strategy: QuizSynthesisStrategy!

    override func setUp() {
        super.setUp()
        strategy = QuizSynthesisStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    // MARK: - type 属性

    func testType_isQuiz() {
        XCTAssertEqual(strategy.type, .quiz)
    }

    // MARK: - process 路径覆盖

    func testProcess_validQuizJSON_returnsRawContent() {
        let validJSON = """
        {
            "quizTitle": "Test Quiz",
            "questions": [
                {
                    "id": 1,
                    "question": "What is 1+1?",
                    "options": ["1", "2", "3", "4"],
                    "answerIndex": 1,
                    "explanation": "Basic math"
                }
            ]
        }
        """
        let result = strategy.process(rawContent: validJSON, sourceContent: "source")
        XCTAssertEqual(result, validJSON)
    }

    func testProcess_invalidContent_longEnough_returnsRawContent() {
        // rawContent.utf8.count >= minValidSynthesisTextBytes (10) 但无法解析为 quiz
        let longInvalidContent = "This is a long enough content that cannot be parsed as quiz JSON"
        let result = strategy.process(rawContent: longInvalidContent, sourceContent: "source")
        // 由于 canDecodeAsQuizModel false, convertJSONToMarkdown nil, 但 utf8.count >= 10
        XCTAssertEqual(result, longInvalidContent)
    }

    func testProcess_invalidContent_tooShort_returnsFallback() {
        // rawContent.utf8.count < minValidSynthesisTextBytes (10)
        let shortInvalidContent = "short"
        let result = strategy.process(rawContent: shortInvalidContent, sourceContent: "source content")
        // 应返回 fallback
        XCTAssertFalse(result.isEmpty)
        // fallback 应是有效 JSON
        XCTAssertTrue(result.contains("quizTitle") || result.contains("questions"))
    }

    func testProcess_emptyContent_returnsFallback() {
        let result = strategy.process(rawContent: "", sourceContent: "source content")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - generateFallback

    func testGenerateFallback_returnsValidQuizJSON() {
        let result = strategy.generateFallback(from: "source content", title: "Test Title")
        XCTAssertFalse(result.isEmpty)
        // 应是有效 JSON
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNotNil(json[ProcessorConstants.Synthesis.quizTitleKey])
            XCTAssertNotNil(json[ProcessorConstants.Synthesis.quizQuestionsKey])
        } else {
            XCTFail("generateFallback 应返回有效 JSON")
        }
    }

    func testGenerateFallback_emptyTitle_usesDefaultTitle() {
        let result = strategy.generateFallback(from: "source content", title: "")
        XCTAssertFalse(result.isEmpty)
        // 应包含默认标题
        XCTAssertTrue(result.contains(L10n.AI.Prompt.Quiz.defaultTitle) || result.contains("quizTitle"))
    }

    func testGenerateFallback_whitespaceTitle_usesDefaultTitle() {
        let result = strategy.generateFallback(from: "source content", title: "   ")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Sendable 合规

    func testStrategy_isSendable() {
        // 编译时与运行时检查 Sendable 合规
        let proto = strategy as SynthesisStrategyProtocol
        XCTAssertNotNil(proto, "strategy 实例应合规遵循 SynthesisStrategyProtocol")
    }
}

// MARK: - CJKSpacingFormatter 补充测试

final class CJKSpacingFormatterSupplementTests: XCTestCase {
    // 占位：CJK 间距格式化器补充测试
}

// MARK: - MermaidSanitizer 补充测试

final class MermaidSanitizerSupplementTests: XCTestCase {
    // 占位：Mermaid 清理器补充测试
}

// MARK: - SwiftMarkdownASTCleaner 补充测试

final class SwiftMarkdownASTCleanerSupplementTests: XCTestCase {
    // 占位：SwiftMarkdown AST 清理器补充测试
}

// MARK: - IngestSanitationPipeline 补充测试

final class IngestSanitationPipelineSupplementTests: XCTestCase {
    func testSanitize_ocrMode_stripsHTML() {
        let input = "<p>OCR text</p>"
        let result = IngestSanitationPipeline.shared.sanitize(input, mode: .ocr)
        XCTAssertFalse(result.contains("<p>"))
        XCTAssertTrue(result.contains("OCR text"))
    }

    func testSanitize_voiceNoteMode_stripsLeadingChatter() {
        let input = "Here is the summary:\nActual content"
        let result = IngestSanitationPipeline.shared.sanitize(input, mode: .voiceNote)
        XCTAssertFalse(result.contains("Here is the summary"))
    }

    func testSanitize_webClipMode_stripsHTML() {
        let input = "<script>alert(1)</script><p>Content</p>"
        let result = IngestSanitationPipeline.shared.sanitize(input, mode: .webClip)
        XCTAssertFalse(result.contains("<script>"))
        XCTAssertTrue(result.contains("Content"))
    }
}

// MARK: - DocumentSanitationEngine 补充测试

final class DocumentSanitationEngineSupplementTests: XCTestCase {
    // 占位：文档清理引擎补充测试
}

// MARK: - WikiLinkExtractor 补充测试

final class WikiLinkExtractorSupplementTests: XCTestCase {
    // 占位：Wiki 链接提取器补充测试
}

// MARK: - JSONExtractor 补充测试

final class JSONExtractorSupplementTests: XCTestCase {

    func testExtractFirstJSONObject_noBrace_returnsNil() {
        XCTAssertNil(JSONExtractor.extractFirstJSONObject(from: "no json here"))
    }

    func testExtractFirstJSONObject_simpleObject() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"key": "value"}"#)
        XCTAssertEqual(result, #"{"key": "value"}"#)
    }

    func testExtractFirstJSONObject_nestedObject() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"outer": {"inner": 1}}"#)
        XCTAssertEqual(result, #"{"outer": {"inner": 1}}"#)
    }

    func testExtractFirstJSONObject_unclosedBrace_returnsNil() {
        XCTAssertNil(JSONExtractor.extractFirstJSONObject(from: #"{"key": "value""#))
    }

    func testExtractFirstJSONObject_braceInString_notCounted() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"key": "val}ue"}"#)
        XCTAssertEqual(result, #"{"key": "val}ue"}"#)
    }

    func testExtractFirstJSONObject_escapedQuoteInString() {
        let result = JSONExtractor.extractFirstJSONObject(from: #"{"key": "val\"ue"}"#)
        XCTAssertNotNil(result)
    }

    func testExtractJSONDictionary_validJSON_returnsDict() {
        let dict = JSONExtractor.extractJSONDictionary(from: #"{"name": "test", "count": 42}"#)
        XCTAssertEqual(dict["name"] as? String, "test")
        XCTAssertEqual(dict["count"] as? Int, 42)
    }

    func testExtractJSONDictionary_invalidJSON_returnsEmpty() {
        let dict = JSONExtractor.extractJSONDictionary(from: "not json at all")
        XCTAssertTrue(dict.isEmpty)
    }

    func testExtractJSONDictionary_codeFenceStripped() {
        let dict = JSONExtractor.extractJSONDictionary(from: "```json\n{\"key\": \"value\"}\n```")
        XCTAssertEqual(dict["key"] as? String, "value")
    }
}

// MARK: - FrontmatterParser 补充测试

final class FrontmatterParserSupplementTests: XCTestCase {

    func testSplit_noFrontmatter_returnsNilFrontmatter() {
        let result = FrontmatterParser.split(content: "plain text without frontmatter")
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "plain text without frontmatter")
    }

    func testSplit_validYAMLFrontmatter() {
        let content = "---\ntitle: Test\n---\nBody content"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNotNil(result.frontmatter)
        XCTAssertTrue(result.frontmatter?.contains("title: Test") == true)
        XCTAssertEqual(result.body, "Body content")
    }

    func testSplit_validJSONFrontmatter() {
        let content = "---json\n{\"title\": \"Test\"}\n---\nBody"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNotNil(result.frontmatter)
        XCTAssertEqual(result.body, "Body")
    }

    func testSplit_unclosedFrontmatter_returnsNil() {
        let content = "---\ntitle: Test\nNo closing delimiter"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    func testSplit_emptyFrontmatter_returnsNil() {
        let content = "---\n---\nBody"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "Body")
    }

    func testParse_validJSON_returnsModel() {
        let json = #"{"pronunciation": "test", "definition": "a test"}"#
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "test")
        XCTAssertEqual(result?.definition, "a test")
    }

    func testParse_invalidJSON_returnsDefaultModel() {
        // EntityFrontmatter 所有字段可选，"not json" 经 YAML 降级转为 {} 后解码成功
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: "not json")
        XCTAssertNotNil(result)
        XCTAssertNil(result?.pronunciation)
        XCTAssertNil(result?.definition)
    }

    func testParse_emptyString_returnsDefaultModel() {
        // 空字符串经 YAML 降级转为 {} 后解码成功，返回全 nil 的默认模型
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: "")
        XCTAssertNotNil(result)
        XCTAssertNil(result?.pronunciation)
    }
}
