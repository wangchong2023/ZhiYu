//
//  PromptRegistryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 PromptRegistry 提示词组装逻辑的正确性。
//

import XCTest
@testable import ZhiYu

final class PromptRegistryTests: XCTestCase {

    // MARK: - Ingest.summary

    func testSummary_containsContent() {
        let content = "这是需要总结的内容"
        let result = PromptRegistry.Ingest.summary(content: content)
        XCTAssertTrue(result.contains(content))
    }

    func testSummary_containsPrefix() {
        let result = PromptRegistry.Ingest.summary(content: "test")
        XCTAssertTrue(result.hasPrefix(L10n.AI.Prompt.summaryPrefix))
    }

    func testSummary_format() {
        let content = "hello"
        let result = PromptRegistry.Ingest.summary(content: content)
        XCTAssertEqual(result, "\(L10n.AI.Prompt.summaryPrefix)\n\n\(content)")
    }

    func testSummary_emptyContent() {
        let result = PromptRegistry.Ingest.summary(content: "")
        XCTAssertTrue(result.hasSuffix("\n\n"))
    }

    // MARK: - Ingest.reverseQA

    func testReverseQA_containsContent() {
        let content = "源文本内容"
        let result = PromptRegistry.Ingest.reverseQA(content: content)
        XCTAssertTrue(result.contains(content))
    }

    func testReverseQA_containsPrefix() {
        let result = PromptRegistry.Ingest.reverseQA(content: "test")
        XCTAssertTrue(result.hasPrefix(L10n.AI.Prompt.reverseQAPrefix))
    }

    func testReverseQA_format() {
        let content = "source"
        let result = PromptRegistry.Ingest.reverseQA(content: content)
        XCTAssertEqual(result, "\(L10n.AI.Prompt.reverseQAPrefix)\n\n\(content)")
    }

    // MARK: - Structure.discoverLinks

    func testDiscoverLinks_containsTitles() {
        let titles = ["PageA", "PageB", "PageC"]
        let result = PromptRegistry.Structure.discoverLinks(content: "content", existingTitles: titles)
        for title in titles {
            XCTAssertTrue(result.contains(title), "结果应包含标题 '\(title)'")
        }
    }

    func testDiscoverLinks_containsContent() {
        let content = "笔记正文"
        let result = PromptRegistry.Structure.discoverLinks(content: content, existingTitles: ["T1"])
        XCTAssertTrue(result.contains(content))
    }

    func testDiscoverLinks_emptyTitles() {
        let result = PromptRegistry.Structure.discoverLinks(content: "c", existingTitles: [])
        let expected = "\(L10n.AI.Prompt.discoverLinksPrefix1)\(L10n.AI.Prompt.discoverLinksPrefix2)c"
        XCTAssertEqual(result, expected)
    }

    func testDiscoverLinks_singleTitle() {
        let result = PromptRegistry.Structure.discoverLinks(content: "c", existingTitles: ["Only"])
        let expected = "\(L10n.AI.Prompt.discoverLinksPrefix1)Only\(L10n.AI.Prompt.discoverLinksPrefix2)c"
        XCTAssertEqual(result, expected)
    }

    func testDiscoverLinks_emptyContent() {
        let result = PromptRegistry.Structure.discoverLinks(content: "", existingTitles: ["A", "B"])
        let expected = "\(L10n.AI.Prompt.discoverLinksPrefix1)A, B\(L10n.AI.Prompt.discoverLinksPrefix2)"
        XCTAssertEqual(result, expected)
    }
}
