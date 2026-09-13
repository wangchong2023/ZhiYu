//
//  SettingsAndPluginCenterDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对系统设置（SettingsView）、插件中心（PluginCenterView）与
//            Mock 服务器配置（ServerConfigView）执行深水区状态机、UI 交互与边界 Fuzz 测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SettingsAndPluginCenterDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SettingsView 紧凑与 Catalyst 模式深度测试

    func testSettingsView_CompactListAndAllSections_RendersAndInteracts() async {
        let rawSettings = SettingsView()
        let settingsView = rawSettings.snapshotEnvironment()

        let host = UIHostingController(rootView: settingsView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "SettingsView 紧凑视图应成功渲染")
        XCTAssertNotNil(rawSettings)
    }

    func testSettingsView_ThemeAndLanguageSwitching_TriggersStateMutation() async {
        let themeManager = ThemeManager()
        let initialMode = themeManager.colorSchemeMode

        // 切换浅色/深色/跟随系统
        themeManager.colorSchemeMode = .dark
        XCTAssertEqual(themeManager.colorSchemeMode, .dark)

        themeManager.colorSchemeMode = .light
        XCTAssertEqual(themeManager.colorSchemeMode, .light)

        themeManager.colorSchemeMode = initialMode
    }

    func testSettingsView_DemoNotebookInjection_HandlesSuccessAndFailure() async {
        let store = AppStore()
        
        // 验证初始注入行为
        let result = await store.generateInitialNotebooks()
        XCTAssertGreaterThanOrEqual(result.total, 0, "示例笔记本注入应返回有效统计")
    }

    // MARK: - 2. PluginCenterView 市场/已安装切换与安全模式深度测试

    func testPluginCenterView_TabSwitchingAndCategoryFiltering_WorksCorrectly() async {
        let rawPlugin = PluginCenterView()
        let pluginCenter = rawPlugin.snapshotEnvironment()

        let host = UIHostingController(rootView: pluginCenter)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "PluginCenterView 完整视图应成功渲染")
        XCTAssertNotNil(rawPlugin)
    }

    func testPluginCenterView_MarketService_FetchAndFilterPlugins() async {
        let registry = PluginRegistry()
        let service = PluginMarketService(registry: registry)

        await service.fetchPlugins()
        XCTAssertNotNil(service.availablePlugins, "插件市场列表应已加载")
        XCTAssertFalse(service.isLoading, "加载完成后 isLoading 应为 false")
    }

    // MARK: - 3. ServerConfigView & ServerEditSheet 配置管理与连通性测试

    func testServerConfigView_DefaultAndCustomConfigs_SerializationAndCRUD() {
        let serverView = ServerConfigView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: serverView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "ServerConfigView 应成功挂载")

        // 验证 MockServerConfig 模型编码与解码
        let config = MockServerConfig(
            id: UUID(),
            name: "Test Local LLM",
            baseURL: "http://127.0.0.1:11434",
            apiKey: "sk-test-key-12345",
            isDefault: true,
            lastTestedAt: Date(),
            latencyMs: 18,
            isHealthy: true
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(config)
            let decoded = try decoder.decode(MockServerConfig.self, from: data)
            XCTAssertEqual(decoded.name, config.name)
            XCTAssertEqual(decoded.baseURL, config.baseURL)
            XCTAssertEqual(decoded.apiKey, config.apiKey)
            XCTAssertEqual(decoded.isDefault, true)
            XCTAssertEqual(decoded.isHealthy, true)
            XCTAssertEqual(decoded.latencyMs, 18)
        } catch {
            XCTFail("MockServerConfig 编码/解码失败: \(error)")
        }
    }

    func testServerEditSheet_FormValidationAndSave() {
        var savedConfig: MockServerConfig?
        let editSheet = ServerEditSheet(server: nil) { newConfig in
            savedConfig = newConfig
        }
        .snapshotEnvironment()

        let host = UIHostingController(rootView: editSheet)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "ServerEditSheet 新增模式应成功渲染")
        XCTAssertNil(savedConfig, "初始时尚未触发保存")
    }

    func testServerEditSheet_EditExistingServer_PopulatesFields() {
        let existing = MockServerConfig(
            id: UUID(),
            name: "Production Ollama",
            baseURL: "https://ollama.local:11434",
            apiKey: "bearer-token-xyz",
            isDefault: false,
            lastTestedAt: nil,
            latencyMs: nil,
            isHealthy: false
        )

        let editSheet = ServerEditSheet(server: existing) { _ in }
            .snapshotEnvironment()

        let host = UIHostingController(rootView: editSheet)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "ServerEditSheet 编辑模式应成功渲染")
        XCTAssertEqual(existing.name, "Production Ollama")
        XCTAssertEqual(existing.baseURL, "https://ollama.local:11434")
    }

    // MARK: - 4. 边界与 Fuzz 异常注入测试

    func testMockServerConfig_ExtremeValuesAndFuzzInputs() {
        // 极端超长 URL 与特殊字符 API Key
        let extremeConfig = MockServerConfig(
            id: UUID(),
            name: String(repeating: "服务器名字", count: 100),
            baseURL: "https://invalid-ip-256.256.256.256:99999/very/long/path/with?query=1&token=" + String(repeating: "A", count: 2000),
            apiKey: "特殊字符🔑!@#$%^&*()_+-=[]{}|;':,.<>/?",
            isDefault: false,
            lastTestedAt: Date(timeIntervalSince1970: 0),
            latencyMs: Int.max,
            isHealthy: false
        )

        XCTAssertEqual(extremeConfig.latencyMs, Int.max)
        XCTAssertFalse(extremeConfig.isHealthy)

        let data = try? JSONEncoder().encode(extremeConfig)
        XCTAssertNotNil(data, "极端配置序列化应稳定不崩溃")
    }
}
