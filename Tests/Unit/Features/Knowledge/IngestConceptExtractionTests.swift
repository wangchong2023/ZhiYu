//
//  IngestConceptExtractionTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Knowledge
//  核心职责：验证 IngestService 概念提取算法对空标题、长短标题重叠及默认初始化的行为。
//

import XCTest
@testable import ZhiYu

final class IngestConceptExtractionTests: XCTestCase {

    /// 验证 extractConcepts 跳过空标题页面
    func testExtractConcepts_emptyTitle_skipsExtraction() async {
        let service = IngestService()
        let pages = [
            KnowledgePage(id: UUID(), title: "", pageType: .concept, content: "test"),
            KnowledgePage(id: UUID(), title: "AI", pageType: .concept, content: "test")
        ]
        let concepts = await service.extractConcepts(from: "This is about AI", pages: pages)
        XCTAssertEqual(concepts, ["AI"], "空标题页面不应被识别为 concept")
        XCTAssertFalse(concepts.contains(""), "空字符串不应出现在 concepts 中")
    }

    /// 验证 extractConcepts 对空标题页面不会导致所有页面被识别
    func testExtractConcepts_emptyTitle_doesNotMatchAllContent() async {
        let service = IngestService()
        let pages = [
            KnowledgePage(id: UUID(), title: "", pageType: .concept, content: "test"),
            KnowledgePage(id: UUID(), title: "Python", pageType: .concept, content: "test")
        ]
        let concepts = await service.extractConcepts(from: "Hello World", pages: pages)
        XCTAssertTrue(concepts.isEmpty, "空标题不应匹配任意内容")
    }

    /// 验证短标题和长标题同时存在时都能被正确识别
    func testExtractConcepts_shortAndLongTitles_bothRecognized() async {
        let service = IngestService()
        let longTitlePage = KnowledgePage(id: UUID(), title: "AI Application", pageType: .concept, content: "test")
        let shortTitlePage = KnowledgePage(id: UUID(), title: "AI", pageType: .concept, content: "test")
        let pages = [longTitlePage, shortTitlePage]

        let concepts = await service.extractConcepts(from: "This is about AI Application", pages: pages)
        XCTAssertTrue(concepts.contains("AI"), "应识别短标题 AI")
        XCTAssertTrue(concepts.contains("AI Application"), "应识别长标题 AI Application")
    }

    /// 验证 IngestService 可正常实例化
    func testIngestService_defaultInit_isInstantiable() {
        let service = IngestService()
        XCTAssertNotNil(service, "IngestService 应可正常实例化")
    }
}
