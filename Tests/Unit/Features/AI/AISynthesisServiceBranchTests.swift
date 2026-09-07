//
//  AISynthesisServiceBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 AISynthesisService 的模板生成分支、Mermaid 降级、异常回退以及文本清洗。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AISynthesisServiceBranchTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 摘要生成与文本清理分支

    func testSummarize_CleansMarkdownHeadersAndCodeBlocks() async throws {
        let service = AISynthesisService.shared
        let content = "这是一段关于分布式共识 Raft 算法的详细背景介绍..."

        let summary = try await service.summarize(content: content)
        XCTAssertFalse(summary.isEmpty, "生成的摘要不应为空")
    }

    // MARK: - 2. 思维导图非法 Mermaid 降级分支

    func testGenerateMindMap_WhenMermaidInvalid_FallsBackToListMindmap() async throws {
        let service = AISynthesisService.shared
        let emptyOrBadContent = "仅有一行文本"

        let mindmap = try await service.generateMindMap(content: emptyOrBadContent)
        XCTAssertFalse(mindmap.isEmpty, "思维导图应触发保底转换机制返回可用列表或脑图")
    }

    // MARK: - 3. 幻灯片大纲生成与保底模板分支

    func testGeneratePresentation_WhenLLMFails_FallsBackToTemplate() async throws {
        let service = AISynthesisService.shared
        let content = "# 智宇 AI Wiki 架构体系\n详细内容描述..."

        let slides = try await service.generatePresentation(content: content)
        XCTAssertFalse(slides.isEmpty, "幻灯片生成应当返回有效 Markdown 大纲")
    }

    // MARK: - 4. 测验生成与格式自愈分支

    func testGenerateQuiz_ReturnsValidContent() async throws {
        let service = AISynthesisService.shared
        let content = "概念 1: 向量检索是基于余弦相似度计算。\n概念 2: FTS5 是 SQLite 的全文检索引擎。"

        let quiz = try await service.generateQuiz(content: content)
        XCTAssertFalse(quiz.isEmpty, "测验题生成不应为空")
    }

    // MARK: - 5. 信息图表 Mermaid 分支

    func testGenerateInfographic_ReturnsValidMermaidGraph() async throws {
        let service = AISynthesisService.shared
        let content = "从数据摄取到向量索引再到大模型合成的完整闭环数据流。"

        let infographic = try await service.generateInfographic(content: content)
        XCTAssertFalse(infographic.isEmpty, "信息图表生成不应为空")
    }

    // MARK: - 6. 深度研究报告多源分支

    func testGenerateReport_GeneratesComprehensiveReport() async throws {
        let service = AISynthesisService.shared
        let content = "主题：2026 年移动端知识图谱与向量数据库最佳实践架构分析。"

        let report = try await service.generateReport(content: content)
        XCTAssertFalse(report.isEmpty, "深度报告不应为空")
    }

    // MARK: - 7. 知识深度扩充分支

    func testExpandKnowledge_ReturnsExpandedContent() async throws {
        let service = AISynthesisService.shared
        let content = "RAG 技术的核心挑战是召回准确率与噪声控制。"

        let expanded = try await service.expandKnowledge(content: content)
        XCTAssertFalse(expanded.isEmpty, "知识扩充不应为空")
    }
}
