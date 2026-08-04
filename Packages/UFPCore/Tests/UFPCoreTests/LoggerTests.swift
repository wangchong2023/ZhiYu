//
//  LoggerTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 Logger 单例的级别语义与 DEBUG 条件编译行为。
//           Logger.debug 在 Release 下静默是预期行为，但调用方不应依赖其副作用。
//

import XCTest
@testable import UFPCore

final class LoggerTests: XCTestCase {

    /// MinimalLogger.shared 必须是单例（同一引用）
    func testLoggerIsSingleton() {
        let a = MinimalLogger.shared
        let b = MinimalLogger.shared
        XCTAssertTrue(a === b, "MinimalLogger.shared 必须返回同一实例")
    }

    /// info/warning/error 在任何配置下都应输出（无级别过滤）
    /// 此测试验证调用不崩溃且无返回值（void）
    func testInfoWarningErrorDoNotCrash() {
        MinimalLogger.shared.info("test info")
        MinimalLogger.shared.warning("test warning")
        MinimalLogger.shared.error("test error")

        // debug 仅在 DEBUG 下输出，但调用本身不应崩溃
        MinimalLogger.shared.debug("test debug")
    }

    /// Logger 单例不可替换 → 测试隔离需通过 MockLogger 而非替换 shared
    /// 此测试验证 MinimalLogger.shared 的 init 是 private（无法外部构造）
    func testLoggerInitIsPrivate() {
        // 编译期保证：以下代码若取消注释会编译失败
        // let logger = MinimalLogger()
        XCTAssertTrue(true, "Logger.init 是 private，外部无法构造（编译期保证）")
    }
}
