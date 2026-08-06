//
//  UserDefaultsKeyStoreTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 UserDefaultsKeyStore 适配器的所有类型读写与删除操作。
//

import XCTest
@testable import ZhiYu

@MainActor
final class UserDefaultsKeyStoreTests: XCTestCase {

    private var store: UserDefaultsKeyStore!
    private var defaults: UserDefaults!
    private let testKey = "test.key.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        // 使用独立 suiteName 避免污染 .standard
        let suiteName = "UserDefaultsKeyStoreTests-\(UUID().uuidString)"
        guard let testDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建测试用 UserDefaults")
            return
        }
        defaults = testDefaults
        store = UserDefaultsKeyStore(defaults: defaults)
    }

    override func tearDown() {
        if let defaults {
            defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
        }
        store = nil
        defaults = nil
        super.tearDown()
    }

    // MARK: - init

    func testInit_默认使用Standard() {
        let standardStore = UserDefaultsKeyStore()
        // 不崩溃即通过；无法直接验证内部 defaults，但行为应正常
        standardStore.set(true, forKey: "init.test")
        XCTAssertTrue(standardStore.bool(forKey: "init.test"))
        standardStore.removeObject(forKey: "init.test")
    }

    func testShared_存在且可用() {
        let shared = UserDefaultsKeyStore.shared
        shared.set("value", forKey: "shared.test")
        XCTAssertEqual(shared.string(forKey: "shared.test"), "value")
        shared.removeObject(forKey: "shared.test")
    }

    // MARK: - Bool

    func testBool_未设置_返回false() {
        XCTAssertFalse(store.bool(forKey: testKey))
    }

    func testBool_设置true_返回true() {
        store.set(true, forKey: testKey)
        XCTAssertTrue(store.bool(forKey: testKey))
    }

    func testBool_设置false_返回false() {
        store.set(true, forKey: testKey)
        store.set(false, forKey: testKey)
        XCTAssertFalse(store.bool(forKey: testKey))
    }

    // MARK: - String

    func testString_未设置_返回nil() {
        XCTAssertNil(store.string(forKey: testKey))
    }

    func testString_设置值_返回值() {
        store.set("hello", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "hello")
    }

    func testString_设置空字符串_返回空字符串() {
        store.set("", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "")
    }

    // MARK: - Data

    func testData_未设置_返回nil() {
        XCTAssertNil(store.data(forKey: testKey))
    }

    func testData_设置值_返回值() {
        let data = Data([0x01, 0x02, 0x03])
        store.set(data, forKey: testKey)
        XCTAssertEqual(store.data(forKey: testKey), data)
    }

    // MARK: - Integer

    func testInteger_未设置_返回0() {
        XCTAssertEqual(store.integer(forKey: testKey), 0)
    }

    func testInteger_设置值_返回值() {
        store.set(42, forKey: testKey)
        XCTAssertEqual(store.integer(forKey: testKey), 42)
    }

    func testInteger_设置负数_返回负数() {
        store.set(-100, forKey: testKey)
        XCTAssertEqual(store.integer(forKey: testKey), -100)
    }

    // MARK: - Double

    func testDouble_未设置_返回0() {
        XCTAssertEqual(store.double(forKey: testKey), 0.0)
    }

    func testDouble_设置值_返回值() {
        store.set(3.14, forKey: testKey)
        XCTAssertEqual(store.double(forKey: testKey), 3.14, accuracy: 0.001)
    }

    // MARK: - Object

    func testObject_未设置_返回nil() {
        XCTAssertNil(store.object(forKey: testKey))
    }

    func testObject_设置数组_返回数组() {
        let array = ["a", "b", "c"] as NSArray
        store.set(array, forKey: testKey)
        let result = store.object(forKey: testKey) as? [String]
        XCTAssertEqual(result, ["a", "b", "c"])
    }

    // MARK: - removeObject

    func testRemoveObject_清除值() {
        store.set("value", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "value")
        store.removeObject(forKey: testKey)
        XCTAssertNil(store.string(forKey: testKey))
    }

    // MARK: - dictionaryRepresentation

    func testDictionaryRepresentation_包含已设置的键() {
        store.set("value", forKey: testKey)
        let dict = store.dictionaryRepresentation()
        XCTAssertNotNil(dict[testKey])
        XCTAssertEqual(dict[testKey] as? String, "value")
    }

    // MARK: - set(Any?, forKey:)

    func testSetAnyNil_清除已有值() {
        store.set("value", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "value")
        store.set(nil as Any?, forKey: testKey)
        XCTAssertNil(store.string(forKey: testKey))
    }
}
