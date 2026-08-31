//
//  SynthesisProcessorDeepBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 SynthesisProcessor 的 Prompt 清洗、Mermaid 自愈与合法性校验全分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class SynthesisProcessorDeepBranchTests: XCTestCase {

    // MARK: - 1. Prompt 指令行过滤分支

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

    // MARK: - 2. Mermaid 合法性校验全分支

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

    // MARK: - 3. Markdown 转 Mermaid Mindmap 柔性自愈

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

    // MARK: - 4. Mermaid 格式化容灾分支

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
}
