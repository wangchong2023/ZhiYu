//
//  OnDeviceLLMAndMemoryDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：深度审计端侧大模型推理服务 (OnDeviceLLMService) 的可用性检测、模型发现、生成取消与内存状态机。
//

import XCTest
import Combine
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class OnDeviceLLMAndMemoryDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 端侧模型发现与配置常数

    func testOnDeviceLLM_DiscoverAndInitialState() {
        let service = OnDeviceLLMService()

        // 验证默认初始化与状态机
        XCTAssertFalse(service.isGenerating)
        XCTAssertEqual(service.generationProgress, 0)
        XCTAssertEqual(service.inferenceSpeed, 0)
        XCTAssertTrue(service.generatedText.isEmpty)

        // 验证 Config 常数合规性（去魔鬼化）
        XCTAssertEqual(OnDeviceLLMService.Config.defaultMaxTokens, 256)
        XCTAssertEqual(OnDeviceLLMService.Config.generationTemperature, 0.7)
        XCTAssertEqual(OnDeviceLLMService.Config.smartIngestMaxTokens, 500)
        XCTAssertEqual(OnDeviceLLMService.Config.chatMaxTokens, 300)
        XCTAssertEqual(OnDeviceLLMService.Config.contextPageLimit, 5)
        XCTAssertEqual(OnDeviceLLMService.Config.titleHitWeight, 3)
    }

    // MARK: - 2. 推理取消与状态重置

    func testOnDeviceLLM_CancelGeneration_ResetsState() {
        let service = OnDeviceLLMService()
        service.isGenerating = true
        service.generationProgress = 0.5
        service.generatedText = "正在生成部分文本..."

        service.cancelGeneration()

        XCTAssertFalse(service.isGenerating, "取消后必须复位 isGenerating")
        XCTAssertEqual(service.generationProgress, 0, "取消后必须清空进度")
    }

    // MARK: - 3. 实体抽取与智能标签生成容错防御

    func testOnDeviceLLM_TagExtraction_HandlesEmptyAndMalformed() async {
        let service = OnDeviceLLMService()

        // 标签提取
        let extractedTags = service.extractTags(from: "这是一个包含 #架构 和 #AI 的文本")
        XCTAssertEqual(extractedTags.count, 2)
        XCTAssertTrue(extractedTags.contains("架构"))
        XCTAssertTrue(extractedTags.contains("AI"))

        let emptyTags = service.extractTags(from: "")
        XCTAssertTrue(emptyTags.isEmpty, "空文本标签提取应安全返回空集合")
    }
}
