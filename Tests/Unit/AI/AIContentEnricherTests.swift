//
//  AIContentEnricherTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AIContentEnricher 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

private final class TriggerBox: @unchecked Sendable {
    var isTriggered = false
}

@MainActor
final class AIContentEnricherTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }
    
    // MARK: - 纯文本测试
    
    /// 验证普通 Markdown 段落（不含表格和图片）在 Actor 中秒回原文本，且不触发大模型
    func testPlainMarkdownNoEnrichment() async {
        let content = "这是一段非常普通的文本段落，介绍量子力学的宏观表现。"
        let mockLLM = MockLLMService()
        
        let triggerBox = TriggerBox()
        mockLLM.generateHandler = { _, _ in
            triggerBox.isTriggered = true
            return "不应该被触发"
        }
        
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        
        XCTAssertEqual(enriched, content)
        XCTAssertFalse(triggerBox.isTriggered, "普通段落应该秒回，绝不触发大模型请求")
    }
    
    // MARK: - Markdown 表格数据增强测试
    
    /// 验证 Markdown 表格能够被正确分割提取，触发 LLM 注入并在返回中增加 "> [数据洞察]" 模块
    func testMarkdownTableEnrichment() async {
        let content = """
        这是一段正文。
        
        | 季度 | Token 消耗 | 环比增长 |
        | --- | --- | --- |
        | Q1 | 500K | - |
        | Q2 | 1.2M | 140% |
        
        这里是表格下方的正文。
        """
        
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { prompt, systemPrompt in
            XCTAssertTrue(systemPrompt.contains("数据分析师"))
            XCTAssertTrue(prompt.contains("Q2"))
            return "> [数据洞察]: Token 消耗呈现爆发式增长，第二季度环比飙升 140%，证明用户依赖加深。"
        }
        
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        
        XCTAssertTrue(enriched.contains("| 季度 | Token 消耗 | 环比增长 |"))
        XCTAssertTrue(enriched.contains("> [数据洞察]: Token 消耗呈现爆发式增长"))
        XCTAssertTrue(enriched.contains("这里是表格下方的正文。"))
    }
    
    // MARK: - Markdown 图片语义增强测试
    
    /// 验证图片语法能够被正则完美捕获，触发 LLM 视觉语义理解并返回 "> [图片语义]" 标记
    func testMarkdownImageEnrichment() async {
        let content = """
        这里展示一张核心原理图：
        
        ![量子纠缠状态演变图](https://zhiyu.app/assets/entanglement.png)
        
        图片介绍完毕。
        """
        
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { prompt, systemPrompt in
            XCTAssertTrue(systemPrompt.contains("视觉理解专家"))
            XCTAssertTrue(prompt.contains("量子纠缠状态演变图"))
            return "> [图片语义]: 模拟量子纠缠系统随时间的退相干效应，直观展现了态密度的收敛轨迹。"
        }
        
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        
        XCTAssertTrue(enriched.contains("![量子纠缠状态演变图](https://zhiyu.app/assets/entanglement.png)"))
        XCTAssertTrue(enriched.contains("> [图片语义]: 模拟量子纠缠系统随时间的退相干效应"))
    }
}
