//
//  PluginStorageTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 PluginStorage 封禁列表持久化与私有数据委托逻辑。
//

import XCTest
@testable import ZhiYu
import UFPCore

@MainActor
final class PluginStorageTests: XCTestCase {

    private var storage: PluginStorage!
    private var mockKeyStore: MockKeyStoreForPluginStorage!

    override func setUp() async throws {
        try await super.setUp()
        mockKeyStore = MockKeyStoreForPluginStorage()
        ServiceContainer.shared.register(mockKeyStore as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)
        storage = PluginStorage()
    }

    override func tearDown() async throws {
        // P2-1 迁移：创建独立 UserDefaults 实例，避免 .shared 跨测试残留
        if let testDefaults = UserDefaults(suiteName: "PluginStorageTests-\(UUID().uuidString)") {
            ServiceContainer.shared.register(UserDefaultsKeyStore(defaults: testDefaults) as any KeyStoreProtocol, for: (any KeyStoreProtocol).self)
        }
        storage = nil
        mockKeyStore = nil
        try await super.tearDown()
    }

    // MARK: - loadSuspendedPluginIDs

    func testLoadSuspendedPluginIDs_noData_returnsEmptySet() {
        let ids = storage.loadSuspendedPluginIDs()
        XCTAssertTrue(ids.isEmpty)
    }

    func testLoadSuspendedPluginIDs_withData_returnsSet() {
        mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] = ["plugin.a", "plugin.b"]

        let ids = storage.loadSuspendedPluginIDs()

        XCTAssertEqual(ids, Set(["plugin.a", "plugin.b"]))
    }

    func testLoadSuspendedPluginIDs_withEmptyArray_returnsEmptySet() {
        mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] = [String]()

        let ids = storage.loadSuspendedPluginIDs()

        XCTAssertTrue(ids.isEmpty)
    }

    func testLoadSuspendedPluginIDs_withNonArrayData_returnsEmptySet() {
        mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] = "not an array"

        let ids = storage.loadSuspendedPluginIDs()

        XCTAssertTrue(ids.isEmpty)
    }

    func testLoadSuspendedPluginIDs_deduplicatesEntries() {
        mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] = ["plugin.a", "plugin.a", "plugin.b"]

        let ids = storage.loadSuspendedPluginIDs()

        XCTAssertEqual(ids.count, 2)
    }

    // MARK: - saveSuspendedPluginIDs

    func testSaveSuspendedPluginIDs_persistsArray() {
        let ids: Set<String> = ["plugin.x", "plugin.y"]

        storage.saveSuspendedPluginIDs(ids)

        let saved = mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] as? [String]
        XCTAssertNotNil(saved)
        XCTAssertEqual(Set(saved ?? []), ids)
    }

    func testSaveSuspendedPluginIDs_emptySet_persistsEmptyArray() {
        storage.saveSuspendedPluginIDs([])

        let saved = mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] as? [String]
        XCTAssertEqual(saved, [])
    }

    func testSaveSuspendedPluginIDs_overwritesPreviousValue() {
        storage.saveSuspendedPluginIDs(["plugin.a"])
        storage.saveSuspendedPluginIDs(["plugin.b"])

        let saved = mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] as? [String]
        XCTAssertEqual(Set(saved ?? []), ["plugin.b"])
    }

    // MARK: - clearSuspendedPluginIDs

    func testClearSuspendedPluginIDs_removesKey() {
        mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins] = ["plugin.a"]

        storage.clearSuspendedPluginIDs()

        XCTAssertNil(mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins])
    }

    func testClearSuspendedPluginIDs_whenNoData_doesNotCrash() {
        storage.clearSuspendedPluginIDs()

        XCTAssertNil(mockKeyStore.store[AppConstants.Keys.Storage.suspendedPlugins])
    }

    // MARK: - 往返一致性

    func testSaveThenLoad_returnsSameSet() {
        let original: Set<String> = ["plugin.1", "plugin.2", "plugin.3"]

        storage.saveSuspendedPluginIDs(original)
        let loaded = storage.loadSuspendedPluginIDs()

        XCTAssertEqual(loaded, original)
    }

    func testClearThenLoad_returnsEmpty() {
        storage.saveSuspendedPluginIDs(["plugin.a"])
        storage.clearSuspendedPluginIDs()
        let loaded = storage.loadSuspendedPluginIDs()

        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - 插件私有数据委托

    func testSavePluginData_thenLoad_returnsValue() {
        let pluginID = "test.plugin.save.\(UUID().uuidString)"
        storage.savePluginData(pluginID: pluginID, key: "theme", value: "dark")

        let value = storage.loadPluginData(pluginID: pluginID, key: "theme")
        XCTAssertEqual(value, "dark")
    }

    func testLoadPluginData_nonExistentKey_returnsNil() {
        let value = storage.loadPluginData(pluginID: "nonexistent.\(UUID().uuidString)", key: "nonexistent")
        XCTAssertNil(value)
    }

    func testLoadAllPluginData_returnsAllKeys() {
        let pluginID = "test.plugin.loadall.\(UUID().uuidString)"
        storage.savePluginData(pluginID: pluginID, key: "key1", value: "val1")
        storage.savePluginData(pluginID: pluginID, key: "key2", value: "val2")

        let allData = storage.loadAllPluginData(pluginID: pluginID)

        XCTAssertEqual(allData.count, 2)
        XCTAssertEqual(allData["key1"], "val1")
        XCTAssertEqual(allData["key2"], "val2")
    }

    func testSavePluginData_differentPlugins_isolated() {
        let pluginA = "plugin.a.\(UUID().uuidString)"
        let pluginB = "plugin.b.\(UUID().uuidString)"
        storage.savePluginData(pluginID: pluginA, key: "shared_key", value: "value_a")
        storage.savePluginData(pluginID: pluginB, key: "shared_key", value: "value_b")

        let valueA = storage.loadPluginData(pluginID: pluginA, key: "shared_key")
        let valueB = storage.loadPluginData(pluginID: pluginB, key: "shared_key")

        XCTAssertEqual(valueA, "value_a")
        XCTAssertEqual(valueB, "value_b")
    }

    func testSavePluginData_overwriteExistingKey() {
        let pluginID = "test.plugin.overwrite.\(UUID().uuidString)"
        storage.savePluginData(pluginID: pluginID, key: "key", value: "old")
        storage.savePluginData(pluginID: pluginID, key: "key", value: "new")

        let value = storage.loadPluginData(pluginID: pluginID, key: "key")
        XCTAssertEqual(value, "new")
    }
}

// MARK: - Mock KeyStore

@MainActor
private final class MockKeyStoreForPluginStorage: KeyStoreProtocol {
    var store: [String: Any] = [:]

    func bool(forKey key: String) -> Bool { store[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { store[key] as? String }
    func data(forKey key: String) -> Data? { store[key] as? Data }
    func integer(forKey key: String) -> Int { store[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { store[key] as? Double ?? 0 }
    func object(forKey key: String) -> Any? { store[key] }
    func set(_ value: Any?, forKey key: String) { store[key] = value }
    func set(_ value: Bool, forKey key: String) { store[key] = value }
    func removeObject(forKey key: String) { store.removeValue(forKey: key) }
    func dictionaryRepresentation() -> [String: Any] { store }
}
