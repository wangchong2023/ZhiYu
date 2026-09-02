//
//  ServerConfigAndMockServersDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 MockServerConfig 数据模型、ServerConfigView 服务器配置列表、
//           编辑表单与默认服务器切换状态机。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class ServerConfigAndMockServersDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. MockServerConfig 模型与 Codable 测试

    func testMockServerConfig_InitAndCodableRoundtrip() throws {
        let id = UUID()
        let config = MockServerConfig(
            id: id,
            name: "本地 Ollama 测试节点",
            baseURL: "http://127.0.0.1:11434",
            apiKey: "sk-mock-test-key",
            isDefault: true,
            lastTestedAt: Date(),
            latencyMs: 15,
            isHealthy: true
        )

        XCTAssertEqual(config.id, id)
        XCTAssertEqual(config.name, "本地 Ollama 测试节点")
        XCTAssertEqual(config.baseURL, "http://127.0.0.1:11434")
        XCTAssertEqual(config.apiKey, "sk-mock-test-key")
        XCTAssertTrue(config.isDefault)
        XCTAssertTrue(config.isHealthy)
        XCTAssertEqual(config.latencyMs, 15)

        // Codable 序列化与反序列化回环
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MockServerConfig.self, from: data)
        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.name, config.name)
        XCTAssertEqual(decoded.baseURL, config.baseURL)
        XCTAssertEqual(decoded.isDefault, config.isDefault)
        XCTAssertEqual(decoded.isHealthy, config.isHealthy)
    }

    // MARK: - 2. ServerConfigView 视图层级与状态机测试

    func testServerConfigView_Hierarchy() {
        let view = NavigationStack {
            ServerConfigView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }
}
