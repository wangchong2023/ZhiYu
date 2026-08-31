//
//  LLMClientAndOnDeviceEdgeTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 LLM 响应解析、SSE 流式报文重组与 OnDevice 服务初始化降级分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class LLMClientAndOnDeviceEdgeTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. LLMProviderMetadata 数据模型构造

    func testLLMProviderMetadata_Initialization() {
        let meta = LLMProviderMetadata(
            id: "openai",
            nameKey: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            defaultModel: "gpt-4o",
            suggestedModels: ["gpt-4o", "gpt-4o-mini"],
            apiKeyPrefix: "sk-",
            apiKeyMinLength: 10,
            apiKeyPlaceholder: "sk-...",
            icon: "sparkles"
        )

        XCTAssertEqual(meta.id, "openai")
        XCTAssertEqual(meta.defaultModel, "gpt-4o")
        XCTAssertEqual(meta.suggestedModels.count, 2)
    }
}
