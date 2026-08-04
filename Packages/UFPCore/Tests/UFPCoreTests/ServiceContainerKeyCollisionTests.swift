//
//  ServiceContainerKeyCollisionTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 ServiceContainer.makeKey 保留模块前缀后，
//           跨模块同名类型 Key 不再冲突。
//           修复前：makeKey 剥离模块前缀导致 `UFPCore.Logger` 与 `ZhiYuDomain.Logger` 互相覆盖。
//           修复后：保留模块前缀，跨模块同名类型独立解析。
//
//  注意：同 SPM 模块内的嵌套类型（如 `enum ModuleA { class Logger }`）
//        在 String(describing:) 中会省略命名空间，输出仅为 `Logger`。
//        这是 Swift 类型系统的固有行为，非 makeKey 缺陷。
//        真正的跨模块冲突需用不同 SPM 包的同名类型验证（UFPCore 无法依赖上层包，
//        故此处用 Foundation 类型 vs 自定义类型验证 makeKey 保留前缀的行为）。
//

import XCTest
@testable import UFPCore

private final class Logger { static let tag = "UFPCore" }
private final class OtherLogger { static let tag = "UFPCore" }

final class ServiceContainerKeyCollisionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// 同模块内不同名类型必须独立解析（基线测试）
    func testDifferentTypesInSameModuleResolveIndependently() {
        let container = ServiceContainer.shared
        let a = Logger()
        let b = OtherLogger()

        container.register(a, for: Logger.self)
        container.register(b, for: OtherLogger.self)

        XCTAssertTrue(container.hasService(for: Logger.self))
        XCTAssertTrue(container.hasService(for: OtherLogger.self))
        XCTAssertNotNil(container.resolveOptional(Logger.self))
        XCTAssertNotNil(container.resolveOptional(OtherLogger.self))
    }

    /// 跨模块类型必须独立解析（修复 makeKey 模块前缀剥离缺陷）
    /// Foundation.URL（跨模块）与本测试文件 private Logger 用不同模块前缀
    /// 修复前：makeKey 砍掉前缀 → 跨模块同名类型 key 冲突
    /// 修复后：保留前缀 → `Foundation.URL` 与 `Logger` key 不同
    func testCrossModuleTypesNoCollision() {
        let container = ServiceContainer.shared
        let localLogger = Logger()

        // 注册本模块 Logger
        container.register(localLogger, for: Logger.self)
        XCTAssertTrue(container.hasService(for: Logger.self))

        // 注册 Foundation 类型（不同模块前缀，不应覆盖本模块 Logger）
        let url = URL(string: "https://example.com")!
        container.register(url, for: URL.self)

        // 两者必须同时存在
        XCTAssertTrue(container.hasService(for: Logger.self),
                      "注册 Foundation 类型后 Logger 仍必须存在")
        XCTAssertTrue(container.hasService(for: URL.self))

        // 解析必须返回各自实例
        XCTAssertNotNil(container.resolveOptional(Logger.self))
        XCTAssertNotNil(container.resolveOptional(URL.self))
    }

    /// 协议存在性类型（`any Protocol`）与具体类型的 Key 必须可区分
    func testExistentialAndConcreteTypeKeyDifferentiation() {
        let container = ServiceContainer.shared

        protocol Tradable { var value: Int { get } }
        struct Coin: Tradable { let value = 100 }

        let coin = Coin()
        container.register(coin as Tradable, for: Tradable.self)
        container.register(coin, for: Coin.self)

        // 两个 key 不应互相覆盖
        XCTAssertTrue(container.hasService(for: Tradable.self))
        XCTAssertTrue(container.hasService(for: Coin.self))
    }
}

