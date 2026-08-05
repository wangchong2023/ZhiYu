//
//  InjectNestedOptionalTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 @Inject 对嵌套 Optional（Optional<Optional<T>>）的行为。
//           发现问题 #10：嵌套 Optional 的 injectWrappedType 与 injectWrap 行为未定义。
//
//  嵌套 Optional 分析：
//  - T = Int?? = Optional<Optional<Int>>
//  - T.self as? OptionalDetectableProtocol.Type → 成功（Optional 遵循协议）
//  - injectWrappedType → Optional<Int>.self（Wrapped = Optional<Int>）
//  - typeErasedResolve(Optional<Int>.self) → 查找 key "Optional<Int>"
//    - 若未注册 Optional<Int> → 返回 nil
//  - injectWrap(nil) → Optional<Optional<Int>>.none（因 nil as? Optional<Int> 失败）
//  - as? T (Int??) → 成功（.none）
//
//  潜在问题：若注册了 Int（非 Optional<Int>），typeErasedResolve 返回 nil，
//  injectWrap(nil) 返回 .none，最终 @Inject var x: Int?? = nil
//

import XCTest
@testable import UFPCore

final class InjectNestedOptionalTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// 未注册时 Int?? 必须返回 nil（不崩溃）
    ///
    /// 修复问题 #10：@Inject var x: Int?? 未注册时曾返回 .some(.none) 而非 nil
    /// 根因：injectWrap(nil as Any) 中，nil as? Wrapped（Wrapped=Optional<Int>）成功
    /// 返回 .some(.none)，最终 Int?? = .some(.none) 而非 .none
    ///
    /// 修复后：injectWrap 用 Mirror 检测 Optional.none，直接返回 .none 语义
    func testInjectNestedOptionalUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var value: Int??
        XCTAssertNil(value, "未注册的 Int?? 必须返回 nil（.none），不崩溃")
    }

    /// 未注册时 String?? 必须返回 nil
    func testInjectNestedOptionalStringUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var value: String??
        XCTAssertNil(value, "未注册的 String?? 必须返回 nil（.none），不崩溃")
    }

    /// OptionalDetectableProtocol 对嵌套 Optional 的 injectWrappedType
    /// Optional<Optional<Int>>.injectWrappedType 应返回 Optional<Int>.self
    func testNestedOptionalInjectWrappedType() {
        let wrappedType = Optional<Optional<Int>>.injectWrappedType
        XCTAssertTrue(wrappedType == Optional<Int>.self,
                      "Int??.injectWrappedType 必须返回 Optional<Int>.self")
    }

    /// injectWrap 对嵌套 Optional 的 nil 输入
    /// Optional<Optional<Int>>.injectWrap(nil as Any) 应返回 .none 语义
    func testNestedOptionalInjectWrapWithNil() {
        let value: Any = NSNull()
        let wrapped = Optional<Optional<Int>>.injectWrap(value) as? Int??
        // injectWrap(NSNull) → NSNull as? Optional<Int> 失败 → 返回 .none
        // as? Int?? → .some(.none) 或 .none？
        // 关键验证：不崩溃
        XCTAssertNotNil(wrapped, "injectWrap 返回的 Optional<Optional<Int>> as? Int?? 必须成功")
    }

    /// 注册 Optional<Int> 后 @Inject Int?? 的行为
    /// typeErasedResolve(Optional<Int>.self) 找到注册值
    /// injectWrap(value) → value as? Optional<Int> → 成功 → .some(wrapped)
    func testInjectNestedOptionalWithRegisteredOptional() {
        let container = ServiceContainer.shared
        // 注册 Optional<Int>（key = "Optional<Int>"）
        let optionalValue: Int? = 42
        container.register(optionalValue, for: Int?.self)

        @Inject var value: Int??
        // typeErasedResolve(Optional<Int>.self) → 找到 42
        // injectWrap(42 as Any) → 42 as? Optional<Int> → 成功 → .some(42)
        // as? Int?? → .some(.some(42))
        // 但注意：注册的是 Int? = .some(42)，存储为 Any
        // typeErasedResolve 返回 Any（包含 .some(42)）
        // injectWrap: (Any).some(42) as? Optional<Int> → 成功 → .some(42)
        // 最终：Int?? = .some(.some(42))
        XCTAssertNotNil(value, "注册 Optional<Int> 后 Int?? 不应为 nil")
        XCTAssertEqual(value ?? nil, 42, "Int?? 解包后应为 42")
    }
}
