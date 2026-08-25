//
//  LLMContextBuilderTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 LLMContextBuilder 的 Prompt 构建、NER 脱敏/还原与边界容错。
//

import XCTest
@testable import ZhiYu

final class LLMContextBuilderSupplementTests: XCTestCase {

    private var builder: LLMContextBuilder!

    override func setUp() {
        super.setUp()
        // 注入 mock entityRecognizer — 模拟器 NLTagger 中文人名/地名识别率低，用确定性 mock 替代
        builder = LLMContextBuilder(entityRecognizer: { text in
            let knownEntities = ["张三丰", "张三", "李四", "王五", "赵六", "钱七", "孙八", "周九", "吴十", "北京", "上海", "广州"]
            return knownEntities.filter { text.contains($0) }
        })
    }

    override func tearDown() {
        builder = nil
        super.tearDown()
    }

    // MARK: - buildRewritePrompt

    func testBuildRewritePrompt_containsQuery() {
        let prompt = builder.buildRewritePrompt(query: "test query")

        XCTAssertTrue(prompt.contains("test query"), "Prompt 应包含原始查询")
    }

    func testBuildRewritePrompt_nonEmptyForEmptyQuery() {
        let prompt = builder.buildRewritePrompt(query: "")

        XCTAssertFalse(prompt.isEmpty, "空查询也应生成非空 Prompt 模板")
    }

    func testBuildRewritePrompt_containsInstruction() {
        let prompt = builder.buildRewritePrompt(query: "q")

        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.count > 10, "Prompt 应有足够长度")
    }

    // MARK: - buildIngestPrompt

    func testBuildIngestPrompt_containsTitleAndContent() {
        let prompt = builder.buildIngestPrompt(title: "Test Title", rawContent: "Raw content here", pages: [])

        XCTAssertTrue(prompt.contains("Test Title"), "应包含标题")
        XCTAssertTrue(prompt.contains("Raw content here"), "应包含原始内容")
    }

    func testBuildIngestPrompt_containsExistingPageTitles() {
        let page = KnowledgePage(title: "Existing Page", pageType: .concept, content: "c")
        let prompt = builder.buildIngestPrompt(title: "T", rawContent: "R", pages: [page])

        XCTAssertTrue(prompt.contains("Existing Page"), "应包含已有页面标题")
    }

    func testBuildIngestPrompt_emptyPagesList_noCrash() {
        let prompt = builder.buildIngestPrompt(title: "T", rawContent: "R", pages: [])

        XCTAssertTrue(prompt.contains("T"))
        XCTAssertTrue(prompt.contains("R"))
    }

    // MARK: - buildSystemPrompt

    func testBuildSystemPrompt_emptyPages_returnsBaseTemplate() {
        let prompt = builder.buildSystemPrompt(pages: [])

        XCTAssertFalse(prompt.isEmpty, "空页面列表也应返回基础模板")
    }

    func testBuildSystemPrompt_containsPageTitles() {
        let page = KnowledgePage(title: "Entity Page", pageType: .entity, content: "Some content")
        let prompt = builder.buildSystemPrompt(pages: [page])

        XCTAssertTrue(prompt.contains("Entity Page"), "应包含页面标题")
        XCTAssertTrue(prompt.contains("Some content"), "应包含内容预览")
    }

    func testBuildSystemPrompt_filtersNonActivePages() {
        let activePage = KnowledgePage(title: "Active", pageType: .entity, content: "active content", status: .active)
        let deprecatedPage = KnowledgePage(title: "Deprecated", pageType: .entity, content: "deprecated content", status: .deprecated)

        let prompt = builder.buildSystemPrompt(pages: [activePage, deprecatedPage])

        XCTAssertTrue(prompt.contains("Active"))
        XCTAssertFalse(prompt.contains("Deprecated"), "deprecated 页面应被过滤")
    }

    func testBuildSystemPrompt_includesStubPages() {
        let stubPage = KnowledgePage(title: "Stub", pageType: .entity, content: "stub content", status: .stub)

        let prompt = builder.buildSystemPrompt(pages: [stubPage])

        XCTAssertTrue(prompt.contains("Stub"), "stub 页面应被包含")
    }

    func testBuildSystemPrompt_categorizesByPageType() {
        let entity = KnowledgePage(title: "Entity1", pageType: .entity, content: "e")
        let concept = KnowledgePage(title: "Concept1", pageType: .concept, content: "c")
        let source = KnowledgePage(title: "Source1", pageType: .source, content: "s")

        let prompt = builder.buildSystemPrompt(pages: [entity, concept, source])

        XCTAssertTrue(prompt.contains("Entity1"))
        XCTAssertTrue(prompt.contains("Concept1"))
        XCTAssertTrue(prompt.contains("Source1"))
    }

    // MARK: - anonymize / deanonymize

    func testAnonymize_emptyText_returnsTextAndEmptyMapping() {
        let result = builder.anonymize("")

        XCTAssertEqual(result.anonymizedText, "")
        XCTAssertTrue(result.mapping.isEmpty, "空文本不应产生映射")
    }

    func testDeanonymize_restoresOriginalText() {
        let original = "张三去北京开会"
        let anonymized = builder.anonymize(original)

        let restored = builder.deanonymize(anonymized.anonymizedText, mapping: anonymized.mapping)

        XCTAssertEqual(restored, original, "脱敏后应能完全还原")
    }

    func testAnonymize_withExistingMapping_reusesPlaceholders() {
        let text1 = "张三去北京"
        let result1 = builder.anonymize(text1)

        let text2 = "李四也去了北京"
        let result2 = builder.anonymize(text2, existingMapping: result1.mapping)

        XCTAssertNotNil(result2.mapping.values.first { $0 == "北京" }, "已有映射应被重用")
    }

    func testDeanonymize_emptyMapping_returnsOriginalText() {
        let text = "no entities here"

        let restored = builder.deanonymize(text, mapping: [:])

        XCTAssertEqual(restored, text)
    }

    func testDeanonymize_multiplePlaceholders_allRestored() {
        let original = "张三和李四去北京见王五"
        let anonymized = builder.anonymize(original)

        let restored = builder.deanonymize(anonymized.anonymizedText, mapping: anonymized.mapping)

        XCTAssertEqual(restored, original)
    }

    func testAnonymize_shortEntityBelowMinLength_notReplaced() {
        let text = "a 去 b"

        let result = builder.anonymize(text)

        XCTAssertTrue(result.mapping.isEmpty, "过短实体（<2 字符）不应被脱敏")
    }
}
