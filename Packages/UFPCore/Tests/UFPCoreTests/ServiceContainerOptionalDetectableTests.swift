//
//  ServiceContainerOptionalDetectableTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 OptionalDetectableProtocol 的 injectWrap 类型安全边界。
//           injectWrap 使用 as? 转型，类型不匹配时返回 nil 包装，不崩溃。
//

import XCTest
@testable import UFPCore

final class ServiceContainerOptionalDetectableTests: XCTestCase {

    /// Optional<Int>.injectWrappedType 必须返回 Int.self
    func testInjectWrappedTypeReturnsInnerType() {
        let wrappedType = Optional<Int>.injectWrappedType
        XCTAssertTrue(wrappedType == Int.self)
    }

    /// Optional<String>.injectWrappedType 必须返回 String.self
    func testInjectWrappedTypeForString() {
        let wrappedType = Optional<String>.injectWrappedType
        XCTAssertTrue(wrappedType == String.self)
    }

    /// injectWrap 成功转型时返回 .some 包装
    func testInjectWrapSucceedsWithMatchingType() {
        let value: Any = 42
        let wrapped = Optional<Int>.injectWrap(value) as? Int?
        XCTAssertEqual(wrapped, 42)
    }

    /// injectWrap 类型不匹配时返回 nil 包装（不崩溃）
    func testInjectWrapReturnsNilWithMismatchedType() {
        let value: Any = "not an int"
        let wrapped = Optional<Int>.injectWrap(value) as? Int?
        // injectWrap 返回 Optional<Int>.none，as? Int? 后是 .some(.none)
        // 此处验证不崩溃且值为 nil 语义
        XCTAssertEqual(wrapped ?? nil, nil, "类型不匹配时 injectWrap 必须返回 nil 语义而非崩溃")
    }

    /// injectWrap 接收不相关类型时返回 nil 语义
    func testInjectWrapWithNilInput() {
        let value: Any = NSNull()
        let wrapped = Optional<Int>.injectWrap(value) as? Int?
        XCTAssertEqual(wrapped ?? nil, nil)
    }
}
