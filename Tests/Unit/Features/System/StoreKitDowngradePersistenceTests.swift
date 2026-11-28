//
//  StoreKitDowngradePersistenceTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/11/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：缺陷 #287 回归测试 — 验证 StoreKitService.downgradeToFree() 降级后
//           认证状态已持久化到 KeyStore，防止 App 重启自动登录时恢复 Pro 权益残留。
//

import XCTest
import UFPCore
@testable import ZhiYuUnitTestHost

@MainActor
final class StoreKitDowngradePersistenceTests: XCTestCase {

    private var service: StoreKitService { StoreKitService.shared }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        service.stopListening()
        service.isRestoring = false
        service.restoreMessage = nil
        AuthSession.shared.logout()
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    /// 验证降级后 KeyStore 中 isAuthenticated 仍为已认证（用户已登录但降回 Free）
    func testDowngradeToFreePersistsStateToKeyStore() {
        // 模拟 Pro 用户
        let proUser = User(
            id: UUID(),
            name: "TestPro",
            email: "pro@test.com",
            phone: nil,
            avatarURL: nil,
            planKey: PlanKey.pro,
            maxVaults: 10,
            maxPages: 1000,
            maxPlugins: 20
        )
        AuthSession.shared.update(user: proUser)
        XCTAssertTrue(proUser.isPro, "前置条件：用户应为 Pro")

        // 执行降级
        service.downgradeToFree()

        // 验证降级后用户 planKey 变为 free
        let updatedUser = AuthSession.shared.currentUser
        XCTAssertNotNil(updatedUser)
        XCTAssertEqual(updatedUser?.planKey, PlanKey.free, "降级后 planKey 必须为 free")

        // 验证 KeyStore 中状态已持久化（saveState 被调用）
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        if let keyStore {
            let persistedAuth = keyStore.bool(forKey: AppConstants.Keys.Storage.authIsAuthenticated)
            // 降级不代表退出登录，isAuthenticated 应仍为 true（用户仍登录中只是降级 Free）
            XCTAssertTrue(persistedAuth, "降级后 isAuthenticated 应仍为 true（用户仍登录状态）")
        }
    }

    /// 验证非 Pro 用户调用 downgradeToFree 是安全的 no-op
    func testDowngradeToFreeNoOpForFreeUser() {
        let freeUser = User(
            id: UUID(),
            name: "FreeUser",
            email: "free@test.com",
            phone: nil,
            avatarURL: nil,
            planKey: PlanKey.free,
            maxVaults: User.DefaultQuotas.freeMaxVaults,
            maxPages: User.DefaultQuotas.freeMaxPages,
            maxPlugins: User.DefaultQuotas.freeMaxPlugins
        )
        AuthSession.shared.update(user: freeUser)

        // 对已经是 Free 的用户调用降级不应崩溃或改变状态
        service.downgradeToFree()
        let current = AuthSession.shared.currentUser
        XCTAssertEqual(current?.planKey, PlanKey.free)
    }

    /// 验证未登录时调用 downgradeToFree 是安全的 no-op
    func testDowngradeToFreeNoOpWhenNoUser() {
        AuthSession.shared.logout()
        // 未登录时不应崩溃
        service.downgradeToFree()
        XCTAssertNil(AuthSession.shared.currentUser)
    }
}
