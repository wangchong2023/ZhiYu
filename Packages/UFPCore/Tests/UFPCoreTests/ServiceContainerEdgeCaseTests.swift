//
//  ServiceContainerEdgeCaseTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 ServiceContainer 的边界场景：
//           1. 空容器解析行为
//           2. 重复 reset 幂等性
//           3. 注册 nil 实例的行为
//           4. 值类型 vs 引用类型注册差异
//

import XCTest
@testable import UFPCore

private struct ValueTypeService: Sendable { let id = UUID() }
private final class ReferenceTypeService: @unchecked Sendable { let id = UUID() }

final class ServiceContainerEdgeCaseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    /// 空容器 hasService 必须返回 false
    func testEmptyContainerHasServiceFalse() {
        let container = ServiceContainer.shared
        XCTAssertFalse(container.hasService(for: ValueTypeService.self))
        XCTAssertFalse(container.hasService(for: ReferenceTypeService.self))
    }

    /// 空容器 resolveOptional 必须返回 nil
    func testEmptyContainerOptionalResolveNil() {
        let container = ServiceContainer.shared
        XCTAssertNil(container.resolveOptional(ValueTypeService.self))
        XCTAssertNil(container.resolveOptional(ReferenceTypeService.self))
    }

    /// 重复 reset 必须幂等（不崩溃，状态一致）
    func testRepeatedResetIsIdempotent() {
        let container = ServiceContainer.shared
        container.register(ValueTypeService(), for: ValueTypeService.self)

        container.reset()
        container.reset()
        container.reset()

        XCTAssertFalse(container.hasService(for: ValueTypeService.self))
    }

    /// 值类型注册后解析必须返回等值（非同一引用，因值语义）
    func testValueTypeRegistrationEquality() {
        let container = ServiceContainer.shared
        let original = ValueTypeService()
        container.register(original, for: ValueTypeService.self)

        let resolved = container.resolveOptional(ValueTypeService.self)
        XCTAssertNotNil(resolved)
        // 值类型：id 相等（内容相同），但非同一引用
        XCTAssertEqual(resolved?.id, original.id)
    }

    /// 引用类型注册后解析必须返回同一引用
    func testReferenceTypeRegistrationIdentity() {
        let container = ServiceContainer.shared
        let original = ReferenceTypeService()
        container.register(original, for: ReferenceTypeService.self)

        let resolved = container.resolveOptional(ReferenceTypeService.self)
        XCTAssertTrue(resolved === original, "引用类型必须返回同一实例")
    }

    /// diagnosticSnapshot 在空容器时必须为空字典
    func testDiagnosticSnapshotEmptyWhenNoRegistrations() {
        let container = ServiceContainer.shared
        container.reset()
        let snapshot = container.diagnosticSnapshot
        XCTAssertTrue(snapshot.isEmpty)
    }
}
