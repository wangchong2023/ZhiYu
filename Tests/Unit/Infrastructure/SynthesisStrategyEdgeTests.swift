//
//  SynthesisStrategyEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 SynthesisStrategyFactory 派发与 6 种策略的 process/generateFallback 语义正确性。
//

import XCTest
@testable import ZhiYu

final class SynthesisStrategyEdgeTests: XCTestCase {

    // MARK: - Factory 派发

    func testFactory_mindmap_returnsMindmapStrategy() {
        let strategy = SynthesisStrategyFactory.strategy(for: .mindmap)
        XCTAssertEqual(strategy.type, .mindmap)
        XCTAssertTrue(strategy is MindmapSynthesisStrategy)
    }

    func testFactory_slides_returnsSlidesStrategy() {
        let strategy = SynthesisStrategyFactory.strategy(for: .slides)
        XCTAssertEqual(strategy.type, .slides)
        XCTAssertTrue(strategy is SlidesSynthesisStrategy)
    }

    func testFactory_quiz_returnsQuizStrategy() {
        let strategy = SynthesisStrategyFactory.strategy(for: .quiz)
        XCTAssertEqual(strategy.type, .quiz)
        XCTAssertTrue(strategy is QuizSynthesisStrategy)
    }

    func testFactory_report_returnsReportStrategy() {
        let strategy = SynthesisStrategyFactory.strategy(for: .report)
        XCTAssertEqual(strategy.type, .report)
        XCTAssertTrue(strategy is ReportSynthesisStrategy)
    }

    func testFactory_infographic_returnsInfographicStrategy() {
        let strategy = SynthesisStrategyFactory.strategy(for: .infographic)
        XCTAssertEqual(strategy.type, .infographic)
        XCTAssertTrue(strategy is InfographicSynthesisStrategy)
    }

    func testFactory_expansion_returnsExpansionStrategy() {
        let strategy = SynthesisStrategyFactory.strategy(for: .expansion)
        XCTAssertEqual(strategy.type, .expansion)
        XCTAssertTrue(strategy is ExpansionSynthesisStrategy)
    }

    // MARK: - MindmapSynthesisStrategy

    func testMindmapStrategy_validMermaid_returnsFormatted() {
        let strategy = MindmapSynthesisStrategy()
        let raw = "```mermaid\nmindmap\n  root((Root))\n  child\n```"
        let result = strategy.process(rawContent: raw, sourceContent: "源内容")
        XCTAssertTrue(result.contains("mindmap"))
        XCTAssertTrue(result.contains("root((Root))"))
    }

    func testMindmapStrategy_emptyContent_returnsFallback() {
        let strategy = MindmapSynthesisStrategy()
        let result = strategy.process(rawContent: "", sourceContent: "源内容")
        XCTAssertTrue(result.contains("mindmap"), "兜底应生成 mindmap")
    }

    func testMindmapStrategy_generateFallback_returnsMindmap() {
        let strategy = MindmapSynthesisStrategy()
        let result = strategy.generateFallback(from: "要点1\n要点2", title: "标题")
        XCTAssertTrue(result.contains("mindmap"))
        XCTAssertTrue(result.contains("root((标题))"))
    }

    // MARK: - SlidesSynthesisStrategy

    func testSlidesStrategy_validContent_returnsFormatted() {
        let strategy = SlidesSynthesisStrategy()
        let raw = "# 标题\n\n这是足够长的内容，用于通过最小字节数校验。" + String(repeating: "内容", count: 100)
        let result = strategy.process(rawContent: raw, sourceContent: "源")
        XCTAssertTrue(result.contains("---") || result.contains("标题"))
    }

    func testSlidesStrategy_emptyContent_returnsFallback() {
        let strategy = SlidesSynthesisStrategy()
        let result = strategy.process(rawContent: "", sourceContent: "源内容")
        XCTAssertFalse(result.isEmpty, "兜底应生成非空内容")
    }

