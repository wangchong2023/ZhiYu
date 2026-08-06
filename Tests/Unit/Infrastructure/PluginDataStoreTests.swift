//
//  PluginDataStoreTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 PluginDataStore 的加密存储/读取往返、多 key 合并、回退明文解码路径。
//

import XCTest
@testable import ZhiYu

final class PluginDataStoreTests: XCTestCase {

    private var store: PluginDataStore!
    private var originalOverride: SecurityManager?
    private let testPluginID = "test-plugin-batch7c"

    override func setUp() {
        super.setUp()
        originalOverride = SecurityManager.testOverride
        SecurityManager.testOverride = MockSecurityManager()
        store = PluginDataStore()
    }

    override func tearDown() {
        SecurityManager.testOverride = originalOverride
        cleanPluginDataFile()
        store = nil
        super.tearDown()
    }

    // MARK: - 辅助方法

    private func cleanPluginDataFile() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let dir = appSupport.appendingPathComponent("PluginsData")
        let file = dir.appendingPathComponent("\(testPluginID).json")
        try? fm.removeItem(at: file)
    }

    // MARK: - savePluginData / loadPluginData 往返

    func testSaveAndLoad_singleKey_returnsValue() {
        store.savePluginData(pluginID: testPluginID, key: "username", value: "alice")
        let result = store.loadPluginData(pluginID: testPluginID, key: "username")
        XCTAssertEqual(result, "alice")
    }

    func testSaveAndLoad_multipleKeys_allPersisted() {
        store.savePluginData(pluginID: testPluginID, key: "key1", value: "val1")
        store.savePluginData(pluginID: testPluginID, key: "key2", value: "val2")
        store.savePluginData(pluginID: testPluginID, key: "key3", value: "val3")

        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "key1"), "val1")
        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "key2"), "val2")
        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "key3"), "val3")
    }

    func testLoadPluginData_nonExistentKey_returnsNil() {
        let result = store.loadPluginData(pluginID: testPluginID, key: "nonexistent")
        XCTAssertNil(result)
    }

    func testLoadPluginData_nonExistentPlugin_returnsNil() {
        let result = store.loadPluginData(pluginID: "nonexistent-plugin-xyz", key: "key")
        XCTAssertNil(result)
    }

    // MARK: - 覆盖更新

    func testSavePluginData_overwriteExistingKey() {
        store.savePluginData(pluginID: testPluginID, key: "counter", value: "1")
        store.savePluginData(pluginID: testPluginID, key: "counter", value: "2")

        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "counter"), "2")
    }

    func testSavePluginData_emptyValue_persisted() {
        store.savePluginData(pluginID: testPluginID, key: "empty", value: "")
        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "empty"), "")
    }

    // MARK: - loadAllPluginData

    func testLoadAllPluginData_returnsAllKeys() {
        store.savePluginData(pluginID: testPluginID, key: "a", value: "1")
        store.savePluginData(pluginID: testPluginID, key: "b", value: "2")

        let all = store.loadAllPluginData(pluginID: testPluginID)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all["a"], "1")
        XCTAssertEqual(all["b"], "2")
    }

    func testLoadAllPluginData_emptyPlugin_returnsEmptyDict() {
        let all = store.loadAllPluginData(pluginID: "empty-plugin-xyz")
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - 多插件隔离

    func testSavePluginData_differentPlugins_isolated() {
        store.savePluginData(pluginID: testPluginID, key: "shared_key", value: "plugin_a_value")
        store.savePluginData(pluginID: "test-plugin-batch7c-b", key: "shared_key", value: "plugin_b_value")

        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "shared_key"), "plugin_a_value")
        XCTAssertEqual(store.loadPluginData(pluginID: "test-plugin-batch7c-b", key: "shared_key"), "plugin_b_value")

        cleanPluginDataFile(for: "test-plugin-batch7c-b")
    }

    // MARK: - 回退明文路径

    func testLoadAllPluginData_fallbackToPlaintextJSON() throws {
        // 直接写入明文 JSON（模拟旧版本或加密失败的数据）
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            XCTFail("无法获取 ApplicationSupportDirectory")
            return
        }
        let dir = appSupport.appendingPathComponent("PluginsData")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(testPluginID).json")

        let plaintextDict = ["fallback_key": "fallback_value"]
        let data = try JSONEncoder().encode(plaintextDict)
        try data.write(to: file)

        // MockSecurityManager.decrypt 会返回原文，但明文 JSON 不是 base64 → 解密失败 → 走回退路径
        let result = store.loadAllPluginData(pluginID: testPluginID)
        XCTAssertEqual(result["fallback_key"], "fallback_value")
    }

    // MARK: - 特殊字符

    func testSaveAndLoad_unicodeValue_persisted() {
        store.savePluginData(pluginID: testPluginID, key: "name", value: "你好世界")
        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "name"), "你好世界")
    }

    func testSaveAndLoad_specialCharacters_persisted() {
        let value = #"{"nested":"json","array":[1,2,3]}"#
        store.savePluginData(pluginID: testPluginID, key: "config", value: value)
        XCTAssertEqual(store.loadPluginData(pluginID: testPluginID, key: "config"), value)
    }

    // MARK: - 辅助方法

    private func cleanPluginDataFile(for pluginID: String) {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let dir = appSupport.appendingPathComponent("PluginsData")
        let file = dir.appendingPathComponent("\(pluginID).json")
        try? fm.removeItem(at: file)
    }
}
