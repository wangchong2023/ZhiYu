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
@testable import ZhiYuUnitTestHost

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
        XCTAssertNotNil(service)
    }

    /// 验证 stopListening 不崩溃
    func testStopListeningNoCrash() {
        service.startListening()
        service.stopListening()
        // 再次 stop 也不应崩溃
        service.stopListening()
        XCTAssertNotNil(service)
    }

    // MARK: - restorePurchases
    // 注：restorePurchases 调用 StoreKit.AppStore.sync()，在模拟器无沙盒账号时会挂起超时。
    // 此测试在 CI 模拟器环境不可靠，跳过。真实环境验证依赖沙盒账号配置。

    // MARK: - PaymentRetryQueue 边界防护（缺陷 #178）

    func testPaymentRetryQueueGuardsNegativeAttemptAndBlankEnqueue() async {
        let queue = PaymentRetryQueue.shared
        await queue.cancelAllPending()

        // 1. 负数 attemptCount 不得触发数组负索引越界崩溃，钳位至首档退避
        let negDelay = await queue.backoffDelay(for: -5)
        let firstDelay = await queue.backoffDelay(for: 0)
        XCTAssertEqual(negDelay, firstDelay, "负数 attemptCount 应安全钳位至 0 档退避")

        // 2. 空交易 ID / 空商品 ID / 空凭证必须被拒绝入队
        await queue.enqueue(productId: "pro.monthly", receiptData: "receipt", transactionId: "   ")
        await queue.enqueue(productId: "", receiptData: "receipt", transactionId: "tx-1")
        await queue.enqueue(productId: "pro.monthly", receiptData: " ", transactionId: "tx-2")
        let count = await queue.pendingCount
        XCTAssertEqual(count, 0, "空交易或空凭证记录不得入队")

        await queue.cancelAllPending()
    }

    // MARK: - AuthSession.logout 清空支付重试队列（缺陷 #183）

    func testAuthSessionLogoutClearsPaymentRetryQueue() async {
        let queue = PaymentRetryQueue.shared
        await queue.cancelAllPending()
        await queue.enqueue(productId: "pro.monthly", receiptData: "base64_receipt", transactionId: "tx_logout_guard")
        let beforeCount = await queue.pendingCount
        XCTAssertEqual(beforeCount, 1)

        AuthSession.shared.logout()
        try? await Task.sleep(for: .milliseconds(80))

        let afterCount = await queue.pendingCount
        XCTAssertEqual(afterCount, 0, "登出时必须清空待重试支付队列，防止跨账号错绑订阅权益")
    }

    // MARK: - ModelReceiptStore 路径穿越防护（缺陷 #181）

    func testModelReceiptStoreBlocksPathTraversalModelIDs() {
        let store = ModelReceiptStore.shared
        let maliciousIDs = ["", " ", ".", "..", "../secret", "dir/sub", "dir\\sub", "bad\nid"]
        for badID in maliciousIDs {
            XCTAssertNil(store.safeReceiptURL(for: badID), "非法 modelId 应被拦截: \(badID)")
        }
        XCTAssertNotNil(store.safeReceiptURL(for: "gemma-4-e2b-it"))
    }
}
