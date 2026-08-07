//
//  LLMConfigManagerTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 LLMConfigManager 的 isReady 判定与 refreshHandler 触发
//

import XCTest
@testable import ZhiYu

@MainActor
final class LLMConfigManagerTests: XCTestCase {

    private var config: LLMConfigManager!

    override func setUp() {
        super.setUp()
        config = LLMConfigManager()
    }

    override func tearDown() {
        config = nil
        super.tearDown()
    }

    // MARK: - isReady

    func testIsReadyReturnsFalseWhenDisabled() {
        config.isEnabled = false
        config.apiKey = "sk-test-key"
        XCTAssertFalse(config.isReady)
    }

    func testIsReadyReturnsFalseWhenApiKeyEmpty() {
        config.isEnabled = true
        config.apiKey = ""
        XCTAssertFalse(config.isReady)
    }

    func testIsReadyReturnsFalseWhenDisabledAndEmptyKey() {
        config.isEnabled = false
        config.apiKey = ""
        XCTAssertFalse(config.isReady)
    }

    func testIsReadyReturnsTrueWhenEnabledAndKeyPresent() {
        config.isEnabled = true
        config.apiKey = "sk-test-key"
        XCTAssertTrue(config.isReady)
    }

    // MARK: - refreshHandler

    func testRefreshHandlerCalledWhenApiKeyChanges() {
        var callCount = 0
        config.setRefreshHandler {
            callCount += 1
        }

        config.apiKey = "new-key"
        XCTAssertGreaterThan(callCount, 0, "修改 apiKey 应触发 refreshHandler")
    }

    func testRefreshHandlerCalledWhenIsEnabledChanges() {
        var callCount = 0
        config.setRefreshHandler {
            callCount += 1
        }

        config.isEnabled = true
        XCTAssertGreaterThan(callCount, 0, "修改 isEnabled 应触发 refreshHandler")
    }

    func testRefreshHandlerCalledWhenBaseURLChanges() {
        var callCount = 0
        config.setRefreshHandler {
            callCount += 1
        }

        config.baseURL = "https://new.url/v1"
        XCTAssertGreaterThan(callCount, 0, "修改 baseURL 应触发 refreshHandler")
    }

    func testRefreshHandlerCalledWhenModelChanges() {
        var callCount = 0
        config.setRefreshHandler {
            callCount += 1
        }

        config.model = "new-model"
        XCTAssertGreaterThan(callCount, 0, "修改 model 应触发 refreshHandler")
    }

    // MARK: - 多 handler

    func testMultipleRefreshHandlersAllCalled() {
        var count1 = 0
        var count2 = 0
        config.setRefreshHandler { count1 += 1 }
        config.setRefreshHandler { count2 += 1 }

        config.apiKey = "trigger"
        XCTAssertGreaterThan(count1, 0)
        XCTAssertGreaterThan(count2, 0)
    }
}
