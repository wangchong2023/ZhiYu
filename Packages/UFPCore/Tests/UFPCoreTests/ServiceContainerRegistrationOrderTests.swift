//
//  ServiceContainerRegistrationOrderTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 ServiceContainer 注册顺序无关性与覆盖语义。
//           Service Locator 模式要求 Last-Write-Wins，且注册后立即可解析。
//

import XCTest
@testable import UFPCore

private protocol OrderServiceProtocol: Sendable { var version: Int { get } }
private struct OrderServiceV1: OrderServiceProtocol, @unchecked Sendable { let version = 1 }
private struct OrderServiceV2: OrderServiceProtocol, @unchecked Sendable { let version = 2 }

final class ServiceContainerRegistrationOrderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    /// 后注册的实例必须覆盖先注册的
    func testLastRegistrationWins() {
        let container = ServiceContainer.shared

        container.register(OrderServiceV1() as OrderServiceProtocol, for: OrderServiceProtocol.self)
        XCTAssertEqual(container.resolveOptional(OrderServiceProtocol.self)?.version, 1)

        container.register(OrderServiceV2() as OrderServiceProtocol, for: OrderServiceProtocol.self)
        XCTAssertEqual(container.resolveOptional(OrderServiceProtocol.self)?.version, 2)
    }

    /// 注册后立即解析必须成功（无延迟生效）
    func testImmediateResolutionAfterRegister() {
        let container = ServiceContainer.shared
        container.register(OrderServiceV1() as OrderServiceProtocol, for: OrderServiceProtocol.self)

        // 不等待，立即解析
        let resolved = container.resolveOptional(OrderServiceProtocol.self)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.version, 1)
    }

    /// 注册同一协议的不同实例类型必须可切换
    func testSwitchImplementationType() {
        let container = ServiceContainer.shared

        container.register(OrderServiceV1() as OrderServiceProtocol, for: OrderServiceProtocol.self)
        let v1 = container.resolveOptional(OrderServiceProtocol.self)
        XCTAssertTrue(v1 is OrderServiceV1)

        container.register(OrderServiceV2() as OrderServiceProtocol, for: OrderServiceProtocol.self)
        let v2 = container.resolveOptional(OrderServiceProtocol.self)
        XCTAssertTrue(v2 is OrderServiceV2)
    }

    /// reset 后所有服务必须清空（在未锁定生产链时）
    func testResetClearsAllServices() {
        let container = ServiceContainer.shared
        container.register(OrderServiceV1() as OrderServiceProtocol, for: OrderServiceProtocol.self)
        XCTAssertTrue(container.hasService(for: OrderServiceProtocol.self))

        container.reset()
        XCTAssertFalse(container.hasService(for: OrderServiceProtocol.self))
        XCTAssertNil(container.resolveOptional(OrderServiceProtocol.self))
    }
}
