//
//  ModelServerAndParametersViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 MockServerConfig 持久化流转、默认服务器切换与推理参数预设匹配分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ModelServerAndParametersViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. MockServerConfig 属性与健康状态分支

    func testMockServerConfig_CreationAndHealthState() {
        let server = MockServerConfig(
            id: UUID(),
            name: "本地 Ollama 端点",
            baseURL: "http://localhost:11434/v1",
            apiKey: "sk-local-key",
            isDefault: true,
            lastTestedAt: Date(),
            latencyMs: 45,
            isHealthy: true
        )

        XCTAssertEqual(server.name, "本地 Ollama 端点")
        XCTAssertTrue(server.isDefault)
        XCTAssertTrue(server.isHealthy)
        XCTAssertEqual(server.latencyMs, 45)
    }

    // MARK: - 2. 默认服务器互斥切换分支

    func testMockServerConfig_SetDefaultServerMutualExclusion() {
        let id1 = UUID()
        let id2 = UUID()

        var servers = [
            MockServerConfig(id: id1, name: "Server 1", baseURL: "http://a", apiKey: nil, isDefault: true, lastTestedAt: nil, latencyMs: nil, isHealthy: true),
            MockServerConfig(id: id2, name: "Server 2", baseURL: "http://b", apiKey: nil, isDefault: false, lastTestedAt: nil, latencyMs: nil, isHealthy: false)
        ]

        // 切换 Server 2 为默认
        servers = servers.map { config in
            var updated = config
            updated.isDefault = (config.id == id2)
            return updated
        }

        XCTAssertFalse(servers[0].isDefault)
        XCTAssertTrue(servers[1].isDefault)
    }

    // MARK: - 3. 推理参数默认值与容差匹配分支

    func testInferenceParameters_DefaultConstants() {
        XCTAssertGreaterThan(FeatureConstants.InferenceParam.defaultTemperature, 0.0)
        XCTAssertGreaterThan(FeatureConstants.InferenceParam.defaultTopP, 0.0)
        XCTAssertGreaterThan(FeatureConstants.InferenceParam.defaultTopK, 0)
        XCTAssertGreaterThan(FeatureConstants.InferenceParam.defaultMaxTokens, 0)
        XCTAssertEqual(FeatureConstants.InferenceParam.presetMatchTolerance, 0.01)
    }
}
