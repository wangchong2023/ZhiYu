//
//  IngestQueueTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 IngestQueue 开展自动化单元测试验证。
//
import XCTest
import Combine
@testable import ZhiYuUnitTestHost

/// 边界与异常测试 (Expert QA Item #4)
/// 模拟极端环境下的 IngestQueue 表现。
@MainActor
final class IngestQueueTests: XCTestCase {
    var store: AppStore!
    var llmService: MockLLMService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
        store = AppStore()
        llmService = MockLLMService()
        cancellables = []
    }

    override func tearDown() async throws {
        // 清理 Combine 订阅，避免 IngestQueue.shared.isProcessing 变化
        // 触发已失效的 sink 闭包（跨测试残留导致 XCTestExpectation 多次 fulfill）
        cancellables.removeAll()
        store = nil
        llmService = nil
        try await super.tearDown()
    }
    
    /// 模拟异步处理流程中的状态流转
    func testQueueProcessingStatusFlow() async throws {
        let queue = IngestQueue.shared
        let dummyContent = "Test Content"
        
        let expectation = expectation(description: "Queue should finish processing")
        
        // 观察 isProcessing 变化
        queue.$isProcessing
            .dropFirst()
            .sink { isProcessing in
                if !isProcessing { expectation.fulfill() }
            }
            .store(in: &cancellables)
        
        // 2. 压入任务
        queue.enqueue(
            title: "BoundaryTest",
            content: dummyContent,
            llmService: llmService,
            pages: [],
            onResult: { _ in }
        )
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // 3. 验证队列状态已重置
        XCTAssertFalse(queue.isProcessing, "即便完成任务，队列也必须重置状态")
        XCTAssertEqual(queue.pendingCount, 0, "计数器必须归零")
    }

    /// 缺陷 #182 回归：Vault 切换发出 .vaultWillSwitch 后必须立即取消队列并阻止旧任务回调写穿新 Vault
    func testVaultSwitchCancelsPendingIngestAndBlocksStaleCallback() async throws {
        let queue = IngestQueue.shared
        var callbackInvoked = false

        queue.enqueue(
            title: "VaultA_StaleNote",
            content: "旧 Vault 摄入正文",
            llmService: llmService,
            pages: [],
            onResult: { _ in
                callbackInvoked = true
            }
        )

        // 入队后立即切换 Vault
        NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)
        try? await Task.sleep(for: .milliseconds(150))

        XCTAssertFalse(queue.isProcessing, "切换 Vault 后 isProcessing 必须复位")
        XCTAssertEqual(queue.pendingCount, 0, "切换 Vault 后 pendingCount 必须归零")
        XCTAssertFalse(callbackInvoked, "被 Vault 切换取消的旧任务绝不得回调写穿新 Vault")
    }

    /// 缺陷 #227 回归：空白内容不入队，批量入队时活跃并发数严格受限于 maxConcurrentTasks(2)
    func testEnqueue_rejectsBlankContentAndCapsActiveConcurrency() async throws {
        let queue = IngestQueue.shared

        // 1. 纯空白内容应直接忽略，不占用队列
        queue.enqueue(title: "Blank", content: "   \n\t  ", llmService: llmService, pages: [], onResult: { _ in })
        XCTAssertEqual(queue.pendingCount, 0)
        XCTAssertFalse(queue.isProcessing)

        // 2. 批量压入 5 个任务，立即检查并发数不超过上限 2，且最终全部完成
        let totalJobs = 5
        var completedCount = 0
        let allDone = expectation(description: "All queued ingest jobs completed")
        for index in 0..<totalJobs {
            queue.enqueue(
                title: "Batch_\(index)",
                content: "正文内容 \(index)",
                llmService: llmService,
                pages: [],
                onResult: { _ in
                    completedCount += 1
                    if completedCount == totalJobs {
                        allDone.fulfill()
                    }
                }
            )
            XCTAssertLessThanOrEqual(
                queue.activeTaskCount,
                IngestQueue.QueueLimits.maxConcurrentTasks,
                "并发活跃任务数不得突破 maxConcurrentTasks 上限"
            )
        }

        await fulfillment(of: [allDone], timeout: 5.0)
        XCTAssertEqual(queue.pendingCount, 0)
        XCTAssertEqual(queue.activeTaskCount, 0)
        XCTAssertFalse(queue.isProcessing)
    }
}
