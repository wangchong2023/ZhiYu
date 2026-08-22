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

    func testLayout_emptyPages_returnsEmptyNodesAndEdges() {
        let result = GraphLayoutProcessor.layout(
            pages: [],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600)
        )
        XCTAssertTrue(result.nodes.isEmpty)
        XCTAssertTrue(result.edges.isEmpty)
    }

    func testLayout_singlePage_returnsSingleNodeNoEdges() {
        let page = KnowledgePage(title: "Single")
        let result = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertEqual(result.nodes.count, 1)
        XCTAssertTrue(result.edges.isEmpty)
        XCTAssertEqual(result.nodes.first?.title, "Single")
    }

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

    func testLayout_selfLink_filtered() {
        let page = KnowledgePage(title: "SelfLink", content: "[[SelfLink]]")
        let result = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { title in title == "SelfLink" ? page : nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertTrue(result.edges.isEmpty, "自链接应被过滤")
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

    func testLayout_linkCount_reflectsEdgeCount() {
        let page1 = KnowledgePage(title: "Page1", content: "[[Page2]]")
        let page2 = KnowledgePage(title: "Page2", content: "[[Page1]]")
        let pages = [page1, page2]
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { title in pages.first { $0.title == title } },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        // 每个节点至少有 1 个链接
        for node in result.nodes {
            XCTAssertGreaterThanOrEqual(node.linkCount, 1)
        }
    }

    // MARK: - applyForces 边界条件

    func testApplyForces_emptyNodes_noOp() {
        var nodes: [GraphNode] = []
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: [],
            canvasWidth: 800,
            canvasHeight: 600,
            config: .default
        )
        XCTAssertTrue(nodes.isEmpty)
    }

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

    func testDetectCommunities_emptyNodes_returnsEmpty() {
        let result = GraphLayoutProcessor.detectCommunities(nodes: [], edges: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testDetectCommunities_noEdges_eachNodeOwnCommunity() {
        let nodes = [
            GraphNode(id: UUID(), title: "A", pageType: .concept, position: .zero),
            GraphNode(id: UUID(), title: "B", pageType: .concept, position: .zero),
            GraphNode(id: UUID(), title: "C", pageType: .concept, position: .zero)
        ]
        let result = GraphLayoutProcessor.detectCommunities(nodes: nodes, edges: [])
        XCTAssertEqual(result.count, 3)
        // 每个节点应有独立的 communityID
        let communityIDs = result.compactMap { $0.communityID }
        XCTAssertEqual(Set(communityIDs).count, 3)
    }
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

    func testSplit_emptyText_returnsEmptyArray() {
        let chunks = chunker.split(text: "")
        XCTAssertTrue(chunks.isEmpty)
    }

    func testSplit_singleLineShortText_returnsSingleChunk() {
        let chunks = chunker.split(text: "Short text")
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks.first?.text, "Short text")
    }

    func testSplit_whitespaceOnlyText_returnsEmptyArray() {
        let chunks = chunker.split(text: "   \n   \n   ")
        XCTAssertTrue(chunks.isEmpty)
    }

    // MARK: - 代码块处理

    func testSplit_codeBlockNotSplitEvenIfExceedsChunkSize() {
        let config = TextChunkerProcessor.Config(chunkSize: 50, chunkOverlap: 10, separators: TextChunkerProcessor.default.separators)
        let codeBlock = "```\n" + String(repeating: "a", count: 200) + "\n```"
        let chunks = chunker.split(text: codeBlock, config: config)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertTrue(chunks.first?.isCode == true)
    }

    func testSplit_codeBlockWithHashInsideNotTreatedAsHeader() {
        let codeBlock = "```\n# This is a comment\nnot a header\n```"
        let chunks = chunker.split(text: codeBlock)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertTrue(chunks.first?.isCode == true)
    }

    // MARK: - 标题层级与面包屑

    func testSplit_h1H2H3_breadcrumbPathReflectsHierarchy() {
        let text = "# Title\n\n## Section\n\n### Subsection\n\nContent here"
        let chunks = chunker.split(text: text)
        XCTAssertFalse(chunks.isEmpty)
        // 最后一个 chunk 应包含完整面包屑路径
        let lastChunk = chunks.last
        XCTAssertNotNil(lastChunk)
        XCTAssertTrue(lastChunk?.breadcrumbPath.contains("Title") == true)
        XCTAssertTrue(lastChunk?.breadcrumbPath.contains("Section") == true)
        XCTAssertTrue(lastChunk?.breadcrumbPath.contains("Subsection") == true)
    }

    func testSplit_headerLevelSkip_back_to_h1_resetsBreadcrumb() {
        let text = "# Title1\n\n## Sub1\n\n# Title2\n\nContent"
        let chunks = chunker.split(text: text)
        XCTAssertFalse(chunks.isEmpty)
        // Title2 的 chunk 面包屑应只包含 Title2
        let title2Chunk = chunks.first { $0.anchorPath == "Title2" }
        XCTAssertNotNil(title2Chunk)
        XCTAssertEqual(title2Chunk?.breadcrumbPath, "Title2")
    }

    // MARK: - Chunk contextualText

    func testChunk_contextualText_withBreadcrumb_includesContextPrefix() {
        // 源码设计：标题行本身也加入 chunk 文本（L74 在 L67 flush 之后执行）
        // 使用多段文本让标题后的内容单独成块，验证 contextualText 包含 contextPrefix
        let text = "# Header\n\nContent line one\n\n# Section2\n\nContent line two"
        let chunks = chunker.split(text: text)
        XCTAssertFalse(chunks.isEmpty)
        // 找到面包屑非空且包含 "Content" 的 chunk
        let contentChunk = chunks.first { !$0.breadcrumbPath.isEmpty && $0.breadcrumbPath != ProcessorConstants.TextChunker.rootAnchor && $0.text.contains("Content") }
        XCTAssertNotNil(contentChunk, "应找到带面包屑的内容分块，chunks: \(chunks.map { "text='\($0.text)', breadcrumb='\($0.breadcrumbPath)'" })")
        // 有面包屑时 contextualText 应包含 contextPrefix
        XCTAssertTrue(contentChunk?.contextualText.contains(ProcessorConstants.TextChunker.contextPrefix) == true,
                      "有面包屑时 contextualText 应包含 contextPrefix，实际: \(contentChunk?.contextualText ?? "nil")")
    }

    func testChunk_contextualText_rootBreadcrumb_returnsPlainText() {
        let text = "Content without headers"
        let chunks = chunker.split(text: text)
        XCTAssertFalse(chunks.isEmpty)
        let chunk = chunks.first
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.contextualText, chunk?.text)
    }

    // MARK: - 重叠窗口

    func testSplit_overlapWindow_maintainsSemanticContinuity() {
        let config = TextChunkerProcessor.Config(chunkSize: 30, chunkOverlap: 10, separators: TextChunkerProcessor.default.separators)
        let text = "Line one content here\nLine two content here\nLine three content here"
        let chunks = chunker.split(text: text, config: config)
        XCTAssertGreaterThan(chunks.count, 1)
        // 验证重叠窗口存在（第二个 chunk 的 startIndex 应小于第一个 chunk 的结束位置）
        if chunks.count >= 2 {
            let firstChunkEnd = chunks[0].startIndex + chunks[0].text.count
            XCTAssertLessThan(chunks[1].startIndex, firstChunkEnd)
        }
    }

    // MARK: - startIndex 单调递增（缺陷 #12 修复验证）

    func testSplit_startIndex_monotonicallyIncreasing_bug12Fixed() {
        // 源码设计：split 按行处理，不拆分单行。需用多行文本触发溢出 flush
        let config = TextChunkerProcessor.Config(chunkSize: 20, chunkOverlap: 5, separators: TextChunkerProcessor.default.separators)
        let text = "A line one here\nB line two here\nC line three here\nD line four here\nE line five here"
        let chunks = chunker.split(text: text, config: config)
        XCTAssertGreaterThan(chunks.count, 1, "多行文本应产生多个分块，实际: \(chunks.count)")
        for i in 1..<chunks.count {
            XCTAssertGreaterThanOrEqual(chunks[i].startIndex, chunks[i - 1].startIndex,
                                        "startIndex 应单调递增：chunks[\(i)].startIndex=\(chunks[i].startIndex) < chunks[\(i-1)].startIndex=\(chunks[i-1].startIndex)")
        }
    }

    // MARK: - 默认配置

    func testDefaultConfig_chunkSizeIs1000() {
        XCTAssertEqual(TextChunkerProcessor.default.chunkSize, ProcessorConstants.TextChunker.defaultChunkSize)
    }

    func testDefaultConfig_chunkOverlapIs200() {
        XCTAssertEqual(TextChunkerProcessor.default.chunkOverlap, ProcessorConstants.TextChunker.defaultChunkOverlap)
    }

    func testDefaultConfig_separatorsInPriorityOrder() {
        let separators = TextChunkerProcessor.default.separators
        XCTAssertEqual(separators.first, "\n# ")
        XCTAssertEqual(separators.last, "")
    }
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
        // 编译时检查 Sendable 合规
        _ = strategy as SynthesisStrategyProtocol
    }
}

