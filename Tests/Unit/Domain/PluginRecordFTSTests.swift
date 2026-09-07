//
//  PluginRecordFTSTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：提供对虚拟搜索虚拟表模型 PluginRecordFTS 的初始化与 Codable 性能校验。
//

import XCTest
@testable import ZhiYu

final class PluginRecordFTSTests: XCTestCase {

    /// 测试 PluginRecordFTS 构造函数的赋值
    func testPluginRecordFTSInitialization() {
        // Arrange & Act
        let fts = PluginRecordFTS(
            id: "plugin_1",
            name: "Search Tool",
            author: "ZhiYuTeam",
            description: "Allows deep search integration"
        )

        // Assert
        XCTAssertEqual(fts.id, "plugin_1", "id 应当正确赋值")
        XCTAssertEqual(fts.name, "Search Tool", "name 应当正确赋值")
        XCTAssertEqual(fts.author, "ZhiYuTeam", "author 应当正确赋值")
        XCTAssertEqual(fts.description, "Allows deep search integration", "description 应当正确赋值")
    }

    /// 测试 PluginRecordFTS 的 Codable 编解码能力
    func testPluginRecordFTSCodable() throws {
        // Arrange
        let fts = PluginRecordFTS(
            id: "plugin_2",
            name: "Test Codable Plugin",
            author: "Tester",
            description: "Plugin FTS test description"
        )

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(fts)

        // Act - Decode
        let decoder = JSONDecoder()
        let decodedFTS = try decoder.decode(PluginRecordFTS.self, from: data)

        // Assert
        XCTAssertEqual(decodedFTS.id, fts.id)
        XCTAssertEqual(decodedFTS.name, fts.name)
        XCTAssertEqual(decodedFTS.author, fts.author)
        XCTAssertEqual(decodedFTS.description, fts.description)
    }
}
