//
//  PluginWatchdogTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 PluginWatchdog 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu
@testable import UFPCore

// MARK: - 模拟拦截器插件
/// 用于模拟各种安全行为和性能指标的看门狗测试专用 Mock 插件
@MainActor
final class MockWatchdogInterceptionPlugin: KnowledgePlugin, InterceptionPlugin {
    /// 插件元数据声明
    let manifest: PluginManifest
    
    /// 商业化模式协议桩：默认声明为 nil
    var monetization: MonetizationInfo? { nil }
    
    /// 模拟插件预处理动作的持续时间
    var processDuration: TimeInterval = 0.0
    
    /// 模拟插件运行期是否抛出崩溃异常的标记
    var shouldThrowError = false
    
    /// 记录前置预处理被触发的总计数
    var preProcessCallCount = 0
    
    /// 自定义拦截后替换成的文本内容
    var customReplacement: String?
    
    /// 初始化测试专用看门狗 Mock 插件
    /// - Parameters:
    ///   - id: 插件唯一标识符
    ///   - permissions: 声明持有的权限数组
    ///   - duration: 模拟处理耗时（秒）
    ///   - shouldThrow: 模拟是否在运行时崩溃抛出 Error
    init(id: String, permissions: [String], duration: TimeInterval = 0.0, shouldThrow: Bool = false) {
        self.manifest = PluginManifest(
            id: id,
            version: "1.0.0",
            author: "Mock Author",
            permissions: permissions,
            names: ["en": "Mock Plugin"],
            descriptions: ["en": "For testing watchdog functionality"]
        )
        self.processDuration = duration
        self.shouldThrowError = shouldThrow
    }
    
    /// 插件加载回调桩
    func onLoad(context: any PluginContext) {}
    
    /// 插件卸载回调桩
    func onUnload() {}
    
    /// 核心前置拦截预处理方法实现：验证时间熔断与抛错隔离
    func preProcess(content: String) throws -> String {
        preProcessCallCount += 1
        
        // 1. 若开启了模拟崩溃选项，物理抛出 JavaScript 崩溃异常
        if shouldThrowError {
            struct MockPluginError: Error, LocalizedError {
                var errorDescription: String? { "Mock JavaScript crash inside preProcess." }
            }
            throw MockPluginError()
        }
        
        // 2. 若配置了非零的耗时时间，以 Thread.sleep 模拟插件主线程超时卡死
        if processDuration > 0 {
            Thread.sleep(forTimeInterval: processDuration)
        }
        
        // 3. 返回转换后的全大写文本或自定义内容以供 XCTAssert 校验
        return customReplacement ?? content.uppercased()
    }
    
    /// 核心后置渲染拦截方法实现：提供符合协议的最简透明返回
    func postProcess(content: String) throws -> String {
        return content
    }
}

// MARK: - 看门狗与安全沙盒测试套件
@MainActor
final class PluginWatchdogTests: XCTestCase {
    
    private var registry: PluginRegistry!
    
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        registry = ServiceContainer.shared.resolve(PluginRegistry.self)
        registry.reset() // 重置为初始空白状态
    }
    
    override func tearDown() async throws {
        registry.reset()
        registry = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. 物理超时熔断测试
    /// 验证当插件执行耗时超过看门狗限定阈值 (0.5s) 时，注册中心能立刻封禁隔离该插件并回收资源
    func testPluginRegistrySuspendsOnTimeout() {
        // 1. 创建一个运行时耗为 0.6s 的慢速插件 (超时阈值为 0.5s)，利用全新的看门狗 Mock 插件实例化
        let slowPlugin = MockWatchdogInterceptionPlugin(id: "plugin.slow", permissions: ["writeContent"], duration: 0.6)
        
        registry.loadPlugin(slowPlugin)
        
        // 第一次调用预处理，应该能调用进去，但由于执行时间 0.6s 超过 0.5s 阈值，会被自动触发熔断封禁
        let result = registry.applyPreProcess(to: "hello")
        
        // 熔断保护：丢弃该超时插件的处理结果，回退输出原内容，且该插件被物理卸载
        XCTAssertEqual(result, "hello")
        XCTAssertEqual(slowPlugin.preProcessCallCount, 1)
        
        // 验证插件已经被物理封禁，在活跃插件列表里被清除
        XCTAssertFalse(registry.plugins.contains { $0.manifest.id == "plugin.slow" })
        
        // 第二次再发起预处理调用时，该插件绝对不应再次被执行
        _ = registry.applyPreProcess(to: "world")
        XCTAssertEqual(slowPlugin.preProcessCallCount, 1, "已被熔断封禁的插件绝对不应该再次被触发调用")
    }
    
    // MARK: - 2. 权限管控安全拦截测试
    /// 验证当插件没有在 manifest 声明相应 writeContent 权限时，其试图改写内容的行为会被安全拦截
    func testPluginRegistrySecurityInterception() {
        // 1. 创建一个没有 'writeContent' 权限的安全不合规插件，利用重名隔离类 MockWatchdogInterceptionPlugin 构造
        let unauthorizedPlugin = MockWatchdogInterceptionPlugin(id: "plugin.unauthorized", permissions: ["log"])
        
        registry.loadPlugin(unauthorizedPlugin)
        
        // 执行过滤
        let result = registry.applyPreProcess(to: "hello")
        
        // 内容不应当被修改，且由于缺乏权限，其 preProcess 甚至根本不应被调用执行
        XCTAssertEqual(result, "hello")
        XCTAssertEqual(unauthorizedPlugin.preProcessCallCount, 0, "无权限的插件应当直接从高层拦截，不允许其内部方法运行")
    }
    
    // MARK: - 3. 异常奔溃物理隔离测试
    /// 验证当插件内部抛出 JS 异常或运行时崩溃时，沙箱能进行物理隔离，不会波及宿主 App 整体稳定性
    func testPluginRegistryCrashIsolation() {
        // 1. 实例化一个会在运行时抛出崩溃错误的插件
        let buggyPlugin = MockWatchdogInterceptionPlugin(id: "plugin.buggy", permissions: ["writeContent"], shouldThrow: true)
        
        registry.loadPlugin(buggyPlugin)
        
        // 执行调用，此时虽然插件 preProcess 抛出 Error，但注册中心能捕获并安全回退
        let result = registry.applyPreProcess(to: "hello")
        
        // 异常隔离：自动忽略该插件的处理结果，保障内容交付不中断
        XCTAssertEqual(result, "hello")
        XCTAssertEqual(buggyPlugin.preProcessCallCount, 1)
    }
    
    // MARK: - 4. 频繁调用频控（Throttling）限流降级测试
    /// 验证在高密并发调用下，超出频控安全阈值后，限流机制自动降级，阻截异常请求
    func testPluginRegistryThrottling() {
        // 1. 初始化并加载限流高频测试插件
        let activePlugin = MockWatchdogInterceptionPlugin(id: "plugin.heavy", permissions: ["writeContent"])
        registry.loadPlugin(activePlugin)
        
        // 频控上限是 50 次，我们连续发起 52 次过滤
        var lastResult = ""
        for _ in 1...52 {
            lastResult = registry.applyPreProcess(to: "hello")
        }
        
        // 前 50 次应正常执行，最后两次（51与52）超标，应当被降级限流
        XCTAssertEqual(activePlugin.preProcessCallCount, 51, "超限调用应当被直接 Throttled 截断")
        XCTAssertEqual(lastResult, "hello", "限流后应当返回原内容，不再经过插件处理")
    }
}
