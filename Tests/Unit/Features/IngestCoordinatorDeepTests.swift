//
//  IngestCoordinatorDeepTests.swift
//  ZhiYuTests
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 IngestCoordinator 的 performIngest/prepareImportFiles/triggerAITagging/
//            extractJSON/resetForm/openManualForm 深度逻辑与边界条件。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class IngestCoordinatorDeepTests: XCTestCase {

    private var coordinator: IngestCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        coordinator = IngestCoordinator()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 100_000_000)
        coordinator = nil
        try await super.tearDown()
    }

    // MARK: - isImporting 频控计算属性

    /// 验证新建 coordinator 初始状态 isImporting 为 false
    func testIsImportingInitialFalse() {
        XCTAssertFalse(coordinator.isImporting, "新建 coordinator 不应在频控期内")
    }

    /// 验证频控期内 isImporting 为 true
    func testIsImportingTrueWithinCooldown() {
        coordinator.lastImportTime = Date()
        XCTAssertTrue(coordinator.isImporting, "频控期内 isImporting 应为 true")
    }

    /// 验证频控期外 isImporting 恢复 false
    func testIsImportingFalseAfterCooldown() {
        let cooldown = coordinator.importCooldownSeconds
        coordinator.lastImportTime = Date().addingTimeInterval(-cooldown - 1)
        XCTAssertFalse(coordinator.isImporting, "频控期外 isImporting 应恢复 false")
    }

    // MARK: - isLLMConfigured

    /// 验证 isLLMConfigured 状态随 LLMService 状态联动
    func testIsLLMConfiguredReflectsLLMServiceState() {
        let oldKey = LLMService.shared.apiKey
        let oldEnabled = LLMService.shared.isEnabled
        defer {
            LLMService.shared.apiKey = oldKey
            LLMService.shared.isEnabled = oldEnabled
        }

        LLMService.shared.apiKey = ""
        XCTAssertFalse(coordinator.isLLMConfigured, "当 apiKey 为空时 isLLMConfigured 应为 false")

        LLMService.shared.apiKey = "sk-valid-key"
        LLMService.shared.isEnabled = true
        XCTAssertTrue(coordinator.isLLMConfigured, "当配置了有效 apiKey 且启用时 isLLMConfigured 应为 true")
    }

    // MARK: - resetForm

    /// 验证 resetForm 清空所有表单字段
    func testResetFormClearsAllFields() {
        coordinator.newTitle = "测试标题"
        coordinator.newContent = "测试内容"
        coordinator.newCustomIcon = "star"
        coordinator.useSmartIngest = true

        coordinator.resetForm()

        XCTAssertEqual(coordinator.newTitle, "", "resetForm 后 newTitle 应为空")
        XCTAssertEqual(coordinator.newContent, "", "resetForm 后 newContent 应为空")
        XCTAssertNil(coordinator.newCustomIcon, "resetForm 后 newCustomIcon 应为 nil")
        XCTAssertFalse(coordinator.useSmartIngest, "resetForm 后 useSmartIngest 应为 false")
    }

    // MARK: - extractJSON

    /// 验证从纯 JSON 字符串提取
    func testExtractJSONPureJSON() {
        let input = "{\"key\": \"value\"}"
        let result = coordinator.extractJSON(from: input)
        XCTAssertEqual(result["key"] as? String, "value")
    }

    /// 验证从 ```json 代码块中提取
    func testExtractJSONCodeBlock() {
        let input = "前置说明\n```json\n{\"tags\": [\"a\", \"b\"]}\n```\n后置说明"
        let result = coordinator.extractJSON(from: input)
        XCTAssertEqual((result["tags"] as? [String])?.count, 2)
    }

    /// 验证无匹配时返回空字典
    func testExtractJSONNoMatch() {
        let input = "纯文本内容没有代码块"
        let result = coordinator.extractJSON(from: input)
        XCTAssertTrue(result.isEmpty)
    }
}
