//
//  StoreKitServiceTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 StoreKitService 的生命周期管理与状态属性逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class StoreKitServiceTests: XCTestCase {

    /// 被测服务（使用单例，因 init 为 private）
    private var service: StoreKitService { StoreKitService.shared }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        // 停止监听避免影响后续测试
        service.stopListening()
        service.isRestoring = false
        service.restoreMessage = nil
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    /// 验证 isRestoring 初始为 false
    func testIsRestoringInitialFalse() {
        XCTAssertFalse(service.isRestoring, "isRestoring 初始应为 false")
    }

    /// 验证 restoreMessage 初始为 nil
    func testRestoreMessageInitialNil() {
        XCTAssertNil(service.restoreMessage, "restoreMessage 初始应为 nil")
    }

    // MARK: - startListening / stopListening

    /// 验证 startListening 不崩溃且可重复调用
    func testStartListeningIdempotent() {
        service.startListening()
        service.startListening()
        // 重复调用不应崩溃（取消上一个 Task 重新注册）
        XCTAssertTrue(true, "重复 startListening 不应崩溃")
    }

    /// 验证 stopListening 不崩溃
    func testStopListeningNoCrash() {
        service.startListening()
        service.stopListening()
        // 再次 stop 也不应崩溃
        service.stopListening()
        XCTAssertTrue(true, "stopListening 不应崩溃")
    }

    // MARK: - restorePurchases
    // 注：restorePurchases 调用 StoreKit.AppStore.sync()，在模拟器无沙盒账号时会挂起超时。
    // 此测试在 CI 模拟器环境不可靠，跳过。真实环境验证依赖沙盒账号配置。
}
