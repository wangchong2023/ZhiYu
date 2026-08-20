//
//  DomainEnumsTests.swift
//  ZhiYuTests
//
//  系统层级：[L1.5] 领域层测试
//  核心职责：验证 Domain/Models 中枚举类型的 case 完整性、rawValue 映射、
//           CaseIterable 一致性及计算属性正确性。
//

import XCTest
@testable import ZhiYu

// MARK: - ChunkType 单元测试

final class ChunkTypeTests: XCTestCase {

    /// 验证 ChunkType 所有 case 的 rawValue
    func testChunkTypeRawValues() {
        XCTAssertEqual(ChunkType.regular.rawValue, "regular")
        XCTAssertEqual(ChunkType.summary.rawValue, "summary")
        XCTAssertEqual(ChunkType.child.rawValue, "child")
        XCTAssertEqual(ChunkType.qaPair.rawValue, "qa_pair")
        XCTAssertEqual(ChunkType.paragraph.rawValue, "paragraph")
        XCTAssertEqual(ChunkType.text.rawValue, "text")
    }

    /// 验证 ChunkType CaseIterable 包含全部 6 个 case
    func testChunkTypeCaseIterable() {
        XCTAssertEqual(ChunkType.allCases.count, 6)
        XCTAssertTrue(ChunkType.allCases.contains(.regular))
        XCTAssertTrue(ChunkType.allCases.contains(.qaPair))
    }

    /// 验证 ChunkType Codable 往返
    func testChunkTypeCodableRoundTrip() throws {
        let original: ChunkType = .qaPair
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChunkType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    /// 验证 ChunkType 从 rawValue 初始化
    func testChunkTypeFromRawValue() {
        XCTAssertEqual(ChunkType(rawValue: "regular"), .regular)
        XCTAssertEqual(ChunkType(rawValue: "qa_pair"), .qaPair)
        XCTAssertNil(ChunkType(rawValue: "unknown"))
    }
}

// MARK: - PageType 单元测试

final class PageTypeTests: XCTestCase {

    /// 验证 PageType 所有 case 的 rawValue
    func testPageTypeRawValues() {
        XCTAssertEqual(PageType.concept.rawValue, "concept")
        XCTAssertEqual(PageType.entity.rawValue, "entity")
        XCTAssertEqual(PageType.source.rawValue, "source")
        XCTAssertEqual(PageType.comparison.rawValue, "comparison")
        XCTAssertEqual(PageType.raw.rawValue, "raw")
    }

    /// 验证 PageType CaseIterable
    func testPageTypeCaseIterable() {
        XCTAssertEqual(PageType.allCases.count, 5)
    }

    /// 验证 PageType Identifiable
    func testPageTypeIdentifiable() {
        XCTAssertEqual(PageType.concept.id, "concept")
        XCTAssertEqual(PageType.entity.id, "entity")
    }

    /// 验证 PageType folderName 映射（通过 KnowledgePage 间接验证）
    func testPageTypeFolderNameViaKnowledgePage() {
        let conceptPage = KnowledgePage(title: "概念", pageType: .concept)
        XCTAssertEqual(conceptPage.folderName, "concepts")
        let entityPage = KnowledgePage(title: "实体", pageType: .entity)
        XCTAssertEqual(entityPage.folderName, "entities")
        let sourcePage = KnowledgePage(title: "来源", pageType: .source)
        XCTAssertEqual(sourcePage.folderName, "sources")
        let comparisonPage = KnowledgePage(title: "比较", pageType: .comparison)
        XCTAssertEqual(comparisonPage.folderName, "comparisons")
        let rawPage = KnowledgePage(title: "原始", pageType: .raw)
        XCTAssertEqual(rawPage.folderName, "raw")
    }
}

// MARK: - PageStatus 单元测试

final class PageStatusTests: XCTestCase {

    /// 验证 PageStatus 所有 case 的 rawValue
    func testPageStatusRawValues() {
        XCTAssertEqual(PageStatus.active.rawValue, "active")
        XCTAssertEqual(PageStatus.stub.rawValue, "stub")
        XCTAssertEqual(PageStatus.needsUpdate.rawValue, "needs-update")
        XCTAssertEqual(PageStatus.deprecated.rawValue, "deprecated")
    }

    /// 验证 PageStatus CaseIterable
    func testPageStatusCaseIterable() {
        XCTAssertEqual(PageStatus.allCases.count, 4)
    }

