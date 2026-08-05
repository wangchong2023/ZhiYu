//
//  ServiceContainerProductionLockRaceTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 isProductionChainPopulated 标记的并发安全性。
//           问题 #8：reset() 与 markProductionChainComplete() 的竞态
//
//  修复方案：reset() 的「检查 isProductionChainPopulated + 清空 services」
//           在同一次 lock.withLock 内原子执行，消除两次 lock 之间的竞态窗口。
//
//  测试策略：
//  1. testResetAfterMarkIsBlocked：先 mark 后并发 reset，验证 reset 被阻止（确定性）
//  2. testResetForTestingClearsLockAndServices：验证 resetForTesting 同时清空标记和服务
//  3. testConcurrentMarkAndResetNoInconsistency：高并发压力测试，验证最终状态一致性
//     （注意：竞态窗口极窄，此测试主要作为回归保护，不能保证 100% 复现 bug）
//

import XCTest
@testable import UFPCore

private protocol RaceServiceProtocol: Sendable { var tag: String { get } }
private final class RaceService: RaceServiceProtocol, @unchecked Sendable {
    let tag = "race"
}

final class ServiceContainerProductionLockRaceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// 场景 1：先 markProductionChainComplete（锁定），再并发 reset()
    ///
    /// 确定性测试：mark 后 isProductionChainPopulated = true，
    /// reset() 在同一次 lock 内读到 true → 被阻止 → services 不被清空。
    func testResetAfterMarkIsBlocked() {
        let container = ServiceContainer.shared

        for _ in 0..<200 {
            container.resetForTesting()
            container.register(RaceService() as RaceServiceProtocol, for: RaceServiceProtocol.self)

            container.markProductionChainComplete()
            XCTAssertTrue(container.isProductionChainLocked,
                         "markProductionChainComplete 后必须锁定")

            // 10 个线程并发 reset，全部应被阻止
            DispatchQueue.concurrentPerform(iterations: 10) { _ in
                container.reset()
            }

            XCTAssertTrue(container.hasService(for: RaceServiceProtocol.self),
                         "生产链锁定后 reset() 不应清空注册表（问题 #8 回归）")
            XCTAssertTrue(container.isProductionChainLocked,
                         "生产链锁定状态不应被 reset() 破坏")
        }
    }

    /// 场景 2：resetForTesting 必须同时清空 isProductionChainPopulated 和 services
    ///
    /// 验证：mark 后 resetForTesting，isProductionChainLocked 应为 false，services 应为空。
    /// 修复前：resetForTesting 分两次 lock 清空，可能与 mark 竞态。
    /// 修复后：resetForTesting 在同一次 lock 内清空两者。
    func testResetForTestingClearsLockAndServices() {
        let container = ServiceContainer.shared

        for _ in 0..<100 {
            container.resetForTesting()
            container.register(RaceService() as RaceServiceProtocol, for: RaceServiceProtocol.self)
            container.markProductionChainComplete()
            XCTAssertTrue(container.isProductionChainLocked)

            container.resetForTesting()

            XCTAssertFalse(container.isProductionChainLocked,
                          "resetForTesting 必须清空 isProductionChainPopulated 标记")
            XCTAssertFalse(container.hasService(for: RaceServiceProtocol.self),
                          "resetForTesting 必须清空 services")
        }
    }

    /// 场景 3：高并发压力测试
    ///
    /// 并发执行 mark 和 reset，验证不会出现「isProductionChainLocked=true 但 services 为空」的不一致状态。
    /// 注意：reset 在 mark 之前执行（合法清空）后 mark 执行（设标记）是调用方使用错误，
    ///       不是 ServiceContainer 的 bug，本测试只检测 mark 先执行但 reset 仍清空的真正 bug。
    ///
    /// 检测方法：mark 完成后立即检查 services 是否存在，若存在但最终为空 → bug。
    func testConcurrentMarkAndResetNoInconsistency() {
        let container = ServiceContainer.shared

        var bugCount = 0
        let totalIterations = 500

        for _ in 0..<totalIterations {
            container.resetForTesting()
            container.register(RaceService() as RaceServiceProtocol, for: RaceServiceProtocol.self)

            let markFoundServiceLock = NSLock()
            var markFoundServiceValue = false

            let startSemaphore = DispatchSemaphore(value: 0)
            let markDone = DispatchGroup()
            let resetDone = DispatchGroup()

            markDone.enter()
            resetDone.enter()

            DispatchQueue.global().async {
                startSemaphore.wait()
                container.markProductionChainComplete()
                markFoundServiceLock.lock()
                markFoundServiceValue = container.hasService(for: RaceServiceProtocol.self)
                markFoundServiceLock.unlock()
                markDone.leave()
            }

            DispatchQueue.global().async {
                startSemaphore.wait()
                container.reset()
                resetDone.leave()
            }

            startSemaphore.signal()
            startSemaphore.signal()

            markDone.wait()
            resetDone.wait()

            markFoundServiceLock.lock()
            let markHadService = markFoundServiceValue
            markFoundServiceLock.unlock()

            // 真正的 bug：mark 完成时 services 存在，但最终 services 为空
            // 说明 reset 在 mark 之后执行了清空（竞态 bug）
            if markHadService && !container.hasService(for: RaceServiceProtocol.self) {
                bugCount += 1
            }
        }

        XCTAssertEqual(bugCount, 0,
                       "问题 #8 竞态：\(bugCount)/\(totalIterations) 次 mark 先完成但 reset 仍清空了 services")
    }
}
