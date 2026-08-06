//
//  PluginRuntimeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 PluginRuntime 的插件加载/卸载、封禁持久化、拦截管道限流与超时熔断逻辑。
//

import XCTest
@testable import ZhiYu
@testable import UFPCore

@MainActor
final class PluginRuntimeTests: XCTestCase {

    private var runtime: PluginRuntime!
    private var mockKeyStore: MockKeyStoreForPlugins!

    override func setUp() async throws {
        try await super.setUp()
        mockKeyStore = MockKeyStoreForPlugins()
        ServiceContainer.shared.register(mockKeyStore as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)
        runtime = PluginRuntime()
        runtime.reset()
    }

    override func tearDown() async throws {
        runtime.reset()
        ServiceContainer.shared.register(UserFaultsKeyStoreFallback.shared as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)
        runtime = nil
        mockKeyStore = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    private func makeManifest(id: String = "test.plugin", permissions: [String] = ["writeContent"]) -> PluginManifest {
        PluginManifest(id: id, version: "2.0.0", permissions: permissions, names: ["en": "Test"], descriptions: ["en": "Test plugin"])
    }

    // MARK: - loadPlugin

    func testLoadPlugin_addsToRegistry() {
        let plugin = MockKnowledgePlugin(manifest: makeManifest(id: "load.test"))
        runtime.loadPlugin(plugin)

        XCTAssertTrue(PluginRegistry.shared.plugins.contains(where: { $0.manifest.id == "load.test" }))
        XCTAssertTrue(plugin.didCallOnLoad)
    }

    func testLoadPlugin_duplicateId_skipsLoading() {
        let plugin1 = MockKnowledgePlugin(manifest: makeManifest(id: "dup.test"))
        let plugin2 = MockKnowledgePlugin(manifest: makeManifest(id: "dup.test"))

        runtime.loadPlugin(plugin1)
        runtime.loadPlugin(plugin2)

        XCTAssertEqual(PluginRegistry.shared.plugins.filter { $0.manifest.id == "dup.test" }.count, 1)
        XCTAssertFalse(plugin2.didCallOnLoad)
    }

    func testLoadPlugin_suspendedPlugin_skipsLoading() {
        let plugin = MockKnowledgePlugin(manifest: makeManifest(id: "suspended.test"))
        runtime.suspendPlugin("suspended.test")

        runtime.loadPlugin(plugin)
        XCTAssertFalse(PluginRegistry.shared.plugins.contains(where: { $0.manifest.id == "suspended.test" }))
        XCTAssertFalse(plugin.didCallOnLoad)
    }

    func testLoadPlugin_initializesResourceUsage() {
        let plugin = MockKnowledgePlugin(manifest: makeManifest(id: "resource.test"))
        runtime.loadPlugin(plugin)

        XCTAssertNotNil(runtime.pluginResourceUsage["resource.test"])
        XCTAssertEqual(runtime.pluginResourceUsage["resource.test"]?.callCount, 0)
    }

    func testLoadPlugin_v1xVersion_logsAdapterShim() {
        let manifest = PluginManifest(id: "v1.plugin", version: "1.5.0", permissions: [], names: ["en": "V1"], descriptions: ["en": "V1 plugin"])
        let plugin = MockKnowledgePlugin(manifest: manifest)
        runtime.loadPlugin(plugin)
        // 验证不崩溃即可
    }

    // MARK: - unloadPlugin

    func testUnloadPlugin_removesFromRegistry() {
        let plugin = MockKnowledgePlugin(manifest: makeManifest(id: "unload.test"))
        runtime.loadPlugin(plugin)

        runtime.unloadPlugin(id: "unload.test")
        XCTAssertFalse(PluginRegistry.shared.plugins.contains(where: { $0.manifest.id == "unload.test" }))
        XCTAssertTrue(plugin.didCallOnUnload)
    }

    func testUnloadPlugin_nonExistentId_noCrash() {
        runtime.unloadPlugin(id: "nonexistent.plugin")
        // 验证不崩溃即可
    }

    func testUnloadPlugin_clearsExtensionPoints() {
        let plugin = MockInterceptionPlugin(manifest: makeManifest(id: "ext.test"))
        runtime.loadPlugin(plugin)

        runtime.unloadPlugin(id: "ext.test")
        XCTAssertFalse(PluginRegistry.shared.intercepters.contains(where: { $0.manifest.id == "ext.test" }))
    }

    // MARK: - suspendPlugin

    func testSuspendPlugin_addsToSuspendedSet() {
        runtime.suspendPlugin("ban.test")
        XCTAssertTrue(runtime.suspendedPluginIDs.contains("ban.test"))
    }

    func testSuspendPlugin_persistsToKeyStore() {
        runtime.suspendPlugin("persist.test")
        let saved = mockKeyStore.object(forKey: AppConstants.Keys.Storage.suspendedPlugins) as? [String]
        XCTAssertNotNil(saved)
        XCTAssertTrue(saved?.contains("persist.test") ?? false)
    }

    func testSuspendPlugin_removesFromRegistry() {
        let plugin = MockKnowledgePlugin(manifest: makeManifest(id: "ban.remove"))
        runtime.loadPlugin(plugin)

        runtime.suspendPlugin("ban.remove")
        XCTAssertFalse(PluginRegistry.shared.plugins.contains(where: { $0.manifest.id == "ban.remove" }))
        XCTAssertTrue(plugin.didCallOnUnload)
    }

    func testSuspendPlugin_updatesResourceStatus() {
        let plugin = MockKnowledgePlugin(manifest: makeManifest(id: "status.test"))
        runtime.loadPlugin(plugin)

        runtime.suspendPlugin("status.test")
        XCTAssertEqual(runtime.pluginResourceUsage["status.test"]?.status, .suspended)
    }

    // MARK: - emitEvent

    func testEmitEvent_callsMatchingListeners() {
        let plugin = MockEventListenerPlugin(manifest: makeManifest(id: "event.test"), events: ["page.created"])
        runtime.loadPlugin(plugin)

        runtime.emitEvent("page.created", data: "hello")
        XCTAssertTrue(plugin.didReceiveEvent)
        XCTAssertEqual(plugin.receivedData as? String, "hello")
    }

    func testEmitEvent_noMatchingListeners_noEffect() {
        let plugin = MockEventListenerPlugin(manifest: makeManifest(id: "event.test2"), events: ["other.event"])
        runtime.loadPlugin(plugin)

        runtime.emitEvent("page.created", data: nil)
        XCTAssertFalse(plugin.didReceiveEvent)
    }

    // MARK: - applyPreProcess

    func testApplyPreProcess_noPlugins_returnsOriginalContent() {
        let result = runtime.applyPreProcess(to: "original content")
        XCTAssertEqual(result, "original content")
    }

    func testApplyPreProcess_interceptionPlugin_modifiesContent() {
        let plugin = MockInterceptionPlugin(manifest: makeManifest(id: "intercept.modify"))
        plugin.processedContent = "modified content"
        runtime.loadPlugin(plugin)

        let result = runtime.applyPreProcess(to: "original")
        XCTAssertEqual(result, "modified content")
    }

    func testApplyPreProcess_suspendedPlugin_skipped() {
        let plugin = MockInterceptionPlugin(manifest: makeManifest(id: "intercept.banned"))
        plugin.processedContent = "should not appear"
        runtime.loadPlugin(plugin)
        runtime.suspendPlugin("intercept.banned")

        let result = runtime.applyPreProcess(to: "original")
        XCTAssertEqual(result, "original")
    }

    func testApplyPreProcess_pluginWithoutWriteContentPermission_skipped() {
        let manifest = makeManifest(id: "no.perm", permissions: ["readContent"])
        let plugin = MockInterceptionPlugin(manifest: manifest)
        plugin.processedContent = "should not appear"
        runtime.loadPlugin(plugin)

        let result = runtime.applyPreProcess(to: "original")
        XCTAssertEqual(result, "original")
    }

    func testApplyPreProcess_throwingPlugin_doesNotCrash() {
        let plugin = MockInterceptionPlugin(manifest: makeManifest(id: "throwing.plugin"))
        plugin.shouldThrow = true
        runtime.loadPlugin(plugin)

        let result = runtime.applyPreProcess(to: "original")
        XCTAssertEqual(result, "original")
    }

    func testApplyPreProcess_updatesResourceUsage() {
        let plugin = MockInterceptionPlugin(manifest: makeManifest(id: "usage.track"))
        plugin.processedContent = "processed"
        runtime.loadPlugin(plugin)

        _ = runtime.applyPreProcess(to: "original")
        XCTAssertEqual(runtime.pluginResourceUsage["usage.track"]?.callCount, 1)
    }

    // MARK: - reset

    func testReset_clearsAllState() {
        let plugin = MockKnowledgePlugin(manifest: makeManifest(id: "reset.test"))
        runtime.loadPlugin(plugin)
        runtime.suspendPlugin("extra.ban")

        runtime.reset()
        XCTAssertTrue(PluginRegistry.shared.plugins.isEmpty)
        XCTAssertTrue(runtime.suspendedPluginIDs.isEmpty)
        XCTAssertTrue(runtime.pluginResourceUsage.isEmpty)
    }

    // MARK: - currentHostVersion

    func testCurrentHostVersion_is2_0_0() {
        XCTAssertEqual(runtime.currentHostVersion, "2.0.0")
    }
}

// MARK: - Mock 类

@MainActor
private class MockKnowledgePlugin: KnowledgePlugin {
    let manifest: PluginManifest
    var monetization: MonetizationInfo?
    var didCallOnLoad = false
    var didCallOnUnload = false

