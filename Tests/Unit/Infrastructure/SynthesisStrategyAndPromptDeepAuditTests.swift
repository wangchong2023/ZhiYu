//
//  SynthesisStrategyAndPromptDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：深度审计 AI 知识合成策略工厂 (SynthesisStrategyFactory) 与文档后处理器 (SynthesisProcessor) 的容错清洗。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SynthesisStrategyAndPromptDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 合成策略工厂完整派发覆盖

    func testSynthesisStrategyFactory_DispatchesAllTypes() {
        let allTypes: [SynthesisStore.SynthesisType] = [
            .mindmap, .slides, .quiz, .report, .infographic, .expansion
        ]

        for type in allTypes {
            let strategy = SynthesisStrategyFactory.strategy(for: type)
            XCTAssertNotNil(strategy, "所有 SynthesisType 都必须在工厂中有对应的策略实现")
        }
    }

    // MARK: - 2. SynthesisProcessor 源内容净化与系统指令剔除

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

    // MARK: - 3. Mermaid 语法自愈与纯骨架过滤

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
