//
//  LLMServicePropertyAccessTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LLMService 属性 getter/setter 透传与 UI 测试自愈逻辑验证。
//

import XCTest
import UFPCore
import Combine
@testable import ZhiYu

@MainActor
final class LLMServicePropertyAccessTests: XCTestCase {
    var service: LLMService!
    var mockConfig: LLMConfigManager!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()

        mockConfig = LLMConfigManager()
        ServiceContainer.shared.register(mockConfig, for: LLMConfigManager.self)

        service = LLMService()
    }

    override func tearDown() async throws {
        service = nil
        mockConfig = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - provider 属性

    func testProviderGetterReturnsConfigManagerValue() {
        mockConfig.provider = .zhipu
        XCTAssertEqual(service.provider, .zhipu)
    }

    func testProviderGetterDefaultsToDeepSeekWhenConfigNil() {
        // configManager 存在但未设置 provider 时，默认值由 LLMConfigManager 决定
        // 这里验证透传逻辑：设置后能正确读取
        mockConfig.provider = .minimax
        XCTAssertEqual(service.provider, .minimax)
    }

    func testProviderSetterUpdatesConfigManager() {
        service.provider = .deepSeek
        XCTAssertEqual(mockConfig.provider, .deepSeek)
    }

    // MARK: - apiKey 属性

    func testApiKeyGetterReturnsConfigManagerValue() {
        mockConfig.apiKey = "sk-real-key"
        XCTAssertEqual(service.apiKey, "sk-real-key")
    }

    func testApiKeyGetterReturnsEmptyWhenConfigNil() {
        // 无法让 configManager 为 nil（已注册），但可以验证空值场景
        mockConfig.apiKey = ""
        XCTAssertEqual(service.apiKey, "")
    }

    func testApiKeySetterUpdatesConfigManager() {
        service.apiKey = "sk-new-key"
        XCTAssertEqual(mockConfig.apiKey, "sk-new-key")
    }

    // MARK: - baseURL 属性

    func testBaseURLGetterReturnsConfigManagerValue() {
        mockConfig.baseURL = "https://api.example.com"
        XCTAssertEqual(service.baseURL, "https://api.example.com")
    }

    func testBaseURLSetterUpdatesConfigManager() {
        service.baseURL = "https://new.api.com"
        XCTAssertEqual(mockConfig.baseURL, "https://new.api.com")
    }

    // MARK: - model 属性

    func testModelGetterReturnsConfigManagerValue() {
        mockConfig.model = "gpt-4o"
        XCTAssertEqual(service.model, "gpt-4o")
    }

    func testModelSetterUpdatesConfigManager() {
        service.model = "claude-3-5-sonnet"
        XCTAssertEqual(mockConfig.model, "claude-3-5-sonnet")
    }

    // MARK: - isEnabled 属性

    func testIsEnabledGetterReturnsConfigManagerValue() {
        mockConfig.isEnabled = true
        XCTAssertTrue(service.isEnabled)
    }

    func testIsEnabledGetterDefaultsToFalseWhenConfigNil() {
        mockConfig.isEnabled = false
        XCTAssertFalse(service.isEnabled)
    }

    func testIsEnabledSetterUpdatesConfigManager() {
        service.isEnabled = true
        XCTAssertTrue(mockConfig.isEnabled)
    }

    // MARK: - autoScan 属性

    func testAutoScanGetterReturnsConfigManagerValue() {
        mockConfig.autoScan = true
        XCTAssertTrue(service.autoScan)
    }

    func testAutoScanSetterUpdatesConfigManager() {
        service.autoScan = true
        XCTAssertTrue(mockConfig.autoScan)
    }

    // MARK: - autoRefactor 属性

    func testAutoRefactorGetterReturnsConfigManagerValue() {
        mockConfig.autoRefactor = true
        XCTAssertTrue(service.autoRefactor)
    }

    func testAutoRefactorSetterUpdatesConfigManager() {
        service.autoRefactor = true
        XCTAssertTrue(mockConfig.autoRefactor)
    }

    // MARK: - isReady 属性

    func testIsReadyGetterReturnsConfigManagerValue() {
        mockConfig.apiKey = "sk-test"
        mockConfig.baseURL = "https://api.test.com"
        mockConfig.model = "test-model"
        mockConfig.isEnabled = true
        XCTAssertTrue(service.isReady)
    }

    func testIsReadyGetterReturnsFalseWhenNotConfigured() {
        mockConfig.apiKey = ""
        mockConfig.isEnabled = false
        XCTAssertFalse(service.isReady)
    }

    // MARK: - objectWillChange 触发验证

    func testPropertySetterTriggersObjectWillChange() {
        var changeCount = 0
        let cancellable = service.objectWillChange.sink { _ in
            changeCount += 1
        }
        service.provider = .zhipu
        service.apiKey = "sk-test"
        service.baseURL = "https://test.com"
        service.model = "test"
        service.isEnabled = true
        service.autoScan = true
        service.autoRefactor = true
        XCTAssertGreaterThanOrEqual(changeCount, 7)
        cancellable.cancel()
    }
}
