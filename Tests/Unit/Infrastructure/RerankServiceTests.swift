//
//  RerankServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 RerankService 搜索重排算法开展自动化单元测试。
//

import XCTest
@testable import ZhiYu

final class RerankServiceTests: XCTestCase {

    private let service = RerankService.shared

    // MARK: - 基础排序

    func testRerank_mostRelevantFirst() async throws {
        let pages = [
            KnowledgePage(title: "A", content: "西瓜香蕉"),           // 0 matches for "苹果"
            KnowledgePage(title: "B", content: "香蕉苹果苹果"),       // 2 matches
            KnowledgePage(title: "C", content: "苹果")                // 1 match
        ]
        let result = try await service.rerank(query: "苹果", candidates: pages)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].title, "B", "出现 2 次应排第一")
        XCTAssertEqual(result[1].title, "C", "出现 1 次应排第二")
        XCTAssertEqual(result[2].title, "A", "出现 0 次应排最后")
    }

    func testRerank_emptyQuery_returnsOriginalOrder() async throws {
        let pages = [
            KnowledgePage(title: "A", content: "苹果"),
            KnowledgePage(title: "B", content: "香蕉")
        ]
        let result = try await service.rerank(query: "", candidates: pages)
        XCTAssertEqual(result.map(\.title), ["A", "B"])
    }

    func testRerank_whitespaceQuery_returnsOriginalOrder() async throws {
        let pages = [
            KnowledgePage(title: "A", content: "苹果"),
            KnowledgePage(title: "B", content: "香蕉")
        ]
        let result = try await service.rerank(query: "   ", candidates: pages)
        XCTAssertEqual(result.map(\.title), ["A", "B"])
    }

    func testRerank_noMatch_returnsOriginalOrder() async throws {
        let pages = [
            KnowledgePage(title: "A", content: "水果"),
            KnowledgePage(title: "B", content: "蔬菜")
        ]
        let result = try await service.rerank(query: "海鲜", candidates: pages)
        XCTAssertEqual(result.map(\.title), ["A", "B"])
    }

    func testRerank_sameFrequency_titleTiebreaker() async throws {
        let pages = [
            KnowledgePage(title: "XX苹果YY", content: "香蕉"),  // 0 matches content, title contains
            KnowledgePage(title: "香蕉", content: "水果")       // 0 matches content, no title match
        ]
        let result = try await service.rerank(query: "苹果", candidates: pages)
        XCTAssertEqual(result[0].title, "XX苹果YY", "标题包含查询词的应排在前面")
    }

    func testRerank_singlePage() async throws {
        let pages = [KnowledgePage(title: "A", content: "苹果")]
        let result = try await service.rerank(query: "苹果", candidates: pages)
        XCTAssertEqual(result.count, 1)
    }

    func testRerank_emptyCandidates() async throws {
        let result = try await service.rerank(query: "苹果", candidates: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testRerank_caseInsensitiveContentMatch() async throws {
        let pages = [
            KnowledgePage(title: "A", content: "苹果 APPLE"),
            KnowledgePage(title: "B", content: "apple 水果")
        ]
        let result = try await service.rerank(query: "apple", candidates: pages)
        XCTAssertEqual(result[0].title, "B", "apple 在 B 中出现 1 次，A 中 0 次（大小写敏感）")
    }
}