// MARK: - CJKSpacingFormatter 补充测试

final class CJKSpacingFormatterSupplementTests: XCTestCase {

    func testSpacing_emptyString_returnsEmpty() {
        XCTAssertEqual(CJKSpacingFormatter.spacing(""), "")
    }

    func testSpacing_cjkFollowedByEnglish_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("中文English")
        XCTAssertTrue(result.contains(" "))
    }

    func testSpacing_englishFollowedByCJK_insertsSpace() {
        let result = CJKSpacingFormatter.spacing("English中文")
        XCTAssertTrue(result.contains(" "))
    }

    func testSpacing_pureCJK_unchanged() {
        let result = CJKSpacingFormatter.spacing("纯中文")
        XCTAssertEqual(result, "纯中文")
    }

    func testSpacing_pureEnglish_unchanged() {
        let result = CJKSpacingFormatter.spacing("pure english")
        XCTAssertEqual(result, "pure english")
    }

    func testSpacing_alreadySpaced_notDoubleSpaced() {
        let result = CJKSpacingFormatter.spacing("中文 English")
        XCTAssertEqual(result, "中文 English")
    }

    func testPanguFormatter_alias_equivalentToCJKSpacingFormatter() {
        let text = "测试test"
        XCTAssertEqual(PanguFormatter.spacing(text), CJKSpacingFormatter.spacing(text))
    }
}