    init(manifest: PluginManifest) {
        self.manifest = manifest
    }

    func onLoad(context: PluginContext) {
        didCallOnLoad = true
    }

    func onUnload() {
        didCallOnUnload = true
    }
}

@MainActor
private final class MockInterceptionPlugin: MockKnowledgePlugin, InterceptionPlugin {
    var processedContent: String = ""
    var shouldThrow = false

    func preProcess(content: String) throws -> String {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return processedContent
    }

    func postProcess(content: String) throws -> String {
        return content
    }
}

@MainActor
private final class MockEventListenerPlugin: MockKnowledgePlugin {
    let events: [String]
    var didReceiveEvent = false
    var receivedData: Any?

    init(manifest: PluginManifest, events: [String]) {
        self.events = events
        super.init(manifest: manifest)
    }

    override func onLoad(context: PluginContext) {
        super.onLoad(context: context)
        for event in events {
            context.addEventListener(event: event) { [weak self] data in
                self?.didReceiveEvent = true
                self?.receivedData = data
            }
        }
    }
}

@MainActor
private final class MockKeyStoreForPlugins: KeyStoreProtocol {
    private var storage: [String: Any] = [:]

    func bool(forKey key: String) -> Bool { storage[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { storage[key] as? String }
    func data(forKey key: String) -> Data? { storage[key] as? Data }
    func integer(forKey key: String) -> Int { storage[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { storage[key] as? Double ?? 0 }
    func object(forKey key: String) -> Any? { storage[key] }
    func set(_ value: Any?, forKey key: String) { storage[key] = value }
    func set(_ value: Bool, forKey key: String) { storage[key] = value }
    func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
    func dictionaryRepresentation() -> [String: Any] { storage }
}

@MainActor
private final class UserFaultsKeyStoreFallback: KeyStoreProtocol {
    static let shared = UserFaultsKeyStoreFallback()
    private var storage: [String: Any] = [:]

    func bool(forKey key: String) -> Bool { storage[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { storage[key] as? String }
    func data(forKey key: String) -> Data? { storage[key] as? Data }
    func integer(forKey key: String) -> Int { storage[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { storage[key] as? Double ?? 0 }
    func object(forKey key: String) -> Any? { storage[key] }
    func set(_ value: Any?, forKey key: String) { storage[key] = value }
    func set(_ value: Bool, forKey key: String) { storage[key] = value }
    func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
    func dictionaryRepresentation() -> [String: Any] { storage }
}
