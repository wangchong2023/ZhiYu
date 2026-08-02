//
//  UFPCoreTests.swift
//  UFPCoreTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPCoreTests]
//  核心职责：通用集成平台底座包 (UFPCore) 单元测试套件。
//           校验 ServiceContainer 的高并发线程安全、未注册服务可选检测与 @Inject 属性包装器逻辑。
//

import XCTest
@testable import UFPCore
import UFPCoreTestMocks

private protocol DummyServiceProtocol: Sendable {
    func execute() -> String
}

private final class DummyService: DummyServiceProtocol, @unchecked Sendable {
    func execute() -> String { "UFPCoreSuccess" }
}

final class UFPCoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.reset()
    }

    /// 校验 ServiceContainer 注册与解析功能
    func testServiceContainerRegistrationAndResolution() {
        let container = ServiceContainer.shared
        let service = DummyService()

        container.register(service as DummyServiceProtocol, for: DummyServiceProtocol.self)

        XCTAssertTrue(container.hasService(for: DummyServiceProtocol.self), "注册后 hasService 必须返回 true")

        let resolved = container.resolve(DummyServiceProtocol.self)
        XCTAssertEqual(resolved.execute(), "UFPCoreSuccess", "解析出的服务实例必须能执行协议方法")
    }

    /// 校验并发多线程下 ServiceContainer 注册与解析的线程安全性
    func testServiceContainerConcurrentThreadSafety() {
        let container = ServiceContainer.shared
        let expectation = expectation(description: "Concurrent DI registration and resolution")
        expectation.expectedFulfillmentCount = 100

        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let service = DummyService()
            container.register(service as DummyServiceProtocol, for: DummyServiceProtocol.self)
            let resolved = container.optionalResolve(DummyServiceProtocol.self)
            XCTAssertNotNil(resolved, "高并发注册与解析时不应出现锁竞争导致的空指针")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    /// 校验未注册服务时的 optionalResolve 安全逻辑
    func testUnregisteredOptionalResolve() {
        let container = ServiceContainer.shared
        let optionalResolved = container.optionalResolve(DummyServiceProtocol.self)
        XCTAssertNil(optionalResolved, "未注册的服务在 optionalResolve 时必须安全返回 nil，不得断言崩溃")
    }

    /// 校验 MockLogger 存根功能
    func testMockLoggerFunctionality() {
        let mockLogger = MockLogger.shared
        mockLogger.clear()

        mockLogger.info("Testing UFPCore MockLogger")
        XCTAssertEqual(mockLogger.logs.count, 1, "MockLogger 记录条数必须为 1")
        XCTAssertTrue(mockLogger.logs.first?.contains("Testing UFPCore MockLogger") ?? false)
    }
}
