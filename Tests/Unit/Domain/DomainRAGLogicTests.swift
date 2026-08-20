//
//  DomainRAGLogicTests.swift
//  ZhiYuTests
//
//  系统层级：[L1.5] 领域层测试
//  核心职责：验证 Domain/RAG 中纯逻辑工具函数 — LLMUtils JSON 解析、
//           Markdown 剥离、内容提取，以及 PromptRegistry 提示词组装。
//

import XCTest
@testable import ZhiYu

// MARK: - LLMUtils 单元测试

final class LLMUtilsDomainTests: XCTestCase {

    // MARK: - stripMarkdown

    /// 验证剥离 ```json 代码块标记
    func testStripMarkdownJsonCodeFence() {
        let input = "```json\n[\"a\", \"b\"]\n```"
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "[\"a\", \"b\"]")
    }

    /// 验证剥离 ``` 代码块标记
    func testStripMarkdownCodeFence() {
        let input = "```\n{\"key\": \"value\"}\n```"
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "{\"key\": \"value\"}")
    }

    /// 验证无 Markdown 标记时仅修剪空白
    func testStripMarkdownNoFence() {
        let input = "  plain text  \n"
        let result = LLMUtils.stripMarkdown(input)
        XCTAssertEqual(result, "plain text")
    }

    /// 验证空字符串
    func testStripMarkdownEmpty() {
        XCTAssertEqual(LLMUtils.stripMarkdown(""), "")
    }

    // MARK: - parseJSONArray

    /// 验证解析标准字符串数组 JSON
    func testParseJSONArrayStringArray() {
        let input = "[\"apple\", \"banana\", \"cherry\"]"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, ["apple", "banana", "cherry"])
    }

    /// 验证解析数字数组 JSON（转为字符串）
    func testParseJSONArrayIntArray() {
        let input = "[1, 0, 1]"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, ["1", "0", "1"])
    }

    /// 验证解析带 Markdown 代码块的 JSON 数组
    func testParseJSONArrayWithMarkdown() {
        let input = "```json\n[\"tag1\", \"tag2\"]\n```"
        let result = LLMUtils.parseJSONArray(input)
        XCTAssertEqual(result, ["tag1", "tag2"])
    }

    /// 验证无效 JSON 返回空数组
    func testParseJSONArrayInvalidJSON() {
        let result = LLMUtils.parseJSONArray("not json")
        XCTAssertTrue(result.isEmpty)
    }

    /// 验证空字符串返回空数组
    func testParseJSONArrayEmpty() {
        XCTAssertTrue(LLMUtils.parseJSONArray("").isEmpty)
    }

    /// 验证空数组 JSON
    func testParseJSONArrayEmptyArray() {
        let result = LLMUtils.parseJSONArray("[]")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - parseSmartIngest

    /// 验证解析有效的 SmartIngestResult JSON
    func testParseSmartIngestValid() throws {
        let json = """
        {
            "title": "测试标题",
            "compiled_content": "编译内容",
            "suggested_tags": ["tag1", "tag2"],
            "suggested_type": "concept",
            "related_titles": ["相关1"],
            "summary": "摘要"
        }
        """
        let result = LLMUtils.parseSmartIngest(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "测试标题")
        XCTAssertEqual(result?.compiledContent, "编译内容")
        XCTAssertEqual(result?.suggestedTags, ["tag1", "tag2"])
        XCTAssertEqual(result?.suggestedType, "concept")
        XCTAssertEqual(result?.relatedTitles, ["相关1"])
        XCTAssertEqual(result?.summary, "摘要")
    }

    /// 验证解析带 Markdown 代码块的 SmartIngestResult
    func testParseSmartIngestWithMarkdown() throws {
        let json = "```json\n{\"title\":null,\"compiled_content\":\"内容\",\"suggested_tags\":[],\"suggested_type\":\"raw\",\"related_titles\":[],\"summary\":\"\"}\n```"
        let result = LLMUtils.parseSmartIngest(json)
        XCTAssertNotNil(result)
        XCTAssertNil(result?.title)
        XCTAssertEqual(result?.compiledContent, "内容")
        XCTAssertEqual(result?.suggestedType, "raw")
    }

    /// 验证无效 JSON 返回 nil
    func testParseSmartIngestInvalid() {
        XCTAssertNil(LLMUtils.parseSmartIngest("invalid"))
    }

    /// 验证空字符串返回 nil
    func testParseSmartIngestEmpty() {
        XCTAssertNil(LLMUtils.parseSmartIngest(""))
    }

    // MARK: - parseRefactorSuggestions

    /// 验证解析有效的重构建议数组
    func testParseRefactorSuggestionsValid() throws {
        let json = """
        [
            {"type": "merge", "target": "页面A", "reason": "内容重复", "suggestion": "合并到页面B"},
            {"type": "rename", "target": "页面C", "reason": "名称不清晰", "suggestion": "重命名为页面D"}
        ]
        """
        let result = LLMUtils.parseRefactorSuggestions(json)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].type, "merge")
        XCTAssertEqual(result[0].target, "页面A")
        XCTAssertEqual(result[0].reason, "内容重复")
        XCTAssertEqual(result[1].type, "rename")
        XCTAssertEqual(result[1].target, "页面C")
    }

    /// 验证解析带 Markdown 代码块的重构建议
    func testParseRefactorSuggestionsWithMarkdown() {
        let json = "```json\n[{\"type\":\"split\",\"target\":\"X\",\"reason\":\"R\",\"suggestion\":\"S\"}]\n```"
        let result = LLMUtils.parseRefactorSuggestions(json)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, "split")
    }

    /// 验证无效 JSON 返回空数组
    func testParseRefactorSuggestionsInvalid() {
        XCTAssertTrue(LLMUtils.parseRefactorSuggestions("invalid").isEmpty)
    }

    /// 验证空字符串返回空数组
    func testParseRefactorSuggestionsEmpty() {
        XCTAssertTrue(LLMUtils.parseRefactorSuggestions("").isEmpty)
    }

    /// 验证空数组 JSON
    func testParseRefactorSuggestionsEmptyArray() {
        XCTAssertTrue(LLMUtils.parseRefactorSuggestions("[]").isEmpty)
    }

    // MARK: - extractContent

    /// 验证从标准 OpenAI 响应提取 content
    func testExtractContentStandard() {
        let response: [String: Any] = [
            "choices": [
                ["message": ["content": "Hello world"]]
            ]
        ]
        XCTAssertEqual(LLMUtils.extractContent(from: response), "Hello world")
    }

    /// 验证从推理模型响应提取 reasoning_content（DeepSeek v4 Pro）
    func testExtractContentReasoningModel() {
        let response: [String: Any] = [
            "choices": [
                ["message": ["reasoning_content": "推理结果"]]
            ]
        ]
        XCTAssertEqual(LLMUtils.extractContent(from: response), "推理结果")
    }

    /// 验证 content 优先于 reasoning_content
    func testExtractContentPrefersContent() {
        let response: [String: Any] = [
            "choices": [
                ["message": ["content": "标准内容", "reasoning_content": "推理内容"]]
            ]
        ]
        XCTAssertEqual(LLMUtils.extractContent(from: response), "标准内容")
    }

    /// 验证无 choices 时返回 nil
    func testExtractContentNoChoices() {
        let response: [String: Any] = [:]
        XCTAssertNil(LLMUtils.extractContent(from: response))
    }

    /// 验证空 choices 数组时返回 nil
    func testExtractContentEmptyChoices() {
        let response: [String: Any] = ["choices": []]
        XCTAssertNil(LLMUtils.extractContent(from: response))
    }

    /// 验证无 message 时返回 nil
    func testExtractContentNoMessage() {
        let response: [String: Any] = ["choices": [["index": 0]]]
        XCTAssertNil(LLMUtils.extractContent(from: response))
    }

    /// 验证 message 无 content 和 reasoning_content 时返回 nil
    func testExtractContentNoContentFields() {
        let response: [String: Any] = [
            "choices": [
                ["message": ["role": "assistant"]]
            ]
        ]
        XCTAssertNil(LLMUtils.extractContent(from: response))
    }
}