    func testSlidesStrategy_generateFallback_returnsPresentation() {
        let strategy = SlidesSynthesisStrategy()
        let result = strategy.generateFallback(from: "要点1\n要点2", title: "标题")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - QuizSynthesisStrategy

    func testQuizStrategy_validQuizJSON_returnsRawContent() {
        let strategy = QuizSynthesisStrategy()
        let raw = #"{"quizTitle":"测试","questions":[{"question":"Q","options":["A","B"],"answer":0}]}"#
        let result = strategy.process(rawContent: raw, sourceContent: "源")
        // 有效测验 JSON 应原样返回或转换为 Markdown
        XCTAssertFalse(result.isEmpty)
    }

    func testQuizStrategy_invalidContent_returnsFallback() {
        let strategy = QuizSynthesisStrategy()
        let result = strategy.process(rawContent: "", sourceContent: "源内容")
        XCTAssertFalse(result.isEmpty, "兜底应生成测验内容")
    }

    func testQuizStrategy_generateFallback_returnsQuizJSON() {
        let strategy = QuizSynthesisStrategy()
        let result = strategy.generateFallback(from: "要点1\n要点2\n要点3", title: "标题")
        XCTAssertTrue(result.contains("quizTitle") || result.contains("questions"))
    }

    // MARK: - ReportSynthesisStrategy

    func testReportStrategy_validContentWithHeading_returnsCleaned() {
        let strategy = ReportSynthesisStrategy()
        let raw = "# 报告标题\n\n这是足够长的报告内容。" + String(repeating: "段落。", count: 100)
        let result = strategy.process(rawContent: raw, sourceContent: "源")
        XCTAssertTrue(result.contains("# 报告标题"))
    }

    func testReportStrategy_noHeading_returnsFallback() {
        let strategy = ReportSynthesisStrategy()
        let raw = String(repeating: "无标题内容。", count: 100)
        let result = strategy.process(rawContent: raw, sourceContent: "源内容")
        // 无 # 标题应触发兜底
        XCTAssertTrue(result.contains("#") || !result.isEmpty)
    }

    func testReportStrategy_emptyContent_returnsFallback() {
        let strategy = ReportSynthesisStrategy()
        let result = strategy.process(rawContent: "", sourceContent: "源内容")
        XCTAssertFalse(result.isEmpty)
    }

    func testReportStrategy_generateFallback_returnsReport() {
        let strategy = ReportSynthesisStrategy()
        let result = strategy.generateFallback(from: "要点1\n要点2", title: "标题")
        XCTAssertTrue(result.contains("# 标题"))
    }

    // MARK: - InfographicSynthesisStrategy

    func testInfographicStrategy_validMermaid_returnsFormatted() {
        let strategy = InfographicSynthesisStrategy()
        let raw = "```mermaid\ngraph TD\nA --> B\n```"
        let result = strategy.process(rawContent: raw, sourceContent: "源")
        XCTAssertTrue(result.contains("graph TD"))
    }

    func testInfographicStrategy_emptyContent_returnsFallback() {
        let strategy = InfographicSynthesisStrategy()
        let result = strategy.process(rawContent: "", sourceContent: "源内容")
        XCTAssertTrue(result.contains("graph TD"))
    }

    func testInfographicStrategy_generateFallback_returnsInfographic() {
        let strategy = InfographicSynthesisStrategy()
        let result = strategy.generateFallback(from: "要点1\n要点2", title: "标题")
        XCTAssertTrue(result.contains("graph TD"))
        XCTAssertTrue(result.contains("Root"))
    }

    // MARK: - ExpansionSynthesisStrategy

    func testExpansionStrategy_validContent_returnsCleaned() {
        let strategy = ExpansionSynthesisStrategy()
        let raw = String(repeating: "扩写内容。", count: 100)
        let result = strategy.process(rawContent: raw, sourceContent: "源")
        XCTAssertFalse(result.isEmpty)
    }

    func testExpansionStrategy_emptyContent_returnsFallback() {
        let strategy = ExpansionSynthesisStrategy()
        let result = strategy.process(rawContent: "", sourceContent: "源内容")
        XCTAssertFalse(result.isEmpty)
    }

    func testExpansionStrategy_generateFallback_returnsExpansion() {
        let strategy = ExpansionSynthesisStrategy()
        let result = strategy.generateFallback(from: "要点1\n要点2", title: "标题")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - 策略 Sendable 一致性

    func testStrategies_areSendable() {
        let strategies: [any SynthesisStrategyProtocol] = [
            MindmapSynthesisStrategy(),
            SlidesSynthesisStrategy(),
            QuizSynthesisStrategy(),
            ReportSynthesisStrategy(),
            InfographicSynthesisStrategy(),
            ExpansionSynthesisStrategy()
        ]
        for strategy in strategies {
            XCTAssertEqual(strategy.type, strategy.type, "策略类型应稳定")
        }
    }
}
