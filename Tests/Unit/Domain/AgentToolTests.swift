//
//  AgentToolTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：提供对智能工具契约模型 AgentTool 构造参数、id 计算映射、Codable 序列化及 Equatable 判定的单元测试覆盖。
//

import XCTest
@testable import ZhiYu

final class AgentToolTests: XCTestCase {

    /// 测试 AgentTool 构造函数各参数的实例化与默认版本号行为
    func testAgentToolInitialization() {
        // Arrange & Act
        let tool = AgentTool(
            toolName: "vectorSearch",
            description: "Queries the vector database for pages matching context",
            parametersSchema: "{\"type\": \"object\"}"
        )

        // Assert
        XCTAssertEqual(tool.toolName, "vectorSearch", "toolName 应当正确赋值")
        XCTAssertEqual(tool.description, "Queries the vector database for pages matching context", "description 应当正确赋值")
        XCTAssertEqual(tool.parametersSchema, "{\"type\": \"object\"}", "parametersSchema 应当正确赋值")
        XCTAssertEqual(tool.version, "1.0.0", "默认版本号应当为 1.0.0")
        XCTAssertEqual(tool.id, "vectorSearch", "计算属性 id 应当映射自 toolName")

        // 测试显式指定版本号
        let toolWithCustomVersion = AgentTool(
            toolName: "webFetch",
            description: "Fetches web page content",
            parametersSchema: "{}",
            version: "2.0.1"
        )
        XCTAssertEqual(toolWithCustomVersion.version, "2.0.1", "自定义版本号应当为 2.0.1")
    }

    /// 测试 AgentTool 的 Codable 解析与还原
    func testAgentToolCodable() throws {
        // Arrange
        let tool = AgentTool(
            toolName: "calendarQuery",
            description: "Checks calendar events",
            parametersSchema: "{\"type\": \"string\"}",
            version: "1.1.0"
        )

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(tool)

        // Act - Decode
        let decoder = JSONDecoder()
        let decodedTool = try decoder.decode(AgentTool.self, from: data)

        // Assert
        XCTAssertEqual(decodedTool.toolName, tool.toolName)
        XCTAssertEqual(decodedTool.description, tool.description)
        XCTAssertEqual(decodedTool.parametersSchema, tool.parametersSchema)
        XCTAssertEqual(decodedTool.version, tool.version)
        XCTAssertEqual(decodedTool.id, tool.id)
    }

    /// 测试 AgentTool 两个对象之间的 Equatable 比较
    func testAgentToolEquatable() {
        // Arrange
        let toolA = AgentTool(
            toolName: "tool1",
            description: "descA",
            parametersSchema: "{}"
        )
        let toolB = AgentTool(
            toolName: "tool1",
            description: "descA",
            parametersSchema: "{}"
        )
        let toolC = AgentTool(
            toolName: "tool2",
            description: "descA",
            parametersSchema: "{}"
        )

        // Act & Assert
        XCTAssertEqual(toolA, toolB, "当属性完全一致时，两个工具实例应当是平等的 (Equatable)")
        XCTAssertNotEqual(toolA, toolC, "当 toolName 不同时，实例应当不相等")
    }
}
