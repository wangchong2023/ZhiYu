//
//  KnowledgePageFTSTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：提供对全文搜索虚拟表索引模型 KnowledgePageFTS 的初始化与 Codable 性能校验。
//

import XCTest
@testable import ZhiYu

final class KnowledgePageFTSTests: XCTestCase {

    /// 测试 KnowledgePageFTS 构造函数的各种默认及赋值行为
    func testKnowledgePageFTSInitialization() {
        // Arrange & Act
        let fts = KnowledgePageFTS(
            id: "page_1",
            title: "FTS Title",
            content: "FTS Content",
            tags: "tag1,tag2",
            aliases: "alias1"
        )

        // Assert
        XCTAssertEqual(fts.id, "page_1", "id 应当正确赋值")
        XCTAssertEqual(fts.title, "FTS Title", "title 应当正确赋值")
        XCTAssertEqual(fts.content, "FTS Content", "content 应当正确赋值")
        XCTAssertEqual(fts.tags, "tag1,tag2", "tags 应当正确赋值")
        XCTAssertEqual(fts.aliases, "alias1", "aliases 应当正确赋值")

        // 测试带有可选参数为 nil 时的默认值
        let ftsDefault = KnowledgePageFTS(
            id: "page_2",
            title: "FTS Title 2",
            content: "FTS Content 2"
        )
        XCTAssertNil(ftsDefault.tags, "默认 tags 应当为 nil")
        XCTAssertNil(ftsDefault.aliases, "默认 aliases 应当为 nil")
    }

    /// 测试 KnowledgePageFTS 的 Codable 编解码能力
    func testKnowledgePageFTSCodable() throws {
        // Arrange
        let fts = KnowledgePageFTS(
            id: "page_3",
            title: "Test Codable",
            content: "Markdown Body",
            tags: "test",
            aliases: "alias"
        )

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(fts)

        // Act - Decode
        let decoder = JSONDecoder()
        let decodedFTS = try decoder.decode(KnowledgePageFTS.self, from: data)

        // Assert
        XCTAssertEqual(decodedFTS.id, fts.id)
        XCTAssertEqual(decodedFTS.title, fts.title)
        XCTAssertEqual(decodedFTS.content, fts.content)
        XCTAssertEqual(decodedFTS.tags, fts.tags)
        XCTAssertEqual(decodedFTS.aliases, fts.aliases)
    }
}
