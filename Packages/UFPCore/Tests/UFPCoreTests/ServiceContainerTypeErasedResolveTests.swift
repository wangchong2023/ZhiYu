//
//  ServiceContainerTypeErasedResolveTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 typeErasedResolve 与泛型 resolve 的 key 一致性。
//           typeErasedResolve 使用 makeKey(forAny:)，必须与 makeKey(for:) 产生相同 key。
//

import XCTest
@testable import UFPCore

private protocol ErasedServiceProtocol: Sendable, AnyObject { var name: String { get } }
private final class ErasedService: ErasedServiceProtocol, @unchecked Sendable {
    let name = "erased"
}

final class ServiceContainerTypeErasedResolveTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    /// typeErasedResolve 必须能找到泛型 register 注册的服务
    func testTypeErasedResolveFindsGenericRegistered() {
        let container = ServiceContainer.shared
        let service = ErasedService()
        container.register(service as ErasedServiceProtocol, for: ErasedServiceProtocol.self)

        let erased = container.typeErasedResolve(ErasedServiceProtocol.self)
        XCTAssertNotNil(erased)

        let typed = erased as? ErasedServiceProtocol
        XCTAssertEqual(typed?.name, "erased")
    }

    /// typeErasedResolve 未注册时返回 nil（不崩溃）
    func testTypeErasedResolveReturnsNilWhenUnregistered() {
        let container = ServiceContainer.shared
        let erased = container.typeErasedResolve(ErasedServiceProtocol.self)
        XCTAssertNil(erased)
    }

    /// typeErasedResolve 与 resolveOptional 必须返回同一实例
    func testTypeErasedAndOptionalResolveReturnSameInstance() {
        let container = ServiceContainer.shared
        let service = ErasedService()
        container.register(service as ErasedServiceProtocol, for: ErasedServiceProtocol.self)

        let erased = container.typeErasedResolve(ErasedServiceProtocol.self) as? ErasedServiceProtocol
        let optional = container.resolveOptional(ErasedServiceProtocol.self)

        XCTAssertTrue(erased === optional, "两种解析方式必须返回同一实例")
    }
}
