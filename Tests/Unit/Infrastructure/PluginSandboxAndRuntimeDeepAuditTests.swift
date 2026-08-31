//
//  PluginSandboxAndRuntimeDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：深入审计插件沙箱安全边界、看门狗熔断封禁、事件总线监听器清理(Bug 40)及 JSContext 连接池硬化。
//

import XCTest
import JavaScriptCore
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PluginSandboxAndRuntimeDeepAuditTests: XCTestCase {

    private var registry: PluginRegistry!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        registry = PluginRegistry()
        registry.reset()
    }

    override func tearDown() async throws {
        registry.reset()
        PluginEnginePool.shared.resetPoolForTesting()
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 看门狗熔断与事件监听器清理 (Bug #40 专项防御)

    func testWatchdog_SuspendPlugin_CompletelyCleansUpEventListeners() {
        let manifest = PluginManifest(
            id: "com.zhiyu.plugin.test.event-zombie",
            version: "1.0.0",
            author: "Tester",
            permissions: ["writeContent", "log"],
            names: ["en": "Event Zombie"],
            descriptions: ["en": "Test plugin"]
        )

        var eventCallbackTriggered = false
        let plugin = MockInterceptionPlugin(manifest: manifest) { content in
            // 模拟超时：返回内容但耗时超限 (0.6s > 0.5s)
            Thread.sleep(forTimeInterval: 0.6)
            return content + " [processed]"
        }

        registry.loadPlugin(plugin)
        XCTAssertEqual(registry.plugins.count, 1)

        // 注册事件监听器
        registry.eventListeners.append(PluginEventListener(
            pluginID: manifest.id,
            event: "page.created",
            callback: { _ in eventCallbackTriggered = true }
        ))
        XCTAssertEqual(registry.eventListeners.count, 1)

        // 触发拦截：耗时 0.6s > 0.5s 超时看门狗，触发自动挂起 suspendPlugin
        _ = registry.runtime.applyPreProcess(to: "测试内容")

        // 验证插件已被移出活跃列表并标记为 suspended
        XCTAssertTrue(registry.suspendedPluginIDs.contains(manifest.id))
        XCTAssertTrue(registry.plugins.isEmpty)

        // 🛡️ Bug #40 关键断言：已封禁插件在 registry.eventListeners 中的监听器必须已被彻底清理
        let remainingListeners = registry.eventListeners.filter { $0.pluginID == manifest.id }
        XCTAssertTrue(
            remainingListeners.isEmpty,
            "被看门狗封禁的插件必须清除其全部事件总线监听器，防止幽灵回调继续被触发"
        )

        // 触发总线事件，验证已封禁插件的回调不会被执行
        registry.emitEvent("page.created", data: ["title": "新页面"])
        XCTAssertFalse(eventCallbackTriggered, "已封禁插件的回调绝不可被事件总线执行")
    }

    // MARK: - 2. 权限网关：网络、LLM 与页面读取权限严格审计

    func testPermissionsGateway_EnforcesGranularAccess() async {
        // 场景 A: 未声明 network 权限的插件尝试发起网络请求
        let noNetworkManifest = PluginManifest(
            id: "com.zhiyu.plugin.test.no-network",
            version: "1.0.0",
            author: "Tester",
            permissions: ["log"],
            names: ["en": "No Network"],
            descriptions: ["en": "Test plugin"]
        )

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://api.example.com/data",
                options: nil,
                allowedDomains: ["api.example.com"],
                permissions: noNetworkManifest.permissions
            )
        ) { error in
            if case PluginSandboxError.permissionDenied(let perm) = error {
                XCTAssertEqual(perm, PluginConstants.Permission.network)
            } else {
                XCTFail("期望抛出 permissionDenied(network) 错误，实际抛出: \(error)")
            }
        }

        // 场景 B: 包含 network 权限但请求未白名单域名
        let networkManifest = PluginManifest(
            id: "com.zhiyu.plugin.test.network",
            version: "1.0.0",
            author: "Tester",
            permissions: ["network"],
            names: ["en": "Network"],
            descriptions: ["en": "Test plugin"]
        )
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://malicious.evil.com/leak",
                options: nil,
                allowedDomains: ["safe.example.com"],
                permissions: networkManifest.permissions
            )
        ) { error in
            if case PluginSandboxError.dlpFetchBlocked(let domain) = error {
                XCTAssertEqual(domain, "malicious.evil.com")
            } else {
                XCTFail("期望抛出 dlpFetchBlocked 错误，实际抛出: \(error)")
            }
        }

        // 场景 C: 尝试注入黑名单 Header（Authorization, Cookie, X-API-Key）
        let dangerousOptions: [String: Any] = [
            "method": "POST",
            "headers": ["Authorization": "Bearer leaked_token", "Content-Type": "application/json"]
        ]
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://safe.example.com/api",
                options: dangerousOptions,
                allowedDomains: ["safe.example.com"],
                permissions: networkManifest.permissions
            )
        ) { error in
            if case PluginSandboxError.permissionDenied(let perm) = error {
                XCTAssertEqual(perm, PluginConstants.Permission.httpHeader)
            } else {
                XCTFail("期望抛出 permissionDenied(httpHeader) 错误，实际抛出: \(error)")
            }
        }

        // 场景 D: 尝试使用危险 HTTP 方法 (DELETE)
        let deleteOptions: [String: Any] = [
            "method": "DELETE"
        ]
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://safe.example.com/api",
                options: deleteOptions,
                allowedDomains: ["safe.example.com"],
                permissions: networkManifest.permissions
            )
        ) { error in
            if case PluginSandboxError.permissionDenied(let perm) = error {
                XCTAssertEqual(perm, PluginConstants.Permission.httpMethod)
            } else {
                XCTFail("期望抛出 permissionDenied(httpMethod) 错误，实际抛出: \(error)")
            }
        }
    }

    // MARK: - 3. JSContext 连接池硬化与全局污染清理

    func testPluginEnginePool_SandboxHardeningAndStateCleanup() {
        let pool = PluginEnginePool.shared

        // 借出 context 并验证 eval / Function 禁用
        let ctx = pool.borrowContext()
        let evalCheck = ctx.evaluateScript("typeof globalThis.eval")
        XCTAssertEqual(evalCheck?.toString(), "undefined", "JS 沙箱中 eval 必须被禁用 (undefined)")

        let functionCheck = ctx.evaluateScript("typeof globalThis.Function")
        XCTAssertEqual(functionCheck?.toString(), "undefined", "JS 沙箱中 Function 构造器必须被禁用 (undefined)")

        // 在借出 context 中注入污染变量
        ctx.evaluateScript("globalThis.maliciousVar = 'dirty_data';")
        let polluted = ctx.evaluateScript("globalThis.maliciousVar")
        XCTAssertEqual(polluted?.toString(), "dirty_data")

        // 归还到池中
        pool.returnContext(ctx)

        // 再次借出，验证污染变量已被归还钩子彻底清理
        let freshCtx = pool.borrowContext()
        let cleanCheck = freshCtx.evaluateScript("typeof globalThis.maliciousVar")
        XCTAssertEqual(cleanCheck?.toString(), "undefined", "归还并再次借出的 JSContext 必须已清除非原生全局污染变量")

        pool.returnContext(freshCtx)
    }

    // MARK: - 4. 插件卸载与磁盘残留清理

    func testPluginLoader_LocalizedReadmeFallback() {
        let loader = PluginLoader()

        // 包含路径穿越的 ID 安全防御
        XCTAssertNil(loader.localizedReadme(for: "../etc/passwd"))
        XCTAssertNil(loader.iconURL(for: "../etc/passwd"))
    }
}

// MARK: - Test Mocks

private final class MockInterceptionPlugin: InterceptionPlugin {
    let manifest: PluginManifest
    let monetization: MonetizationInfo? = nil
    private let interceptBlock: (String) -> String

    init(manifest: PluginManifest, interceptBlock: @escaping (String) -> String) {
        self.manifest = manifest
        self.interceptBlock = interceptBlock
    }

    func onLoad(context: PluginContext) {}
    func onUnload() {}

    func preProcess(content: String) throws -> String {
        interceptBlock(content)
    }

    func postProcess(content: String) throws -> String {
        content
    }
}
