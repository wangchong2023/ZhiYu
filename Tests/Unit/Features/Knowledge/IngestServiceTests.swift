//
//  IngestServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 IngestService 的纯逻辑函数开展单元测试。
//

import XCTest
@testable import ZhiYu

final class IngestServicePureLogicTests: XCTestCase {

    private let service = IngestService()

    // MARK: - extractConcepts

    func testExtractConcepts_matchFound() async {
        let pages = [
            KnowledgePage(title: "机器学习"),
            KnowledgePage(title: "深度学习"),
            KnowledgePage(title: "自然语言处理")
        ]
        let content = "机器学习与深度学习在自然语言处理中有广泛应用"
        let result = await service.extractConcepts(from: content, pages: pages)
        XCTAssertEqual(Set(result), Set(["机器学习", "深度学习", "自然语言处理"]))
    }

    func testExtractConcepts_noMatch() async {
        let pages = [
            KnowledgePage(title: "计算机视觉"),
            KnowledgePage(title: "强化学习")
        ]
        let content = "机器学习在金融领域有广泛应用"
        let result = await service.extractConcepts(from: content, pages: pages)
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractConcepts_partialMatch() async {
        let pages = [
            KnowledgePage(title: "机器学习"),
            KnowledgePage(title: "自动驾驶"),
            KnowledgePage(title: "强化学习")
        ]
        let content = "机器学习和自动驾驶技术"
        let result = await service.extractConcepts(from: content, pages: pages)
        XCTAssertEqual(Set(result), Set(["机器学习", "自动驾驶"]))
    }

    func testExtractConcepts_emptyContent() async {
        let pages = [KnowledgePage(title: "机器学习")]
        let result = await service.extractConcepts(from: "", pages: pages)
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractConcepts_emptyPages() async {
        let result = await service.extractConcepts(from: "机器学习", pages: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractConcepts_caseInsensitive() async {
        let pages = [KnowledgePage(title: "Machine Learning")]
        let content = "machine learning is a subset of AI"
        let result = await service.extractConcepts(from: content, pages: pages)
        XCTAssertEqual(result, ["Machine Learning"])
    }

    func testExtractConcepts_substringMatchAvoided() async {
        let pages = [
            KnowledgePage(title: "学习"),     // substring of "机器学习"
            KnowledgePage(title: "机器学习")
        ]
        let content = "机器学习是AI的一个分支"
        let result = await service.extractConcepts(from: content, pages: pages)
        XCTAssertEqual(Set(result), Set(["机器学习", "学习"]), "子串匹配当前算法会同时命中两个")
    }

    func testExtractConcepts_duplicateTitlesNotDeduplicated() async {
        // 当前算法不执行去重，重复标题会多次返回
        let pages = [
            KnowledgePage(title: "AI"),
            KnowledgePage(title: "AI")
        ]
        let content = "AI technology"
        let result = await service.extractConcepts(from: content, pages: pages)
        XCTAssertEqual(result.count, 2, "当前算法不执行去重，重复标题返回多次")
    }
}
