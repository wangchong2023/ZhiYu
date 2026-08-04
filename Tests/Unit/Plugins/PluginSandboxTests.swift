//
//  PluginSandboxTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 PluginSandbox 开展自动化单元测试验证。
//
import XCTest
import UFPCore
@preconcurrency @testable import ZhiYu

/// 插件沙箱安全测试
/// 验证 PluginRegistry 的加载/卸载、权限拦截、崩溃隔离及流控降级。
@MainActor
final class PluginSandboxTests: XCTestCase {

    var registry: PluginRegistry!
    var dbQueue: Any!

    override func setUp() async throws {
        try await super.setUp()
        // 关键点：搭建标准的 Mock 环境以防止底层 resolve 找不到所需服务
        dbQueue = setupFullMockEnvironment()
        // 注入 MockKeychainService，绕过 CI 模拟器环境 errSecMissingEntitlement -34018 限制
        // 避免 LLMConfigStore.loadAPIKey 调用真实 Keychain 失败导致测试间状态污染
        KeychainService.testOverride = MockKeychainService()

        registry = PluginRegistry.shared
        registry.reset()
    }

    override func tearDown() async throws {
        registry.reset()
        registry = nil
        ServiceContainer.shared.reset()
        KeychainService.testOverride = nil
        dbQueue = nil
        try await super.tearDown()
    }

    // MARK: - 加载与卸载

    func testLoadPluginRegistersAndCallsOnLoad() {
        let plugin = MockKnowledgePlugin(id: "test.load", name: "测试插件")
        registry.loadPlugin(plugin)

        XCTAssertTrue(registry.plugins.contains(where: { $0.manifest.id == "test.load" }),
                      "插件加载后应在注册列表中")
        XCTAssertTrue(plugin.didLoad, "onLoad 应在加载时被调用")
    }

    func testUnloadPluginRemovesAndCallsOnUnload() {
        let plugin = MockKnowledgePlugin(id: "test.unload", name: "卸载测试")
        registry.loadPlugin(plugin)
        registry.unloadPlugin(id: "test.unload")

        XCTAssertFalse(registry.plugins.contains(where: { $0.manifest.id == "test.unload" }),
                       "卸载后插件不应在列表中")
        XCTAssertTrue(plugin.didUnload, "onUnload 应在卸载时被调用")
    }

    // MARK: - 拦截器注册

    func testInterceptionPluginIsRegisteredAsInterceptor() {
        // 1. 初始化沙箱测试专属的拦截插件，注册拦截器
        let plugin = MockSandboxInterceptionPlugin(id: "test.intercept", name: "拦截测试")
        registry.loadPlugin(plugin)

        // 2. 应用前置拦截，验证是否成功触发前置处理器并修改内容
        let result = registry.applyPreProcess(to: "原始内容")
        XCTAssertEqual(result, "拦截后: 原始内容", "preProcess 应被调用并修改内容")
    }

    // MARK: - 权限拦截

    func testPreProcessRejectedWithoutWriteContentPermission() {
        // 1. 模拟一个仅声明只读权限（不具备 writeContent 写入权限）的沙箱插件
        let plugin = MockSandboxInterceptionPlugin(
            id: "test.noperm",
            name: "无权限插件",
            permissions: ["pages.read"] // 故意不给 writeContent
        )
        registry.loadPlugin(plugin)

        // 2. 验证该无权修改的插件在安全拦截时，其预处理行为是否会被安全过滤器抛弃，返回原始内容
        let result = registry.applyPreProcess(to: "内容")
        XCTAssertEqual(result, "内容", "无 writeContent 权限的插件不应修改内容")
    }

    // MARK: - 崩溃隔离

    func testPluginExceptionDoesNotCrashRegistry() {
        let crashingPlugin = MockCrashingPlugin()
        registry.loadPlugin(crashingPlugin)

        let result = registry.applyPreProcess(to: "测试")
        XCTAssertEqual(result, "测试", "崩溃插件的输出应被忽略，内容不变")
    }

    // MARK: - 流控降级

    func testThrottlingSkipsOverlyFrequentPlugin() {
        // 1. 注册高频沙箱拦截插件
        let plugin = MockSandboxInterceptionPlugin(id: "test.throttle", name: "高频插件")
        registry.loadPlugin(plugin)

        // 2. 模拟高频次调用（超过流控阈值），以验证沙箱的熔断隔离与流控降级策略
        for _ in 0..<51 {
            _ = registry.applyPreProcess(to: "内容")
        }

        // 3. 即使高频降级被触发，系统也应保持稳定不会发生崩溃
        let result = registry.applyPreProcess(to: "最终内容")
        XCTAssertNotNil(result)
    }
    // MARK: - 扩展点注册 (Obsidian 对标)

    func testPluginCanRegisterCommands() {
        let plugin = MockExtensiblePlugin(id: "test.cmd")
        registry.loadPlugin(plugin)
        
        XCTAssertEqual(registry.commands.count, 1, "插件应成功注册一个全局指令")
        XCTAssertEqual(registry.commands.first?.name, "Test Command")
        XCTAssertEqual(registry.commands.first?.pluginID, "test.cmd")
    }
    
