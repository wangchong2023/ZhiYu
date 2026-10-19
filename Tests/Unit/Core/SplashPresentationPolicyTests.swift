//
//  SplashPresentationPolicyTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 测试层
//  核心职责：验证 SplashPresentationPolicy 在所有条件分支（首次启动/非首次冷启动/已登录/UI测试）下的判断与持久化正确性。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class SplashPresentationPolicyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SplashPresentationPolicy.resetSplashState()
    }

    override func tearDown() {
        SplashPresentationPolicy.resetSplashState()
        super.tearDown()
    }

    // MARK: - shouldSkipSplash 纯逻辑评估测试

    func testShouldSkipSplash_firstLaunchNotLoggedIn_returnsFalse() {
        // 首次打开、未登录、非 UI 测试：应当展示闪屏 (返回 false)
        let shouldSkip = SplashPresentationPolicy.shouldSkipSplash(
            isUITesting: false,
            hasSeenSplashBefore: false,
            isLoggedIn: false
        )
        XCTAssertFalse(shouldSkip, "首次冷启动且未登录状态下不应跳过闪屏")
    }

    func testShouldSkipSplash_nonFirstLaunchSeenBefore_returnsTrue() {
        // 非首次冷启动（已在持久化中记录看过）：应当跳过闪屏快速进入主界面 (返回 true)
        let shouldSkip = SplashPresentationPolicy.shouldSkipSplash(
            isUITesting: false,
            hasSeenSplashBefore: true,
            isLoggedIn: false
        )
        XCTAssertTrue(shouldSkip, "非首次冷启动（已记录看过）应跳过闪屏")
    }

    func testShouldSkipSplash_userLoggedIn_returnsTrue() {
        // 用户已处于登录状态（首次或恢复会话）：应当跳过闪屏快速进入主界面 (返回 true)
        let shouldSkip = SplashPresentationPolicy.shouldSkipSplash(
            isUITesting: false,
            hasSeenSplashBefore: false,
            isLoggedIn: true
        )
        XCTAssertTrue(shouldSkip, "用户已登录状态下应直接跳过闪屏")
    }

    func testShouldSkipSplash_uiTesting_returnsTrue() {
        // UI 测试环境下：始终跳过闪屏，防止遮挡测试视图 (返回 true)
        let shouldSkip = SplashPresentationPolicy.shouldSkipSplash(
            isUITesting: true,
            hasSeenSplashBefore: false,
            isLoggedIn: false
        )
        XCTAssertTrue(shouldSkip, "UI 测试环境下应跳过闪屏")
    }

    // MARK: - 持久化与状态重置测试

    func testMarkSplashSeenAndHasSeenSplashBefore_persistsState() {
        XCTAssertFalse(SplashPresentationPolicy.hasSeenSplashBefore(), "初始化时应为 false")

        SplashPresentationPolicy.markSplashSeen()
        XCTAssertTrue(SplashPresentationPolicy.hasSeenSplashBefore(), "调用 markSplashSeen 后应持久化为 true")

        SplashPresentationPolicy.resetSplashState()
        XCTAssertFalse(SplashPresentationPolicy.hasSeenSplashBefore(), "调用 resetSplashState 后应恢复为 false")
    }

    func testKeyStoreIntegration_readsAndWritesProperly() {
        final class InMemoryKeyStore: KeyStoreProtocol, @unchecked Sendable {
            private var dict: [String: Any] = [:]
            func bool(forKey key: String) -> Bool {
                dict[key] as? Bool ?? false
            }
            func set(_ value: Bool, forKey key: String) {
                dict[key] = value
            }
            func removeObject(forKey key: String) {
                dict.removeValue(forKey: key)
            }
            func string(forKey key: String) -> String? { dict[key] as? String }
            func integer(forKey key: String) -> Int { dict[key] as? Int ?? 0 }
            func double(forKey key: String) -> Double { dict[key] as? Double ?? 0.0 }
            func data(forKey key: String) -> Data? { dict[key] as? Data }
            func object(forKey key: String) -> Any? { dict[key] }
            func set(_ value: Any?, forKey key: String) { dict[key] = value }
            func dictionaryRepresentation() -> [String: Any] { dict }
        }

        let store = InMemoryKeyStore()
        XCTAssertFalse(SplashPresentationPolicy.hasSeenSplashBefore(keyStore: store))

        SplashPresentationPolicy.markSplashSeen(keyStore: store)
        XCTAssertTrue(SplashPresentationPolicy.hasSeenSplashBefore(keyStore: store))

        SplashPresentationPolicy.resetSplashState(keyStore: store)
        XCTAssertFalse(SplashPresentationPolicy.hasSeenSplashBefore(keyStore: store))
    }
}
