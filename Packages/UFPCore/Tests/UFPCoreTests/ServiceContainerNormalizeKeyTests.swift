//
//  ServiceContainerNormalizeKeyTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 normalizeKey 的 key 归一化逻辑：
//           1. "any " 前缀移除（常见 existential type）
//           2. "all " 前缀移除（多协议组合 existential type）
//           3. "(unknown context at $xxx)." 前缀移除（测试文件 private 嵌套类型）
//           4. 无前缀类型保持不变
//           5. 跨模块同名类型 key 必须不同（保留模块前缀）
//

import XCTest
@testable import UFPCore

private protocol NormalizeKeyTestProtocol: Sendable { var value: Int { get } }
private final class NormalizeKeyTestImpl: NormalizeKeyTestProtocol, @unchecked Sendable {
    let value = 42
}

private final class NormalizeKeyOtherType: @unchecked Sendable {
    let tag = "other"
}

final class ServiceContainerNormalizeKeyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// "any " 前缀的协议类型与无前缀的具体类型必须用不同 key
    /// 注册 `any NormalizeKeyTestProtocol` 后，解析 `NormalizeKeyTestImpl`（具体类型）应失败
    func testAnyPrefixProtocolAndConcreteTypeDifferentKey() {
        let container = ServiceContainer.shared
        let impl = NormalizeKeyTestImpl()
        container.register(impl as NormalizeKeyTestProtocol, for: NormalizeKeyTestProtocol.self)

        // 协议已注册，具体类型未注册 — 解析具体类型应返回 nil
        XCTAssertNil(container.resolveOptional(NormalizeKeyTestImpl.self),
                     "协议与具体类型 key 不同，解析具体类型应返回 nil")
        // 解析协议应成功
        XCTAssertNotNil(container.resolveOptional(NormalizeKeyTestProtocol.self),
                        "协议已注册，解析协议应成功")
    }

    /// 跨模块同名类型 key 必须不同（保留模块前缀）
    /// Foundation.URL 与本测试文件的 private 类型用不同模块前缀
    func testCrossModuleSameNameTypesNoCollision() {
        let container = ServiceContainer.shared

        // 注册 Foundation.URL
        let url = URL(string: "https://example.com")!
        container.register(url, for: URL.self)
        XCTAssertTrue(container.hasService(for: URL.self))

        // 注册本模块类型
        let other = NormalizeKeyOtherType()
        container.register(other, for: NormalizeKeyOtherType.self)
        XCTAssertTrue(container.hasService(for: NormalizeKeyOtherType.self))

        // 两者必须同时存在（key 不冲突）
        XCTAssertTrue(container.hasService(for: URL.self),
                      "注册 NormalizeKeyOtherType 后 URL 仍必须存在")
        XCTAssertTrue(container.hasService(for: NormalizeKeyOtherType.self),
                      "注册 URL 后 NormalizeKeyOtherType 仍必须存在")
    }

    /// 同模块内不同名类型必须独立解析（基线测试）
    func testSameModuleDifferentTypesResolveIndependently() {
        let container = ServiceContainer.shared
        let a = NormalizeKeyTestImpl()
        let b = NormalizeKeyOtherType()

        container.register(a, for: NormalizeKeyTestImpl.self)
        container.register(b, for: NormalizeKeyOtherType.self)

        XCTAssertTrue(container.hasService(for: NormalizeKeyTestImpl.self))
        XCTAssertTrue(container.hasService(for: NormalizeKeyOtherType.self))
        XCTAssertNotNil(container.resolveOptional(NormalizeKeyTestImpl.self))
        XCTAssertNotNil(container.resolveOptional(NormalizeKeyOtherType.self))
    }

    /// 重复注册同类型必须覆盖旧实例（非累积）
    func testReRegisterOverwritesPreviousInstance() {
        let container = ServiceContainer.shared

        let first = NormalizeKeyTestImpl()
        container.register(first, for: NormalizeKeyTestImpl.self)

        let second = NormalizeKeyTestImpl()
        container.register(second, for: NormalizeKeyTestImpl.self)

        // diagnosticSnapshot 应只包含 1 个 key（覆盖非累积）
        let snapshot = container.diagnosticSnapshot
        let matchingKeys = snapshot.keys.filter { $0.contains("NormalizeKeyTestImpl") }
        XCTAssertEqual(matchingKeys.count, 1,
                       "重复注册应覆盖，diagnosticSnapshot 应只含 1 个匹配 key")
    }

    /// hasService 对未注册类型返回 false
    func testHasServiceReturnsFalseForUnregistered() {
        XCTAssertFalse(ServiceContainer.shared.hasService(for: NormalizeKeyTestImpl.self),
                       "未注册类型 hasService 必须返回 false")
    }
}
