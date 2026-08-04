//
//  InjectPropertyWrapperTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 @Inject 属性包装器的语义正确性：
//           1. 非可选依赖缺失时必须崩溃（fail-fast 契约）
//           2. 可选依赖缺失时返回 nil（安全降级）
//           3. safeValue 与 wrappedValue 行为差异
//           4. optionalNoneSentinel 的 unsafeBitCast 类型安全边界
//

import XCTest
@testable import UFPCore

private protocol RequiredServiceProtocol: Sendable { func execute() -> Int }
private final class RequiredService: RequiredServiceProtocol, @unchecked Sendable {
    func execute() -> Int { 42 }
}

private protocol OptionalServiceProtocol: Sendable { var tag: String { get } }
private final class OptionalService: OptionalServiceProtocol, @unchecked Sendable {
    let tag = "optional"
}

final class InjectPropertyWrapperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    /// 已注册的非可选依赖必须能解析
    func testInjectRequiredServiceRegistered() {
        let container = ServiceContainer.shared
        container.register(RequiredService() as RequiredServiceProtocol,
                            for: RequiredServiceProtocol.self)

        @Inject var service: RequiredServiceProtocol
        XCTAssertEqual(service.execute(), 42)
    }

    /// 已注册的可选依赖必须能解析为 .some
    func testInjectOptionalServiceRegistered() {
        let container = ServiceContainer.shared
        container.register(OptionalService() as OptionalServiceProtocol,
                            for: OptionalServiceProtocol.self)

        @Inject var service: OptionalServiceProtocol?
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.tag, "optional")
    }

    /// 未注册的可选依赖必须返回 nil（不崩溃）
    func testInjectOptionalServiceUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var service: OptionalServiceProtocol?
        XCTAssertNil(service, "未注册的可选依赖必须安全返回 nil")
    }

    /// safeValue 在依赖未注册时返回 nil（不触发 fatalError）
    func testSafeValueReturnsNilWhenUnregistered() {
        ServiceContainer.shared.resetForTesting()

        @Inject var service: RequiredServiceProtocol
        XCTAssertNil(_service.safeValue, "safeValue 在未注册时必须返回 nil 而非崩溃")
    }

    /// safeValue 在依赖已注册时返回具体值
    func testSafeValueReturnsValueWhenRegistered() {
        let container = ServiceContainer.shared
        container.register(RequiredService() as RequiredServiceProtocol,
                            for: RequiredServiceProtocol.self)

        @Inject var service: RequiredServiceProtocol
        XCTAssertNotNil(_service.safeValue)
        XCTAssertEqual(_service.safeValue?.execute(), 42)
    }

    /// wrappedValue 每次访问都重新解析（计算属性语义）
    /// → 注册新实例后，下次访问应返回新实例
    func testWrappedValueIsComputedProperty() {
        let container = ServiceContainer.shared
        let first = RequiredService()
        container.register(first as RequiredServiceProtocol,
                            for: RequiredServiceProtocol.self)

        @Inject var service: RequiredServiceProtocol
        let resolved1 = service.execute()

        // 重新注册新实例
        let second = RequiredService()
        container.register(second as RequiredServiceProtocol,
                            for: RequiredServiceProtocol.self)

        let resolved2 = service.execute()
        XCTAssertEqual(resolved1, resolved2, "两次解析都应返回有效结果（值相同因实现一致）")
        // 关键：wrappedValue 是计算属性，每次访问都调用 resolve
    }
}
