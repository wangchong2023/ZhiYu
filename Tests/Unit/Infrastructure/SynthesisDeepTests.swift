//
//  SynthesisDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：SynthesisProcessorDeepBranchTests.swift, SynthesisStrategyAndPromptDeepAuditTests.swift
//

import Dependencies
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class SynthesisDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testSanitizeSourceLines_FilterPromptKeywords() {
        let input = """
        # 正常标题
        请以思维导图形式输出
        目标受众：专业开发者
        Tone: Professional
        ```mermaid
        mindmap
        ```
        真正的内容第一行
        真正的内容第二行
        """
        let lines = SynthesisProcessor.sanitizeSourceLines(input)

        XCTAssertTrue(lines.contains("# 正常标题"))
        XCTAssertTrue(lines.contains("真正的内容第一行"))
        XCTAssertTrue(lines.contains("真正的内容第二行"))
        XCTAssertFalse(lines.contains("```mermaid"))
    }

    func testIsValidMermaidSyntax_AllVariants() {
        // 空文本
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax(""))
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax("   \n\t  "))

        // 合法 mindmap
        let validMindmap = """
        mindmap
          root((知识图谱))
            概念A
            概念B
        """
        XCTAssertTrue(SynthesisProcessor.isValidMermaidSyntax(validMindmap))

        // 合法 graph TD
        let validGraph = """
        graph TD
          A --> B
          B --> C
        """
        XCTAssertTrue(SynthesisProcessor.isValidMermaidSyntax(validGraph))

        // 仅有 mindmap 头部（无子节点）
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax("mindmap"))
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax("graph TD"))

        // 非法前缀
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax("invalid_prefix\n  A --> B"))
    }

    func testConvertMarkdownToListMindmap_FallbackHealing() {
        let md = """
        - 第一模块
          - 核心概念1
          - 核心概念2
        - 第二模块
          - 扩展应用
        """
        let result = SynthesisProcessor.convertMarkdownToListMindmap(md, title: "系统架构")
        XCTAssertTrue(result.contains("mindmap"))
        XCTAssertTrue(result.contains("系统架构"))
        XCTAssertTrue(result.contains("第一模块"))
    }

    func testFormatMermaid_EmptyAndMalformedHandling() {
        let emptyResult = SynthesisProcessor.formatMermaid("", fallbackPrefix: "graph TD")
        XCTAssertTrue(emptyResult.isEmpty)

        let whitespaceResult = SynthesisProcessor.formatMermaid("   \n  ", fallbackPrefix: "mindmap")
        XCTAssertTrue(whitespaceResult.isEmpty)

        let rawNodesOnly = "A --> B\nB --> C"
        let formatted = SynthesisProcessor.formatMermaid(rawNodesOnly, fallbackPrefix: "graph TD")
        XCTAssertTrue(formatted.contains("graph TD"))
        XCTAssertTrue(formatted.contains("A --> B"))
    }

    func testSynthesisStrategyFactory_DispatchesAllTypes() {
        let allTypes: [SynthesisStore.SynthesisType] = [
            .mindmap, .slides, .quiz, .report, .infographic, .expansion
        ]

        for type in allTypes {
            let strategy = SynthesisStrategyFactory.strategy(for: type)
            XCTAssertNotNil(strategy, "所有 SynthesisType 都必须在工厂中有对应的策略实现")
        }
    }

    func testSynthesisProcessor_SanitizeSourceLines() {
        let depthKey = L10n.AI.Synthesis.Control.depth
        let audienceKey = L10n.AI.Synthesis.Control.audience
        let toneKey = L10n.AI.Synthesis.Control.tone

        let rawText = """
        这是正文第一行
        ```markdown
        Format: JSON
        Requirements: Strict
        \(depthKey): Detailed
        \(audienceKey): Beginner
        \(toneKey): Academic
        ```
        知识核心定义与推导
        """

        let cleaned = SynthesisProcessor.sanitizeSourceLines(rawText)
        XCTAssertEqual(cleaned.count, 2, "系统 Prompt 指令与代码栅栏应被完全剔除")
        XCTAssertTrue(cleaned.contains("这是正文第一行"))
        XCTAssertTrue(cleaned.contains("知识核心定义与推导"))
    }

    func testSynthesisProcessor_FormatMermaid_FiltersPureSkeleton() {
        // 纯骨架应被过滤为空字符串
        let pureMindmap = "```mermaid\nmindmap\n```"
        let resultMindmap = SynthesisProcessor.formatMermaid(pureMindmap, fallbackPrefix: "mindmap\n  root((主题))")
        XCTAssertTrue(resultMindmap.isEmpty, "纯 Mermaid mindmap 骨架必须被过滤为空，防止污染知识库")

        let pureGraph = "```mermaid\ngraph TD\n```"
        let resultGraph = SynthesisProcessor.formatMermaid(pureGraph, fallbackPrefix: "graph TD")
        XCTAssertTrue(resultGraph.isEmpty, "纯 Mermaid graph TD 骨架必须被过滤为空")

        // 真实有意义的 Mermaid 内容
        let validMermaid = "```mermaid\nmindmap\n  root((核心系统))\n    子模块A\n    子模块B\n```"
        let validResult = SynthesisProcessor.formatMermaid(validMermaid, fallbackPrefix: "")
        XCTAssertFalse(validResult.isEmpty, "包含实际节点的 Mermaid 代码必须正常保留并格式化")
    }

}
