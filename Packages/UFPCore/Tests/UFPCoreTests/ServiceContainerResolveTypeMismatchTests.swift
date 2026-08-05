//
//  ServiceContainerResolveTypeMismatchTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 resolve<T> 在类型不匹配时的行为语义。
//           发现问题 #9：注册协议后用具体类型 resolve，或注册具体类型后用协议 resolve，
//           instance as? T 失败 → 触发 fatalError（fail-fast 契约）。
//           需验证这是预期行为还是应返回 nil。
//

import XCTest
@testable import UFPCore

private protocol MismatchServiceProtocol: Sendable { var tag: String { get } }
private final class MismatchServiceImpl: MismatchServiceProtocol, @unchecked Sendable {
    let tag = "mismatch"
}

final class ServiceContainerResolveTypeMismatchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// 注册协议后用具体类型 resolveOptional — 应返回 nil（不崩溃）
    ///
    /// instance 是 existential 容器（MismatchServiceProtocol），
    /// as? MismatchServiceImpl 转型失败 → 返回 nil
    func testRegisterProtocolResolveConcreteOptionalReturnsNil() {
        let container = ServiceContainer.shared
        container.register(MismatchServiceImpl() as MismatchServiceProtocol,
                           for: MismatchServiceProtocol.self)

        let result = container.resolveOptional(MismatchServiceImpl.self)
        XCTAssertNil(result,
                     "注册协议后用具体类型 resolveOptional 应返回 nil（existential 容器无法 as? 具体类型）")
    }

    /// 注册具体类型后用协议 resolveOptional — 应返回 nil（不崩溃）
    ///
    /// instance 是 MismatchServiceImpl，as? MismatchServiceProtocol
    /// 注意：Swift 中 as? 协议转型可能成功（若实例遵循协议）
    /// 此测试验证实际行为
    func testRegisterConcreteResolveProtocolOptional() {
        let container = ServiceContainer.shared
        let impl = MismatchServiceImpl()
        container.register(impl, for: MismatchServiceImpl.self)

        let result = container.resolveOptional(MismatchServiceProtocol.self)
        // 关键验证：注册具体类型，用协议 resolveOptional
        // Swift 的 as? 协议转型行为：若实例遵循协议则成功
        // 但 ServiceContainer 的 key 不同（MismatchServiceImpl vs MismatchServiceProtocol）
        // → services[key] 为 nil → as? T 返回 nil
        XCTAssertNil(result,
                     "注册具体类型后用协议 resolveOptional 应返回 nil（key 不同，未找到服务）")
    }

    /// 注册 Int 后用 String resolveOptional — 类型不匹配返回 nil
    func testRegisterIntResolveStringOptionalReturnsNil() {
        let container = ServiceContainer.shared
        container.register(42, for: Int.self)

        let result = container.resolveOptional(String.self)
        XCTAssertNil(result, "注册 Int 后用 String resolveOptional 应返回 nil（key 不同）")
    }

    /// 注册 Int 后用 Int? resolveOptional — Optional 包装类型
    /// 验证 key 是否匹配（Int vs Optional<Int>）
    ///
    /// 修复问题 #13：resolveOptional<Int?> 未注册时曾返回 .some(.none) 而非 nil
    /// 根因：instance 为 nil 时，nil as? Int? 返回 .some(.none)（Swift 语言陷阱）
    /// 修复后：resolveOptional 先 guard let nonNilInstance，避免 nil as? T 陷阱
    func testRegisterIntResolveIntOptional() {
        let container = ServiceContainer.shared
        container.register(42, for: Int.self)

        let result = container.resolveOptional(Int?.self)
        // Int? 的 key 是 "Optional<Int>"，Int 的 key 是 "Int" → 不匹配
        // 修复后：instance 为 nil 时直接返回 nil，不执行 nil as? Int?
        XCTAssertNil(result, "注册 Int 后用 Int? resolveOptional 应返回 nil（key 不同）")
    }

    /// typeErasedResolve 注册协议后用具体类型 — 应返回 nil
    func testTypeErasedResolveRegisterProtocolResolveConcrete() {
        let container = ServiceContainer.shared
        container.register(MismatchServiceImpl() as MismatchServiceProtocol,
                           for: MismatchServiceProtocol.self)

        let result = container.typeErasedResolve(MismatchServiceImpl.self)
        XCTAssertNil(result, "注册协议后用具体类型 typeErasedResolve 应返回 nil（key 不同）")
    }

    /// hasService 注册协议后查询具体类型 — 应返回 false
    func testHasServiceRegisterProtocolQueryConcrete() {
        let container = ServiceContainer.shared
        container.register(MismatchServiceImpl() as MismatchServiceProtocol,
                           for: MismatchServiceProtocol.self)

        XCTAssertFalse(container.hasService(for: MismatchServiceImpl.self),
                       "注册协议后 hasService 查具体类型应返回 false（key 不同）")
        XCTAssertTrue(container.hasService(for: MismatchServiceProtocol.self),
                      "注册协议后 hasService 查协议应返回 true")
    }
}