    /// 验证 PageStatus Codable 往返
    func testPageStatusCodableRoundTrip() throws {
        let original: PageStatus = .needsUpdate
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PageStatus.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - Confidence 单元测试

final class ConfidenceTests: XCTestCase {

    /// 验证 Confidence 所有 case 的 rawValue
    func testConfidenceRawValues() {
        XCTAssertEqual(Confidence.high.rawValue, "high")
        XCTAssertEqual(Confidence.medium.rawValue, "medium")
        XCTAssertEqual(Confidence.low.rawValue, "low")
    }

    /// 验证 Confidence CaseIterable
    func testConfidenceCaseIterable() {
        XCTAssertEqual(Confidence.allCases.count, 3)
    }

    /// 验证 Confidence Codable 往返
    func testConfidenceCodableRoundTrip() throws {
        let original: Confidence = .high
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Confidence.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - AppTab 单元测试

final class AppTabTests: XCTestCase {

    /// 验证 AppTab 所有 case 的 rawValue
    func testAppTabRawValues() {
        XCTAssertEqual(AppTab.knowledge.rawValue, "knowledge")
        XCTAssertEqual(AppTab.chat.rawValue, "chat")
        XCTAssertEqual(AppTab.ingest.rawValue, "ingest")
        XCTAssertEqual(AppTab.synthesis.rawValue, "synthesis")
        XCTAssertEqual(AppTab.graph.rawValue, "graph")
    }

    /// 验证 AppTab CaseIterable 包含全部 5 个 case
    func testAppTabCaseIterable() {
        XCTAssertEqual(AppTab.allCases.count, 5)
    }

    /// 验证 AppTab 从 rawValue 初始化
    func testAppTabFromRawValue() {
        XCTAssertEqual(AppTab(rawValue: "knowledge"), .knowledge)
        XCTAssertEqual(AppTab(rawValue: "chat"), .chat)
        XCTAssertNil(AppTab(rawValue: "unknown"))
    }
}

// MARK: - ToolItem 单元测试

final class ToolItemTests: XCTestCase {

    /// 验证 ToolItem 所有 case 的 rawValue
    func testToolItemRawValues() {
        XCTAssertEqual(ToolItem.pageList.rawValue, "index")
        XCTAssertEqual(ToolItem.dashboard.rawValue, "dashboard")
        XCTAssertEqual(ToolItem.tagCloud.rawValue, "tagCloud")
        XCTAssertEqual(ToolItem.taskCenter.rawValue, "chat")
        XCTAssertEqual(ToolItem.chat.rawValue, "chat_ai")
        XCTAssertEqual(ToolItem.synthesis.rawValue, "synthesis")
        XCTAssertEqual(ToolItem.weeklyReport.rawValue, "weeklyReport")
        XCTAssertEqual(ToolItem.log.rawValue, "log")
        XCTAssertEqual(ToolItem.collab.rawValue, "collab")
        XCTAssertEqual(ToolItem.pluginMarket.rawValue, "pluginMarket")
        XCTAssertEqual(ToolItem.search.rawValue, "search")
        XCTAssertEqual(ToolItem.ingest.rawValue, "ingest")
        XCTAssertEqual(ToolItem.graph.rawValue, "graph")
        XCTAssertEqual(ToolItem.lint.rawValue, "lint")
        XCTAssertEqual(ToolItem.healthCheck.rawValue, "healthCheck")
        XCTAssertEqual(ToolItem.sources.rawValue, "sources")
    }

    /// 验证 ToolItem CaseIterable 包含全部 16 个 case
    func testToolItemCaseIterable() {
        XCTAssertEqual(ToolItem.allCases.count, 16)
    }

    /// 验证 ToolItem 从 rawValue 初始化
    func testToolItemFromRawValue() {
        XCTAssertEqual(ToolItem(rawValue: "index"), .pageList)
        XCTAssertEqual(ToolItem(rawValue: "chat_ai"), .chat)
        XCTAssertNil(ToolItem(rawValue: "nonexistent"))
    }
}

// MARK: - SynthesisControlOptions 单元测试

final class SynthesisControlOptionsTests: XCTestCase {

    /// 验证 SynthesisControlOptions init（含默认值）
    func testSynthesisControlOptionsInitWithDefaults() {
        let options = SynthesisControlOptions()
        XCTAssertEqual(options.depth, .standard)
        XCTAssertEqual(options.audience, .professional)
        XCTAssertEqual(options.tone, .professional)
        XCTAssertEqual(options.customPrompt, "")
    }

    /// 验证 SynthesisControlOptions 带全部参数 init
    func testSynthesisControlOptionsInitWithAllParameters() {
        let options = SynthesisControlOptions(
            depth: .detailed,
            audience: .beginner,
            tone: .casual,
            customPrompt: "自定义指令"
        )
        XCTAssertEqual(options.depth, .detailed)
        XCTAssertEqual(options.audience, .beginner)
        XCTAssertEqual(options.tone, .casual)
        XCTAssertEqual(options.customPrompt, "自定义指令")
    }

    /// 验证 Depth 枚举 CaseIterable
    func testDepthCaseIterable() {
        XCTAssertEqual(SynthesisControlOptions.Depth.allCases.count, 3)
        XCTAssertTrue(SynthesisControlOptions.Depth.allCases.contains(.concise))
        XCTAssertTrue(SynthesisControlOptions.Depth.allCases.contains(.standard))
        XCTAssertTrue(SynthesisControlOptions.Depth.allCases.contains(.detailed))
    }

    /// 验证 Audience 枚举 CaseIterable
    func testAudienceCaseIterable() {
        XCTAssertEqual(SynthesisControlOptions.Audience.allCases.count, 3)
    }

    /// 验证 Tone 枚举 CaseIterable
    func testToneCaseIterable() {
        XCTAssertEqual(SynthesisControlOptions.Tone.allCases.count, 3)
    }

    /// 验证 SynthesisControlOptions Equatable
    func testSynthesisControlOptionsEquality() {
        let a = SynthesisControlOptions()
        let b = SynthesisControlOptions()
        XCTAssertEqual(a, b)
    }

    /// 验证不同 depth 的 SynthesisControlOptions 不相等
    func testSynthesisControlOptionsInequality() {
        let a = SynthesisControlOptions(depth: .concise)
        let b = SynthesisControlOptions(depth: .detailed)
        XCTAssertNotEqual(a, b)
    }
}