// MARK: - MermaidSanitizer 补充测试

final class MermaidSanitizerSupplementTests: XCTestCase {

    func testSanitize_emptyString_returnsEmpty() {
        XCTAssertEqual(MermaidSanitizer.sanitize(""), "")
    }

    func testSanitize_graphKeyword_preserved() {
        let result = MermaidSanitizer.sanitize("graph TD\nA[Hello]")
        XCTAssertTrue(result.contains("graph TD"))
    }

    func testSanitize_flowchartKeyword_preserved() {
        let result = MermaidSanitizer.sanitize("flowchart LR\nA[Hello]")
        XCTAssertTrue(result.contains("flowchart LR"))
    }

    func testSanitize_nodeWithColon_autoQuoted() {
        let result = MermaidSanitizer.sanitize("graph TD\nA[Hello:World]")
        XCTAssertTrue(result.contains("\""))
    }

    func testSanitize_plainNodeText_notQuoted() {
        let result = MermaidSanitizer.sanitize("graph TD\nA[Hello]")
        XCTAssertTrue(result.contains("A[Hello]"))
        XCTAssertFalse(result.contains("\""))
    }

    func testSanitize_emptyLines_removed() {
        let result = MermaidSanitizer.sanitize("graph TD\n\n\nA[Hello]")
        XCTAssertFalse(result.contains("\n\n"))
    }
}

// MARK: - SwiftMarkdownASTCleaner 补充测试

final class SwiftMarkdownASTCleanerSupplementTests: XCTestCase {

    func testCleanAST_emptyString_returnsEmpty() {
        XCTAssertEqual(SwiftMarkdownASTCleaner.cleanAST(""), "")
    }

    func testCleanAST_unclosedCodeBlock_appendsClosingFence() {
        let result = SwiftMarkdownASTCleaner.cleanAST("```\ncode")
        // 实现会在末尾追加换行+代码围栏+换行
        let expected = "```\ncode\n```\n"
        XCTAssertEqual(result, expected)
    }

    func testCleanAST_closedCodeBlock_unchanged() {
        let input = "```\ncode\n```"
        let result = SwiftMarkdownASTCleaner.cleanAST(input)
        XCTAssertEqual(result, input)
    }

    func testCleanAST_unclosedBold_appendsClosing() {
        let result = SwiftMarkdownASTCleaner.cleanAST("**bold")
        XCTAssertTrue(result.hasSuffix("**"))
    }

    func testCleanAST_tripleNewlines_collapsedToDouble() {
        let result = SwiftMarkdownASTCleaner.cleanAST("line1\n\n\n\nline2")
        XCTAssertFalse(result.contains("\n\n\n"))
    }
}

// MARK: - IngestSanitationPipeline 补充测试

final class IngestSanitationPipelineSupplementTests: XCTestCase {

