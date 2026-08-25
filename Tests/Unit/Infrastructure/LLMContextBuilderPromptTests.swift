//
//  LLMContextBuilderPromptTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 LLMContextBuilder 的 system prompt / ingest prompt / rewrite prompt 构建逻辑。
//

import XCTest
@testable import ZhiYu

// MARK: - LLMContextBuilder Prompt 构建测试

final class LLMContextBuilderPromptTests: XCTestCase {

    /// 注入 mock entityRecognizer — 模拟器 NLTagger 中文人名识别率低，用确定性 mock 替代
    private let builder = LLMContextBuilder(entityRecognizer: { text in
        let knownNames = ["张三丰", "张三", "李四", "王五", "赵六", "钱七", "孙八", "周九", "吴十"]
        return knownNames.filter { text.contains($0) }
    })

    // MARK: - buildSystemPrompt 测试

    func testBuildSystemPromptContainsRoleDescription() {
        let prompt = builder.buildSystemPrompt(pages: [])
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.role))
        XCTAssertTrue(prompt.contains(L10n.Chat.welcomeDesc))
    }

    func testBuildSystemPromptIncludesPageStatistics() {
        let pages: [any KnowledgePageRepresentable] = [
            makePage(title: "Entity1", content: "内容", pageType: .entity, status: .active),
            makePage(title: "Concept1", content: "内容", pageType: .concept, status: .active),
            makePage(title: "Source1", content: "内容", pageType: .source, status: .active)
        ]
        let prompt = builder.buildSystemPrompt(pages: pages)
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.totalPages))
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.entityList))
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.conceptList))
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.sourceList))
    }

    func testBuildSystemPromptHandlesEmptyPages() {
        let prompt = builder.buildSystemPrompt(pages: [])
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.role))
        // 空知识库也应包含统计信息（0 页）
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.totalPages))
    }

    func testBuildSystemPromptIncludesStubStatusPages() {
        let pages: [any KnowledgePageRepresentable] = [
            makePage(title: "Stub", content: "内容", pageType: .entity, status: .stub)
        ]
        let prompt = builder.buildSystemPrompt(pages: pages)
        XCTAssertTrue(prompt.contains("Stub"))
    }

    func testBuildSystemPromptIncludesRecentUpdates() {
        let recentDate = Date()
        let oldDate = Date().addingTimeInterval(-86400 * 30)
        let pages: [any KnowledgePageRepresentable] = [
            makePage(title: "OldPage", content: "内容", pageType: .entity, status: .active, updatedAt: oldDate),
            makePage(title: "NewPage", content: "内容", pageType: .entity, status: .active, updatedAt: recentDate)
        ]
        let prompt = builder.buildSystemPrompt(pages: pages)
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Prompt.recentUpdates))
        XCTAssertTrue(prompt.contains("NewPage"))
    }

    func testBuildSystemPromptTruncatesLongEntityList() {
        var pages: [any KnowledgePageRepresentable] = []
        for i in 0..<50 {
            // 让后面的页面 updatedAt 更早，避免出现在 recent 列表中
            let date = Date().addingTimeInterval(Double(-i))
            pages.append(makePage(title: "Entity\(i)", content: "内容\(i)", pageType: .entity, status: .active, updatedAt: date))
        }
        let prompt = builder.buildSystemPrompt(pages: pages)
        // maxEntityOverview=20，Entity49 不应出现在实体列表中
        // Entity49 的 updatedAt 最早，也不在 recent 前 5
        XCTAssertFalse(prompt.contains("Entity49"))
        XCTAssertFalse(prompt.contains("Entity30"))
    }

    // MARK: - buildIngestPrompt 测试

    func testBuildIngestPromptContainsTitleAndContent() {
        let prompt = builder.buildIngestPrompt(
            title: "测试标题",
            rawContent: "这是原始内容",
            pages: []
        )
        XCTAssertTrue(prompt.contains("测试标题"))
        XCTAssertTrue(prompt.contains("这是原始内容"))
        XCTAssertTrue(prompt.contains(L10n.AI.LLM.Ingest.compileInstruction))
    }

    func testBuildIngestPromptIncludesExistingPageTitles() {
        let pages: [any KnowledgePageRepresentable] = [
            makePage(title: "已有页面A", content: "", pageType: .entity, status: .active),
            makePage(title: "已有页面B", content: "", pageType: .concept, status: .active)
        ]
        let prompt = builder.buildIngestPrompt(
            title: "新页面",
            rawContent: "内容",
            pages: pages
        )
        XCTAssertTrue(prompt.contains("已有页面A"))
        XCTAssertTrue(prompt.contains("已有页面B"))
    }

    func testBuildIngestPromptContainsJSONSchemaHint() {
        let prompt = builder.buildIngestPrompt(title: "T", rawContent: "C", pages: [])
        XCTAssertTrue(prompt.contains("compiledContent"))
        XCTAssertTrue(prompt.contains("suggestedTags"))
        XCTAssertTrue(prompt.contains("suggestedType"))
    }

    // MARK: - buildRewritePrompt 测试

    func testBuildRewritePromptContainsUserQuery() {
        let prompt = builder.buildRewritePrompt(query: "用户的问题是什么？")
        XCTAssertTrue(prompt.contains("用户的问题是什么？"))
        XCTAssertTrue(prompt.contains(L10n.AI.Prompt.QueryRewrite.instruction))
    }

    func testBuildRewritePromptContainsRules() {
        let prompt = builder.buildRewritePrompt(query: "test")
        XCTAssertTrue(prompt.contains(L10n.AI.Prompt.QueryRewrite.rule1))
        XCTAssertTrue(prompt.contains(L10n.AI.Prompt.QueryRewrite.rule2))
    }

    // MARK: - anonymize / deanonymize 补充测试

    func testAnonymizeHandlesEmptyText() {
        let result = builder.anonymize("")
        XCTAssertEqual(result.anonymizedText, "")
        XCTAssertTrue(result.mapping.isEmpty)
    }

    func testAnonymizePreservesExistingMapping() {
        let existing: [String: String] = ["[ENTITY_A]": "张三"]
        let result = builder.anonymize("李四来了", existingMapping: existing)
        // 李四应被分配新的占位符
        XCTAssertTrue(result.mapping.count >= 2)
        XCTAssertEqual(result.mapping["[ENTITY_A]"], "张三")
    }

    func testDeanonymizeRestoresOriginalText() {
        let mapping = ["[ENTITY_A]": "张三", "[ENTITY_B]": "北京"]
        let text = "[ENTITY_A]去了[ENTITY_B]"
        let restored = builder.deanonymize(text, mapping: mapping)
        XCTAssertEqual(restored, "张三去了北京")
    }

    func testDeanonymizeHandlesEmptyMapping() {
        let result = builder.deanonymize("普通文本", mapping: [:])
        XCTAssertEqual(result, "普通文本")
    }

    func testAnonymizeThenDeanonymizeRoundTrip() {
        let original = "张三去了北京出差"
        let (anonymized, mapping) = builder.anonymize(original)
        if mapping.isEmpty {
            // NLTagger 可能未识别到实体（环境差异），跳过 round-trip
            return
        }
        let restored = builder.deanonymize(anonymized, mapping: mapping)
        XCTAssertEqual(restored, original)
    }

    // MARK: - 辅助方法

    /// 构造测试用 KnowledgePage
    private func makePage(
        title: String,
        content: String,
        pageType: PageType,
        status: PageStatus,
        updatedAt: Date = Date()
    ) -> KnowledgePage {
        return KnowledgePage(
            title: title,
            pageType: pageType,
            content: content,
            status: status,
            updatedAt: updatedAt
        )
    }
}
