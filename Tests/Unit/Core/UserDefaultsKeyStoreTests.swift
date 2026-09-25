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

    func testInitDefaultsToStandard() {
        let standardStore = UserDefaultsKeyStore()
        // 不崩溃即通过；无法直接验证内部 defaults，但行为应正常
        standardStore.set(true, forKey: "init.test")
        XCTAssertTrue(standardStore.bool(forKey: "init.test"))
        standardStore.removeObject(forKey: "init.test")
    }

    func testSharedExistsAndUsable() {
        let shared = UserDefaultsKeyStore.shared
        shared.set("value", forKey: "shared.test")
        XCTAssertEqual(shared.string(forKey: "shared.test"), "value")
        shared.removeObject(forKey: "shared.test")
    }

    // MARK: - Bool

    func testBoolNotSetReturnsFalse() {
        XCTAssertFalse(store.bool(forKey: testKey))
    }

    func testBoolSetTrueReturnsTrue() {
        store.set(true, forKey: testKey)
        XCTAssertTrue(store.bool(forKey: testKey))
    }

    func testBoolSetFalseReturnsFalse() {
        store.set(true, forKey: testKey)
        store.set(false, forKey: testKey)
        XCTAssertFalse(store.bool(forKey: testKey))
    }

    // MARK: - String

    func testStringNotSetReturnsNil() {
        XCTAssertNil(store.string(forKey: testKey))
    }

    func testStringSetValueReturnsValue() {
        store.set("hello", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "hello")
    }

    func testStringSetEmptyStringReturnsEmptyString() {
        store.set("", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "")
    }

    // MARK: - Data

    func testDataNotSetReturnsNil() {
        XCTAssertNil(store.data(forKey: testKey))
    }

    func testDataSetValueReturnsValue() {
        let data = Data([0x01, 0x02, 0x03])
        store.set(data, forKey: testKey)
        XCTAssertEqual(store.data(forKey: testKey), data)
    }

    // MARK: - Integer

    func testIntegerNotSetReturns0() {
        XCTAssertEqual(store.integer(forKey: testKey), 0)
    }

    func testIntegerSetValueReturnsValue() {
        store.set(42, forKey: testKey)
        XCTAssertEqual(store.integer(forKey: testKey), 42)
    }

    func testIntegerSetNegativeReturnsNegative() {
        store.set(-100, forKey: testKey)
        XCTAssertEqual(store.integer(forKey: testKey), -100)
    }

    // MARK: - Double

    func testDoubleNotSetReturns0() {
        XCTAssertEqual(store.double(forKey: testKey), 0.0)
    }

    func testDoubleSetValueReturnsValue() {
        store.set(3.14, forKey: testKey)
        XCTAssertEqual(store.double(forKey: testKey), 3.14, accuracy: 0.001)
    }

    // MARK: - Object

    func testObjectNotSetReturnsNil() {
        XCTAssertNil(store.object(forKey: testKey))
    }

    func testObjectSetArrayReturnsArray() {
        let array = ["a", "b", "c"] as NSArray
        store.set(array, forKey: testKey)
        let result = store.object(forKey: testKey) as? [String]
        XCTAssertEqual(result, ["a", "b", "c"])
    }

    // MARK: - removeObject

    func testRemoveObjectClearsValue() {
        store.set("value", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "value")
        store.removeObject(forKey: testKey)
        XCTAssertNil(store.string(forKey: testKey))
    }

    // MARK: - dictionaryRepresentation

    func testDictionaryRepresentationContainsSetKey() {
        store.set("value", forKey: testKey)
        let dict = store.dictionaryRepresentation()
        XCTAssertNotNil(dict[testKey])
        XCTAssertEqual(dict[testKey] as? String, "value")
    }

    // MARK: - set(Any?, forKey:)

    func testSetAnyNilClearsExistingValue() {
        store.set("value", forKey: testKey)
        XCTAssertEqual(store.string(forKey: testKey), "value")
        store.set(nil as Any?, forKey: testKey)
        XCTAssertNil(store.string(forKey: testKey))
    }
}
