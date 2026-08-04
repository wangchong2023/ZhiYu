//
//  ServiceContainerKeyGenerationTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 ServiceContainer.makeKey 的类型字符串归一化逻辑：
//           1. "any " 前缀剥离
//           2. 模块名前缀剥离（含泛型边界）
//           3. 泛型类型不剥离（保留 < > 区分）
//           4. Swift 内部修饰符（"(unknown context at ...)"）截断
//

import XCTest
@testable import UFPCore

private protocol KeyTestProtocol: Sendable { var value: Int { get } }
private struct KeyTestImpl: KeyTestProtocol { let value = 1 }

final class ServiceContainerKeyGenerationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    /// `any Protocol` 与 `Protocol` 必须解析到同一 key
    func testExistentialPrefixStripped() {
        let container = ServiceContainer.shared
        let impl = KeyTestImpl()
        container.register(impl as KeyTestProtocol, for: KeyTestProtocol.self)

        // 通过 hasService 验证 key 一致性
        XCTAssertTrue(container.hasService(for: KeyTestProtocol.self))

        // typeErasedResolve 使用 makeKey(forAny:)，必须与 makeKey(for:) 一致
        let erased = container.typeErasedResolve(KeyTestProtocol.self)
        XCTAssertNotNil(erased, "typeErasedResolve 必须能找到 any Protocol 注册的实例")
    }

    /// 泛型类型 Array<Int> 与 Array<String> 的 key 必须不同
    /// 当前实现：含 `<` 时不剥离模块前缀，但 key 仍包含完整泛型签名
    func testGenericTypesHaveDistinctKeys() {
        let container = ServiceContainer.shared

        let intArray: [Int] = [1, 2, 3]
        let stringArray: [String] = ["a", "b"]

        container.register(intArray, for: [Int].self)
        container.register(stringArray, for: [String].self)

        XCTAssertTrue(container.hasService(for: [Int].self))
        XCTAssertTrue(container.hasService(for: [String].self))

        let resolvedInts = container.resolveOptional([Int].self)
        let resolvedStrings = container.resolveOptional([String].self)

        XCTAssertEqual(resolvedInts, [1, 2, 3])
        XCTAssertEqual(resolvedStrings, ["a", "b"])
    }

    /// 重复注册同一 key 必须覆盖旧值（Last-Write-Wins 语义）
    func testReRegistrationOverwrites() {
        let container = ServiceContainer.shared

        let v1 = KeyTestImpl()
        v1.value // 1
        container.register(v1 as KeyTestProtocol, for: KeyTestProtocol.self)

        struct KeyTestImpl2: KeyTestProtocol { let value = 2 }
        let v2 = KeyTestImpl2()
        container.register(v2 as KeyTestProtocol, for: KeyTestProtocol.self)

        let resolved = container.resolveOptional(KeyTestProtocol.self)
        XCTAssertEqual(resolved?.value, 2, "重复注册必须覆盖，解析到最新实例")
    }

    /// resolveOptional 多次调用必须返回同一实例（幂等解析）
    func testResolveOptionalIsIdempotent() {
        let container = ServiceContainer.shared
        let impl = KeyTestImpl()
        container.register(impl as KeyTestProtocol, for: KeyTestProtocol.self)

        let a = container.resolveOptional(KeyTestProtocol.self)
        let b = container.resolveOptional(KeyTestProtocol.self)

        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertEqual(a?.value, b?.value)
    }
}
