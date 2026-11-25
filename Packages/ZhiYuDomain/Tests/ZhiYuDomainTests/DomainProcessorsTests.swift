//
//  DomainProcessorsTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证下沉至 ZhiYuDomain 的 WikiLinkExtractor、MermaidSanitizer、ThinkingProcessor 与 FrontmatterDocumentModels。
//

import XCTest
@testable import ZhiYuDomain

final class DomainProcessorsTests: XCTestCase {

    func testWikiLinkExtractorParsesPlainAndAliasedLinks() {
        let links = WikiLinkExtractor.extractLinks(from: "参见 [[知识图谱]] 与 [[RAG架构|检索增强]]，忽略 \\[[转义]]")
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].targetTitle, "知识图谱")
        XCTAssertNil(links[0].alias)
        XCTAssertEqual(links[0].displayTitle, "知识图谱")
        XCTAssertEqual(links[1].targetTitle, "RAG架构")
        XCTAssertEqual(links[1].alias, "检索增强")
        XCTAssertEqual(links[1].displayTitle, "检索增强")
    }

    func testMermaidSanitizerQuotesSpecialCharactersInLabels() {
        let raw = """
        flowchart TD
        A[Node (With Paren)] --> B[CleanNode]
        """
        let sanitized = MermaidSanitizer.sanitize(raw)
        XCTAssertTrue(sanitized.contains(#"A["Node (With Paren)"]"#))
        XCTAssertTrue(sanitized.contains("B[CleanNode]"))
    }

    func testThinkingProcessorExtractsThinkTagAndMainAnswer() {
        let raw = "<think>先分析上下文再归纳结论</think>\n最终回答内容"
        let result = ThinkingProcessor.process(raw)
        XCTAssertEqual(result.thinkingContent, "先分析上下文再归纳结论")
        XCTAssertEqual(result.mainContent, "最终回答内容")
    }

    func testThinkingProcessorHandlesPlainAnswerWithoutThinking() {
        let result = ThinkingProcessor.process("直接回答无思考标签")
        XCTAssertNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, "直接回答无思考标签")
    }

    func testMatrixValueCodableRoundTrip() throws {
        let cells: [MatrixValue] = [.text("高"), .rating(4.8), .range(min: 1.0, max: 5.0), .imageList(["a.png"]), .null]
        let data = try JSONEncoder().encode(cells)
        let decoded = try JSONDecoder().decode([MatrixValue].self, from: data)
        XCTAssertEqual(decoded, cells)
    }
}