// MARK: - PromptRegistry 单元测试

final class PromptRegistryDomainTests: XCTestCase {

    // MARK: - Ingest.summary

    /// 验证 summary 提示词包含内容
    func testSummaryPromptContainsContent() {
        let prompt = PromptRegistry.Ingest.summary(content: "这是需要摘要的内容")
        XCTAssertTrue(prompt.contains("这是需要摘要的内容"))
    }

    /// 验证 summary 提示词包含前缀
    func testSummaryPromptContainsPrefix() {
        let prompt = PromptRegistry.Ingest.summary(content: "内容")
        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains("内容"))
    }

    /// 验证 summary 提示词空内容
    func testSummaryPromptEmptyContent() {
        let prompt = PromptRegistry.Ingest.summary(content: "")
        XCTAssertFalse(prompt.isEmpty)
    }

    // MARK: - Ingest.reverseQA

    /// 验证 reverseQA 提示词包含内容
    func testReverseQAPromptContainsContent() {
        let prompt = PromptRegistry.Ingest.reverseQA(content: "反向提问内容")
        XCTAssertTrue(prompt.contains("反向提问内容"))
    }

    /// 验证 reverseQA 提示词非空
    func testReverseQAPromptNotEmpty() {
        let prompt = PromptRegistry.Ingest.reverseQA(content: "test")
        XCTAssertFalse(prompt.isEmpty)
    }

    // MARK: - Structure.discoverLinks

    /// 验证 discoverLinks 提示词包含内容和标题
    func testDiscoverLinksPromptContainsContentAndTitles() {
        let prompt = PromptRegistry.Structure.discoverLinks(
            content: "笔记内容",
            existingTitles: ["标题A", "标题B"]
        )
        XCTAssertTrue(prompt.contains("笔记内容"))
        XCTAssertTrue(prompt.contains("标题A"))
        XCTAssertTrue(prompt.contains("标题B"))
    }

    /// 验证 discoverLinks 提示词空标题列表
    func testDiscoverLinksPromptEmptyTitles() {
        let prompt = PromptRegistry.Structure.discoverLinks(
            content: "内容",
            existingTitles: []
        )
        XCTAssertTrue(prompt.contains("内容"))
    }

    /// 验证 discoverLinks 提示词标题用逗号连接
    func testDiscoverLinksPromptTitlesJoinedByComma() {
        let prompt = PromptRegistry.Structure.discoverLinks(
            content: "x",
            existingTitles: ["A", "B", "C"]
        )
        XCTAssertTrue(prompt.contains("A, B, C"))
    }
}
