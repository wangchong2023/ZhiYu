//
//  ServiceContainerConcurrencyTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 ServiceContainer 在高并发注册/解析下的线程安全性与数据一致性。
//           OSAllocatedUnfairLock 必须保证注册表操作的原子性，避免丢失更新。
//

import XCTest
@testable import UFPCore

private protocol ConcurrentServiceProtocol: Sendable { var id: Int { get } }
private final class ConcurrentService: ConcurrentServiceProtocol, @unchecked Sendable {
    let id: Int
    init(id: Int) { self.id = id }
}

final class ServiceContainerConcurrencyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    /// 高并发交替注册同一 key 的不同实例 → 最终状态必须一致（无半写入状态）
    func testConcurrentRegisterSameKeyConsistency() {
        let container = ServiceContainer.shared
        let iterations = 200

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            let service = ConcurrentService(id: i)
            container.register(service as ConcurrentServiceProtocol, for: ConcurrentServiceProtocol.self)
        }

        // 最终解析必须成功且无崩溃
        let resolved = container.resolveOptional(ConcurrentServiceProtocol.self)
        XCTAssertNotNil(resolved, "并发注册后必须能解析到某个实例")
        XCTAssertTrue((0..<iterations).contains(resolved!.id),
                      "解析出的 id 必须是某次注册的有效值，不能是内存损坏")
    }

    /// 高并发 resolve 与 register 交替 → resolve 不应读到半写入状态
    func testConcurrentResolveWhileRegistering() {
        let container = ServiceContainer.shared
        container.register(ConcurrentService(id: -1) as ConcurrentServiceProtocol,
                            for: ConcurrentServiceProtocol.self)

        let expectation = expectation(description: "Concurrent resolve/register")
        expectation.expectedFulfillmentCount = 100

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            if i % 2 == 0 {
                container.register(ConcurrentService(id: i) as ConcurrentServiceProtocol,
                                    for: ConcurrentServiceProtocol.self)
            } else {
                let resolved = container.resolveOptional(ConcurrentServiceProtocol.self)
                XCTAssertNotNil(resolved, "resolve 不应返回 nil（已有初始注册）")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    /// hasService 与 resolveOptional 之间存在 TOCTOU 窗口
    /// 此测试验证：即使 hasService 返回 true，resolveOptional 仍可能因并发 reset 返回 nil
    /// → 调用方不应依赖 hasService，应直接用 resolveOptional
    func testHasServiceTOCTOUWithReset() {
        let container = ServiceContainer.shared
        container.register(ConcurrentService(id: 0) as ConcurrentServiceProtocol,
                            for: ConcurrentServiceProtocol.self)

        XCTAssertTrue(container.hasService(for: ConcurrentServiceProtocol.self))

        // 模拟并发 reset（在锁外）
        DispatchQueue.global().sync {
            container.reset()
        }

        // hasService 现在应返回 false
        XCTAssertFalse(container.hasService(for: ConcurrentServiceProtocol.self))
        XCTAssertNil(container.resolveOptional(ConcurrentServiceProtocol.self))
    }
}
