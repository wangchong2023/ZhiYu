//
//  InjectValueOptionalTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 @Inject 对值类型 Optional 的安全降级：
//           1. String?（24 字节）未注册时返回 nil 不崩溃
//           2. Int?（9 字节）未注册时返回 nil 不崩溃
//           3. Double?（9 字节）未注册时返回 nil 不崩溃
//           4. Bool?（2 字节）未注册时返回 nil 不崩溃
//           5. 已注册的值类型 Optional 返回正确值
//
//  回归测试：覆盖问题 1（optionalNoneSentinel unsafeBitCast 必崩 bug）
//           原缺陷：unsafeBitCast(Bool?.none, to: T.self) 在 T 大小不同于 Bool? 时必崩
//           修复后：injectWrap 安全构造 Optional<Wrapped>.none，as? T 成功返回 nil
//

import XCTest
@testable import UFPCore

final class InjectValueOptionalTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    // MARK: - 未注册的值类型 Optional 必须返回 nil（不崩溃）

    /// String?（24 字节，大小不同于 Bool? 的 2 字节）未注册时返回 nil
    /// 回归测试：原 unsafeBitCast(Bool?.none, to: String?.self) 必崩
    func testInjectStringOptionalUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var value: String?
        XCTAssertNil(value, "未注册的 String? 必须安全返回 nil，不崩溃")
    }

    /// Int?（9 字节，大小不同于 Bool? 的 2 字节）未注册时返回 nil
    /// 回归测试：原 unsafeBitCast(Bool?.none, to: Int?.self) 必崩
    func testInjectIntOptionalUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var value: Int?
        XCTAssertNil(value, "未注册的 Int? 必须安全返回 nil，不崩溃")
    }

    /// Double?（9 字节，大小不同于 Bool? 的 2 字节）未注册时返回 nil
    /// 回归测试：原 unsafeBitCast(Bool?.none, to: Double?.self) 必崩
    func testInjectDoubleOptionalUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var value: Double?
        XCTAssertNil(value, "未注册的 Double? 必须安全返回 nil，不崩溃")
    }

    /// Bool?（2 字节，与 sentinel 大小相同）未注册时返回 nil
    /// 覆盖与 sentinel 大小相同的边界值
    func testInjectBoolOptionalUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var value: Bool?
        XCTAssertNil(value, "未注册的 Bool? 必须安全返回 nil，不崩溃")
    }

    /// Data?（16 字节，大小不同于 Bool? 的 2 字节）未注册时返回 nil
    /// 回归测试：原 unsafeBitCast(Bool?.none, to: Data?.self) 必崩
    func testInjectDataOptionalUnregisteredReturnsNil() {
        ServiceContainer.shared.resetForTesting()

        @Inject var value: Data?
        XCTAssertNil(value, "未注册的 Data? 必须安全返回 nil，不崩溃")
    }

    // MARK: - 已注册的值类型 Optional 必须返回正确值

    /// 已注册的 String? 必须返回具体值
    func testInjectStringOptionalRegisteredReturnsValue() {
        let container = ServiceContainer.shared
        container.register("hello", for: String.self)

        @Inject var value: String?
        XCTAssertEqual(value, "hello", "已注册的 String? 必须返回具体值")
    }

    /// 已注册的 Int? 必须返回具体值
    func testInjectIntOptionalRegisteredReturnsValue() {
        let container = ServiceContainer.shared
        container.register(42, for: Int.self)

        @Inject var value: Int?
        XCTAssertEqual(value, 42, "已注册的 Int? 必须返回具体值")
    }

    /// 已注册的 Double? 必须返回具体值
    func testInjectDoubleOptionalRegisteredReturnsValue() {
        let container = ServiceContainer.shared
        container.register(3.14, for: Double.self)

        @Inject var value: Double?
        XCTAssertEqual(value, 3.14, "已注册的 Double? 必须返回具体值")
    }

    /// 已注册的 Bool? 必须返回具体值
    func testInjectBoolOptionalRegisteredReturnsValue() {
        let container = ServiceContainer.shared
        container.register(true, for: Bool.self)

        @Inject var value: Bool?
        XCTAssertEqual(value, true, "已注册的 Bool? 必须返回具体值")
    }

    // MARK: - 类型不匹配时安全降级为 nil

    /// 注册了 Int 但 @Inject 期望 String? 时，安全返回 nil（不崩溃）
    /// 覆盖 injectWrap 的类型不匹配分支：42 as? String 失败 → 返回 Optional<String>.none
    func testInjectTypeMismatchReturnsNil() {
        let container = ServiceContainer.shared
        container.register(42, for: Int.self)

        @Inject var value: String?
        XCTAssertNil(value, "注册 Int 但期望 String? 时必须安全返回 nil，不崩溃")
    }
}
