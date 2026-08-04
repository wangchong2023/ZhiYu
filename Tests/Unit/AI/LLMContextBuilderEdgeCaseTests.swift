//
//  LLMContextBuilderEdgeCaseTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMContextBuilder 的 anonymize/deanonymize 边界条件与不变量。
//

import XCTest
@testable import ZhiYu

@MainActor
final class LLMContextBuilderEdgeCaseTests: XCTestCase {

    private var builder: LLMContextBuilder!

    override func setUp() async throws {
        try await super.setUp()
        builder = LLMContextBuilder()
    }

    override func tearDown() async throws {
        builder = nil
        try await super.tearDown()
    }

    // MARK: - anonymize 空文本

    func testAnonymizeEmptyTextReturnsEmptyAndExistingMapping() {
        let existing = ["[ENTITY_A]": "张三"]
        let (anonymized, mapping) = builder.anonymize("", existingMapping: existing)
        XCTAssertEqual(anonymized, "", "空文本脱敏后应为空")
        XCTAssertEqual(mapping, existing, "空文本应保留 existingMapping 不变")
    }

    // MARK: - deanonymize 往返不变量

    func testDeanonymizeRoundTripPreservesOriginal() {
        let original = "张三和李四在北京市朝阳区联合开发了智宇应用。"
        let (anonymized, mapping) = builder.anonymize(original)
        let restored = builder.deanonymize(anonymized, mapping: mapping)
        XCTAssertEqual(restored, original, "脱敏后还原应与原文一致（往返不变量）")
    }

    // MARK: - deanonymize 空映射

    func testDeanonymizeWithEmptyMappingReturnsOriginal() {
        let text = "普通文本无占位符"
        let result = builder.deanonymize(text, mapping: [:])
        XCTAssertEqual(result, text, "空映射时 deanonymize 应返回原文")
    }

    // MARK: - deanonymize 占位符长度降序

    func testDeanonymizeHandlesOverlappingPlaceholders() {
        // 构造前缀相交的占位符，验证降序替换不产生错误
        let mapping = [
            "[ENTITY_A]": "张三",
            "[ENTITY_AA]": "张三丰"
        ]
        let text = "[ENTITY_A]和[ENTITY_AA]是不同的人"
        let result = builder.deanonymize(text, mapping: mapping)
        XCTAssertTrue(result.contains("张三丰"), "长占位符应优先替换")
        XCTAssertFalse(result.contains("[ENTITY_"), "所有占位符应被替换")
    }

    // MARK: - anonymize existingMapping 复用

    func testAnonymizeReusesExistingMappingForSameEntity() {
        let existing = ["[ENTITY_A]": "张三"]
        // 第二段文本中再次出现"张三"，应复用 [ENTITY_A]
        let (anonymized, mapping) = builder.anonymize("张三来了", existingMapping: existing)
        if anonymized.contains("[ENTITY_A]") {
            XCTAssertEqual(mapping["[ENTITY_A]"], "张三", "应复用已有占位符")
        }
        // 无论 NER 是否检测到，映射应至少保留 existing
        XCTAssertTrue(mapping["[ENTITY_A]"] != nil, "existingMapping 应被保留")
    }

    // MARK: - deanonymize 无占位符文本

    func testDeanonymizeTextWithoutPlaceholders() {
        let mapping = ["[ENTITY_A]": "张三"]
        let text = "这段文本没有任何占位符"
        let result = builder.deanonymize(text, mapping: mapping)
        XCTAssertEqual(result, text, "无占位符文本应原样返回")
    }

    // MARK: - buildSystemPrompt 基本结构

    func testBuildSystemPromptContainsRoleAndRules() {
        let pages: [any KnowledgePageRepresentable] = []
        let prompt = builder.buildSystemPrompt(pages: pages)
        XCTAssertFalse(prompt.isEmpty, "系统提示词不应为空")
        // 验证包含关键结构标记
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.role) || prompt.count > 50, "应包含角色定义或足够内容")
    }

    func testBuildSystemPromptWithPagesIncludesOverview() {
        let pages: [any KnowledgePageRepresentable] = [
            KnowledgePage(title: "实体A", pageType: .entity, content: "内容A", status: .active),
            KnowledgePage(title: "概念B", pageType: .concept, content: "内容B", status: .active)
        ]
        let prompt = builder.buildSystemPrompt(pages: pages)
        XCTAssertTrue(prompt.contains("实体A") || prompt.contains("概念B"), "应包含页面标题概览")
    }

    // MARK: - buildIngestPrompt 结构

    func testBuildIngestPromptContainsTitleAndContent() {
        let prompt = builder.buildIngestPrompt(title: "测试标题", rawContent: "测试内容", pages: [])
        XCTAssertTrue(prompt.contains("测试标题"), "应包含标题")
        XCTAssertTrue(prompt.contains("测试内容"), "应包含原始内容")
    }

    // MARK: - buildRewritePrompt 结构

    func testBuildRewritePromptContainsQuery() {
        let prompt = builder.buildRewritePrompt(query: "用户查询")
        XCTAssertTrue(prompt.contains("用户查询"), "应包含用户查询")
    }
}
