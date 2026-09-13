//
//  PluginRecordTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：测试 L1.5 领域层 PluginRecord 结构体的初始化逻辑与 Codable 编解码的完整度。
//

import XCTest
@testable import ZhiYu

final class PluginRecordTests: XCTestCase {

    /// 测试 PluginRecord 使用默认参数进行初始化
    func testPluginRecordDefaultInitialization() {
        // Arrange & Act
        let record = PluginRecord(
            id: "test_plugin",
            name: "Test Plugin",
            version: "1.0.0",
            author: "ZhiYuAuthor",
            source: "local",
            status: "active",
            permissionsJSON: "[]"
        )

        // Assert
        XCTAssertEqual(record.id, "test_plugin", "id 应正确初始化")
        XCTAssertEqual(record.name, "Test Plugin", "name 应正确初始化")
        XCTAssertEqual(record.version, "1.0.0", "version 应正确初始化")
        XCTAssertEqual(record.author, "ZhiYuAuthor", "author 应正确初始化")
        XCTAssertEqual(record.source, "local", "source 应正确初始化")
        XCTAssertEqual(record.status, "active", "status 应正确初始化")
        XCTAssertEqual(record.permissionsJSON, "[]", "permissionsJSON 应正确初始化")
        XCTAssertEqual(record.loadDuration, 0.0, "loadDuration 默认值应为 0")
        XCTAssertEqual(record.unloadDuration, 0.0, "unloadDuration 默认值应为 0")
        XCTAssertEqual(record.totalExecutionTime, 0.0, "totalExecutionTime 默认值应为 0")
        XCTAssertEqual(record.callCount, 0, "callCount 默认值应为 0")
        XCTAssertEqual(record.manifestJSON, "", "manifestJSON 默认值应为空字符串")
        XCTAssertNotNil(record.installedAt, "installedAt 默认值应不为空")
        XCTAssertNotNil(record.updatedAt, "updatedAt 默认值应不为空")
    }

    /// 测试 PluginRecord 使用全量自定义参数进行初始化
    func testPluginRecordFullInitialization() {
        // Arrange
        let now = Date()

        // Act
        let record = PluginRecord(
            id: "full_plugin",
            name: "Full Plugin",
            version: "2.1.0",
            author: "Developer",
            source: "market",
            status: "suspended",
            permissionsJSON: "[\"storage\"]",
            loadDuration: 1.5,
            unloadDuration: 0.8,
            totalExecutionTime: 12.3,
            callCount: 15,
            installedAt: now,
            updatedAt: now,
            manifestJSON: "{\"id\":\"full_plugin\"}"
        )

        // Assert
        XCTAssertEqual(record.id, "full_plugin")
        XCTAssertEqual(record.name, "Full Plugin")
        XCTAssertEqual(record.version, "2.1.0")
        XCTAssertEqual(record.author, "Developer")
        XCTAssertEqual(record.source, "market")
        XCTAssertEqual(record.status, "suspended")
        XCTAssertEqual(record.permissionsJSON, "[\"storage\"]")
        XCTAssertEqual(record.loadDuration, 1.5)
        XCTAssertEqual(record.unloadDuration, 0.8)
        XCTAssertEqual(record.totalExecutionTime, 12.3)
        XCTAssertEqual(record.callCount, 15)
        XCTAssertEqual(record.installedAt, now)
        XCTAssertEqual(record.updatedAt, now)
        XCTAssertEqual(record.manifestJSON, "{\"id\":\"full_plugin\"}")
    }

    /// 测试 PluginRecord 的 Codable 解析，特别是下划线字段映射的正确性
    func testPluginRecordCodable() throws {
        // Arrange
        let jsonString = """
        {
            "id": "codable_plugin",
            "name": "Codable Plugin",
            "version": "1.2.3",
            "author": "Tester",
            "source": "local",
            "status": "unloaded",
            "permissions_json": "[]",
            "load_duration": 0.5,
            "unload_duration": 0.2,
            "total_execution_time": 4.5,
            "call_count": 8,
            "installed_at": 1718000000.0,
            "updated_at": 1718000000.0,
            "manifest_json": "{\\"test\\": true}"
        }
        """
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("无法将 JSON 字符串转化为 Data")
            return
        }

        // Act
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let record = try decoder.decode(PluginRecord.self, from: data)

        // Assert
        XCTAssertEqual(record.id, "codable_plugin")
        XCTAssertEqual(record.permissionsJSON, "[]")
        XCTAssertEqual(record.loadDuration, 0.5)
        XCTAssertEqual(record.unloadDuration, 0.2)
        XCTAssertEqual(record.totalExecutionTime, 4.5)
        XCTAssertEqual(record.callCount, 8)
        XCTAssertEqual(record.manifestJSON, "{\"test\": true}")

        // Test Encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let encodedData = try encoder.encode(record)
        let jsonObject = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]

        // Assert properties in encoded JSON match the CodingKeys
        XCTAssertEqual(jsonObject?["permissions_json"] as? String, "[]")
        XCTAssertEqual(jsonObject?["load_duration"] as? Double, 0.5)
        XCTAssertEqual(jsonObject?["manifest_json"] as? String, "{\"test\": true}")
    }
}