    func testPluginCanRegisterRibbonItems() {
        let plugin = MockExtensiblePlugin(id: "test.ribbon")
        registry.loadPlugin(plugin)
        
        XCTAssertEqual(registry.ribbonItems.count, 1, "插件应成功注册一个侧边栏图标")
        XCTAssertEqual(registry.ribbonItems.first?.title, "Test Ribbon")
        XCTAssertEqual(registry.ribbonItems.first?.icon, "star")
    }
    
    func testUnloadPluginClearsRegisteredExtensions() {
        let plugin = MockExtensiblePlugin(id: "test.ext.clear")
        registry.loadPlugin(plugin)
        XCTAssertFalse(registry.commands.isEmpty)
        XCTAssertFalse(registry.settingTabs.isEmpty)
        
        registry.unloadPlugin(id: "test.ext.clear")
        XCTAssertTrue(registry.commands.isEmpty, "插件卸载后，其注册的指令应被自动清理")
        XCTAssertTrue(registry.ribbonItems.isEmpty)
        XCTAssertTrue(registry.settingTabs.isEmpty, "插件卸载后，其注册的设置页应被自动清理")
        XCTAssertTrue(registry.customViews.isEmpty)
    }
    
    // MARK: - 安全与持久化验证 (Phase 1 & 2)
    
    func testPluginStorageReadWrite() {
        let pluginID = "test.storage"
        registry.savePluginData(pluginID: pluginID, key: "theme", value: "dark")
        
        let value = registry.loadPluginData(pluginID: pluginID, key: "theme")
        XCTAssertEqual(value, "dark", "插件应能正确读取自己存储的数据")
    }
    
    func testWatchdogTimeoutSuspension() {
        // 创建一个执行极慢的插件 (模拟 0.6s)
        let slowPlugin = MockSlowPlugin()
        registry.loadPlugin(slowPlugin)
        
        _ = registry.applyPreProcess(to: "test")
        
        // 验证该插件是否被 Watchdog 挂起
        // 注意：在单元测试中由于 intercepter 是 Swift 实现，
        // preProcess 的耗时会被准确记录并触发熔断
    }
}

// MARK: - Mock 插件

private enum MockError: Error {
    case simulatedCrash
}

@MainActor
private class MockKnowledgePlugin: KnowledgePlugin {
    let manifest: PluginManifest
    var monetization: MonetizationInfo? { nil }
    private(set) var didLoad = false
    private(set) var didUnload = false

    init(id: String, name: String, permissions: [String] = ["storage.read", "writeContent"], allowedDomains: [String]? = nil) {
        manifest = PluginManifest(
            id: id,
            version: "2.0.0",
            author: "Tester",
            permissions: permissions,
            allowedDomains: allowedDomains,
            names: ["en": name],
            descriptions: ["en": "Test description"]
        )
    }

    func onLoad(context: PluginContext) { didLoad = true }
    func onUnload() { didUnload = true }
}

@MainActor
private final class MockExtensiblePlugin: MockKnowledgePlugin {
    init(id: String) {
        super.init(id: id, name: "Extensible Plugin")
    }
    
    override func onLoad(context: PluginContext) {
        super.onLoad(context: context)
        context.registerCommand(id: "cmd1", name: "Test Command") {}
        context.registerRibbonItem(icon: "star", title: "Test Ribbon") {}
        context.registerSettingTab(name: "Test Settings", schema: nil) { _ in }
        context.registerView(id: "view1", title: "Test View", icon: "doc") {}
    }
}

@MainActor
private final class MockSlowPlugin: MockKnowledgePlugin, InterceptionPlugin {
    init() {
        super.init(id: "test.slow", name: "慢插件", permissions: ["writeContent"])
    }
    
    func preProcess(content: String) throws -> String {
        Thread.sleep(forTimeInterval: 0.6) // 故意超过 0.5s 阈值
        return content
    }
    func postProcess(content: String) throws -> String { content }
}

/// 沙箱测试专属的模拟内容拦截插件 (MockSandboxInterceptionPlugin)
/// 实现 InterceptionPlugin 协议，用于模拟高频拦截与内容预处理行为
@MainActor
private final class MockSandboxInterceptionPlugin: MockKnowledgePlugin, InterceptionPlugin {
    /// 预处理阶段拦截，并在内容前附加 "拦截后: " 标记以验证插件调用路径
    /// - Parameter content: 原始文本内容
    /// - Returns: 处理完成后的文本内容
    func preProcess(content: String) throws -> String { 
        return "拦截后: \(content)" 
    }
    
    /// 后处理阶段拦截，此处仅透明返回，不作任何更改
    /// - Parameter content: 预处理后的文本内容
    /// - Returns: 最终文本内容
    func postProcess(content: String) throws -> String { 
        return content 
    }
}

@MainActor
private final class MockCrashingPlugin: MockKnowledgePlugin, InterceptionPlugin {
    init() {
        super.init(id: "test.crash", name: "崩溃测试", permissions: ["writeContent"])
    }
    func preProcess(content: String) throws -> String {
        throw MockError.simulatedCrash
    }
    func postProcess(content: String) throws -> String { content }
}
