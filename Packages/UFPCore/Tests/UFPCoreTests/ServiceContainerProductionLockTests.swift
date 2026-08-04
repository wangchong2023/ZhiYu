//
//  ServiceContainerProductionLockTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 markProductionChainComplete 后 reset() 被禁用的语义，
//           以及 resetForTesting() 可逆重置生产链标记的修复行为。
//

import XCTest
@testable import UFPCore

private protocol LockedServiceProtocol: Sendable { func ping() -> String }
private final class LockedService: LockedServiceProtocol, @unchecked Sendable {
    func ping() -> String { "locked" }
}

final class ServiceContainerProductionLockTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 每个测试前确保 shared 处于干净状态
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// isReady 在 markProductionChainComplete 前必须为 false
    func testIsReadyFalseBeforeMarkComplete() {
        let container = ServiceContainer.shared
        XCTAssertFalse(container.isReady)
        XCTAssertFalse(container.isProductionChainLocked)
    }

    /// markProductionChainComplete 后 isReady 必须为 true
    func testIsReadyTrueAfterMarkComplete() {
        let container = ServiceContainer.shared
        container.markProductionChainComplete()
        XCTAssertTrue(container.isReady)
        XCTAssertTrue(container.isProductionChainLocked)
    }

    /// diagnosticSnapshot 必须反映真实注册表
    func testDiagnosticSnapshotReflectsRegistrations() {
        let container = ServiceContainer.shared
        container.register(LockedService() as LockedServiceProtocol, for: LockedServiceProtocol.self)

        let snapshot = container.diagnosticSnapshot
        let keyExists = snapshot.values.contains(true)
        XCTAssertTrue(keyExists, "diagnosticSnapshot 必须包含已注册的服务 key")
    }

    /// 生产链锁定后 reset() 必须被禁用（静默无效）
    func testResetBlockedWhenProductionLocked() {
        let container = ServiceContainer.shared
        container.register(LockedService() as LockedServiceProtocol, for: LockedServiceProtocol.self)
        container.markProductionChainComplete()

        container.reset() // 应被禁用
        XCTAssertTrue(container.hasService(for: LockedServiceProtocol.self),
                      "生产链锁定后 reset() 必须无效，服务仍存在")
    }

    /// resetForTesting() 必须可逆重置生产链标记并清空服务
    /// （修复 markProductionChainComplete 不可逆导致的测试隔离破坏）
    func testResetForTestingClearsProductionLock() {
        let container = ServiceContainer.shared
        container.register(LockedService() as LockedServiceProtocol, for: LockedServiceProtocol.self)
        container.markProductionChainComplete()
        XCTAssertTrue(container.isProductionChainLocked)

        container.resetForTesting()
        XCTAssertFalse(container.isProductionChainLocked, "resetForTesting 必须清除生产链标记")
        XCTAssertFalse(container.hasService(for: LockedServiceProtocol.self),
                       "resetForTesting 必须清空服务注册表")
    }

    /// resetForTesting 后可重新注册并 resolve（验证 shared 单例可复用）
    func testSharedReusableAfterResetForTesting() {
        let container = ServiceContainer.shared
        container.markProductionChainComplete()
        container.resetForTesting()

        // 重新注册并解析
        container.register(LockedService() as LockedServiceProtocol, for: LockedServiceProtocol.self)
        let resolved = container.resolveOptional(LockedServiceProtocol.self)
        XCTAssertNotNil(resolved, "resetForTesting 后必须可重新注册并解析")
    }
}
