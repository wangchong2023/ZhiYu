//
//  KeychainServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 KeychainService 钥匙串存储/读取/删除 + testOverride 注入机制 + KeychainError 枚举。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class KeychainServiceTests: XCTestCase {

    /// 测试用 KeychainService 实例（不依赖真实 Keychain entitlements）
    private var service: KeychainService!

    override func setUp() {
        super.setUp()
        // 注册 KeyStoreProtocol mock，让 KeychainService 在模拟器无 entitlements 时
        // 可降级到 KeyStore 缓存路径（errSecMissingEntitlement -34018 回退）
        ServiceContainer.shared.register(
            UserDefaultsKeyStore.shared as any KeyStoreProtocol,
            for: (any KeyStoreProtocol).self
        )
        service = KeychainService()
    }

    override func tearDown() {
        service = nil
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    // MARK: - testOverride 注入机制

    func testTestOverride_设置后shared返回Mock实例() {
        let mock = MockKeychainService()
        let originalOverride = KeychainService.testOverride
        KeychainService.testOverride = mock
        defer { KeychainService.testOverride = originalOverride }

        XCTAssertTrue(KeychainService.shared === mock, "testOverride 设置后 shared 应返回 Mock 实例")
    }

    func testTestOverride_置nil后shared返回真实单例() {
        let originalOverride = KeychainService.testOverride
        KeychainService.testOverride = nil
        defer { KeychainService.testOverride = originalOverride }

        XCTAssertNil(KeychainService.testOverride, "testOverride 置 nil 后应为 nil")
        // shared 应返回真实单例（非 Mock）
        XCTAssertFalse(KeychainService.shared is MockKeychainService)
    }

    // MARK: - MockKeychainService 环回存储

    func testMockKeychainService_storeRetrieveDelete环回() throws {
        let mock = MockKeychainService()
        try mock.store(key: "test_key", value: "test_value")
        XCTAssertEqual(try mock.retrieve(key: "test_key"), "test_value")

        try mock.delete(key: "test_key")
        XCTAssertNil(try mock.retrieve(key: "test_key"))
    }

    func testMockKeychainService_retrieve不存在的key返回nil() throws {
        let mock = MockKeychainService()
        XCTAssertNil(try mock.retrieve(key: "nonexistent_key"))
    }

    func testMockKeychainService_store覆盖旧值() throws {
        let mock = MockKeychainService()
        try mock.store(key: "key", value: "value1")
        try mock.store(key: "key", value: "value2")
        XCTAssertEqual(try mock.retrieve(key: "key"), "value2")
    }

    // MARK: - KeychainError 枚举

    func testKeychainError_encodingFailed_errorDescription非空() {
        XCTAssertFalse(KeychainError.encodingFailed.errorDescription?.isEmpty ?? true)
    }

    func testKeychainError_storeFailed_errorDescription含状态码() {
        let status: OSStatus = -25291
        let error = KeychainError.storeFailed(status)
        XCTAssertTrue(error.errorDescription?.contains("\(status)") ?? false)
    }

    func testKeychainError_retrieveFailed_errorDescription含状态码() {
        let status: OSStatus = -25300
        let error = KeychainError.retrieveFailed(status)
        XCTAssertTrue(error.errorDescription?.contains("\(status)") ?? false)
    }

    func testKeychainError_deleteFailed_errorDescription含状态码() {
        let status: OSStatus = -25299
        let error = KeychainError.deleteFailed(status)
        XCTAssertTrue(error.errorDescription?.contains("\(status)") ?? false)
    }

    func testKeychainError_unexpectedData_errorDescription非空() {
        XCTAssertFalse(KeychainError.unexpectedData.errorDescription?.isEmpty ?? true)
    }

    // MARK: - 真实 KeychainService（模拟器无 entitlements 降级路径）

    /// 模拟器环境下 Keychain 通常返回 errSecMissingEntitlement，
    /// DEBUG 模式下应降级到 KeyStore（UserDefaults）回退缓存
    func testStore_模拟器降级到KeyStore缓存() throws {
        // 此测试验证 DEBUG 降级路径：模拟器无 entitlements 时写入 UserDefaults
        // 若真实 Keychain 可用（有 entitlements），则直接写入 Keychain
        try service.store(key: "batch6b_test_store", value: "test_value")
        // 不崩溃即通过（降级路径或真实 Keychain 均可）
    }

    func testRetrieve_模拟器降级从KeyStore缓存读取() throws {
        try service.store(key: "batch6b_test_retrieve", value: "retrieve_value")
        let retrieved = try service.retrieve(key: "batch6b_test_retrieve")
        // 降级路径或真实 Keychain 均应返回存储的值
        XCTAssertEqual(retrieved, "retrieve_value")
    }

    func testDelete_模拟器降级清理KeyStore缓存() throws {
        try service.store(key: "batch6b_test_delete", value: "delete_value")
        try service.delete(key: "batch6b_test_delete")
        // 删除后读取应返回 nil
        let retrieved = try service.retrieve(key: "batch6b_test_delete")
        XCTAssertNil(retrieved)
    }

    func testRetrieve_不存在的key返回nil() throws {
        let retrieved = try service.retrieve(key: "batch6b_nonexistent_\(UUID().uuidString)")
        XCTAssertNil(retrieved)
    }
}