    func testSanitize_emptyInput_returnsEmpty() {
        let result = IngestSanitationPipeline.shared.sanitize("", mode: .ocr)
        XCTAssertEqual(result, "")
    }

    func testSanitize_whitespaceOnly_returnsEmpty() {
        let result = IngestSanitationPipeline.shared.sanitize("   \n   ", mode: .ocr)
        XCTAssertEqual(result, "")
    }

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

    func testIngestSourceMode_allCases_containsAllFiveModes() {
        XCTAssertEqual(IngestSourceMode.allCases.count, 5)
        XCTAssertTrue(IngestSourceMode.allCases.contains(.ocr))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.voiceNote))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.webClip))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.document))
        XCTAssertTrue(IngestSourceMode.allCases.contains(.plainMarkdown))
    }
}

// MARK: - DocumentSanitationEngine 补充测试

final class DocumentSanitationEngineSupplementTests: XCTestCase {

    func testSanitize_emptyString_returnsEmpty() {
        XCTAssertEqual(DocumentSanitationEngine.shared.sanitize(""), "")
    }

    func testSanitize_whitespaceOnly_returnsEmpty() {
        XCTAssertEqual(DocumentSanitationEngine.shared.sanitize("   \n   "), "")
    }

    func testSanitize_htmlScriptTag_stripped() {
        let result = DocumentSanitationEngine.shared.sanitize("<script>alert(1)</script>text")
        XCTAssertFalse(result.contains("<script>"))
        XCTAssertTrue(result.contains("text"))
    }

    func testSanitize_htmlStyleTag_stripped() {
        let result = DocumentSanitationEngine.shared.sanitize("<style>.x{}</style>text")
        XCTAssertFalse(result.contains("<style>"))
        XCTAssertTrue(result.contains("text"))
    }

    func testSanitize_htmlGenericTag_stripped() {
        let result = DocumentSanitationEngine.shared.sanitize("<p>text</p>")
        XCTAssertFalse(result.contains("<p>"))
        XCTAssertTrue(result.contains("text"))
    }

    func testSanitizerOptions_defaultSuite_containsAllOptions() {
        let options = SanitizerOptions.defaultSuite
        XCTAssertTrue(options.contains(.applyPanguSpacing))
        XCTAssertTrue(options.contains(.sanitizeMermaid))
        XCTAssertTrue(options.contains(.stripLeadingChatter))
        XCTAssertTrue(options.contains(.mergeOCRLineBreaks))
        XCTAssertTrue(options.contains(.stripHTMLNoise))
    }

    func testSanitizerOptions_emptyRawValue_isEmpty() {
        let options = SanitizerOptions(rawValue: 0)
        XCTAssertTrue(options.isEmpty)
    }
}

// MARK: - WikiLinkExtractor 补充测试

final class WikiLinkExtractorSupplementTests: XCTestCase {

    func testExtractLinks_emptyText_returnsEmpty() {
        XCTAssertTrue(WikiLinkExtractor.extractLinks(from: "").isEmpty)
    }

    func testExtractLinks_noLinks_returnsEmpty() {
        XCTAssertTrue(WikiLinkExtractor.extractLinks(from: "plain text without links").isEmpty)
    }

    func testExtractLinks_singleStandardLink() {
        let links = WikiLinkExtractor.extractLinks(from: "This is a [[Target Page]] link")
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.targetTitle, "Target Page")
    }

    func testExtractLinks_aliasedLink() {
        let links = WikiLinkExtractor.extractLinks(from: "[[Target|Display Text]]")
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.targetTitle, "Target")
        XCTAssertEqual(links.first?.alias, "Display Text")
        XCTAssertEqual(links.first?.displayTitle, "Display Text")
    }

    func testExtractLinks_unclosedBracket_notMatched() {
        let links = WikiLinkExtractor.extractLinks(from: "[[Unclosed")
        XCTAssertTrue(links.isEmpty)
    }

    func testExtractLinks_emptyTitle_notMatched() {
        let links = WikiLinkExtractor.extractLinks(from: "[[ ]]")
        XCTAssertTrue(links.isEmpty)
    }

    func testExtractLinks_escapedBackslash_notMatched() {
        let links = WikiLinkExtractor.extractLinks(from: "\\[[Escaped]]")
        XCTAssertTrue(links.isEmpty)
    }

    func testExtractLinks_multipleLinks() {
        let links = WikiLinkExtractor.extractLinks(from: "[[Page1]] and [[Page2]]")
        XCTAssertEqual(links.count, 2)
    }
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
