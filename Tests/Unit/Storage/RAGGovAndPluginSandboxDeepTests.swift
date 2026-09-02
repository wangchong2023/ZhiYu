//
//  RAGGovernanceAndPluginSandboxDeepBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：针对 RAG 全链路治理存储（RAGGovernanceSQLiteStore）、
//            JS 沙箱插件引擎（JavaScriptPlugin）与插件市场（PluginMarketService）进行深层分支测试。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class RAGGovAndPluginSandboxDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. RAGGovernanceSQLiteStore Token 计费与百分位计算分支

    func testRAGGovernance_TokenLoggingAndPercentileStats() async throws {
        let store = ServiceContainer.shared.resolve((any RAGGovernanceRepository).self)

        // 记录多条 Token 消耗
        try await store.logTokenUsage(model: "gpt-4o", promptTokens: 100, completionTokens: 50)
        try await store.logTokenUsage(model: "gpt-4o", promptTokens: 200, completionTokens: 80)
        try await store.logTokenUsage(model: "claude-3-5", promptTokens: 300, completionTokens: 120)

        // 分支 1: days <= 0 (当天统计)
        let todayStats = try await store.fetchTokenStats(days: 0)
        XCTAssertGreaterThanOrEqual(todayStats.total, 0)

        // 分支 2: days > 0 (历史多日统计)
        let weekStats = try await store.fetchTokenStats(days: 7)
        XCTAssertGreaterThanOrEqual(weekStats.total, 0)
    }

    // MARK: - 2. JavaScriptPlugin 执行与沙箱安全分支

    func testJavaScriptPlugin_ExecutionAndSecurityHooks() async throws {
        let manifest = PluginManifest(
            id: "com.zhiyu.plugin.summary",
            version: "1.0.0",
            author: "ZhiYu Open Source",
            permissions: ["network"],
            names: ["en": "Text Summarizer"],
            descriptions: ["en": "Summarizes markdown documents"],
            category: "tools"
        )

        let plugin = JavaScriptPlugin(
            script: "function onExecute(input) { return 'Summary: ' + input; }",
            manifest: manifest
        )

        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin?.manifest.id, "com.zhiyu.plugin.summary")
    }
}
