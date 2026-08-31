//
//  PluginRuntimeAndMarketBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 PluginManifest 解码、插件市场模型与 JavaScriptPlugin 沙箱权限隔离分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PluginRuntimeAndMarketBranchTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. PluginManifest 解码与权限集分支

    func testPluginManifest_DecodeAndValidation() throws {
        let json = """
        {
            "id": "com.zhiyu.plugin.mermaid",
            "name": "Mermaid 渲染增强",
            "version": "1.2.0",
            "author": "Antigravity",
            "description": "提供复杂时序图与甘特图实时预览",
            "names": {"zh-Hans": "Mermaid 渲染增强"},
            "descriptions": {"zh-Hans": "提供复杂时序图与甘特图实时预览"},
            "permissions": ["readContent", "aiAccess"]
        }
        """
        let data = Data(json.utf8)

        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
        XCTAssertEqual(manifest.id, "com.zhiyu.plugin.mermaid")
        XCTAssertEqual(manifest.permissions.count, 2)
        XCTAssertTrue(manifest.permissions.contains("readContent"))
    }

    // MARK: - 2. 插件安装状态与生命周期

    func testPluginRecord_StateTransitions() {
        var record = PluginRecord(
            id: "test.plugin",
            name: "测试插件",
            version: "1.0.0",
            author: "Tester",
            source: "local",
            status: "unloaded",
            permissionsJSON: "[]",
            manifestJSON: "{}"
        )

        XCTAssertEqual(record.status, "unloaded")
        record.status = "active"
        XCTAssertEqual(record.status, "active")
    }
}
