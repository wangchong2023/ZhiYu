//
//  LoggerBoundaryTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 MinimalLogger 的边界值行为。
//           发现问题 #12：Logger 的 file/function/line 参数边界值未测试。
//

import XCTest
@testable import UFPCore

final class LoggerBoundaryTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    /// info/warning/error/debug 调用不崩溃（基线）
    func testAllLevelsDoNotCrash() {
        MinimalLogger.shared.debug("debug message")
        MinimalLogger.shared.info("info message")
        MinimalLogger.shared.warning("warning message")
        MinimalLogger.shared.error("error message")
    }

    /// 空消息不崩溃
    func testEmptyMessageDoesNotCrash() {
        MinimalLogger.shared.debug("")
        MinimalLogger.shared.info("")
        MinimalLogger.shared.warning("")
        MinimalLogger.shared.error("")
    }

    /// 显式传入空 file 参数 — 边界值
    /// (file as NSString).lastPathComponent 对空字符串返回空字符串
    func testEmptyFileParameterDoesNotCrash() {
        MinimalLogger.shared.info("test", file: "", function: "", line: 0)
        MinimalLogger.shared.warning("test", file: "", function: "", line: 0)
        MinimalLogger.shared.error("test", file: "", function: "", line: 0)
        MinimalLogger.shared.debug("test", file: "", function: "", line: 0)
    }

    /// 显式传入无路径分隔符的 file — 边界值
    /// (file as NSString).lastPathComponent 对无分隔符字符串返回整个字符串
    func testFileParameterWithoutPathSeparator() {
        MinimalLogger.shared.info("test", file: "nofile", function: "testFunc", line: 42)
        // 不崩溃即通过
    }

    /// 显式传入完整路径 file — 正常场景
    func testFileParameterWithFullPath() {
        MinimalLogger.shared.info("test", file: "/path/to/SomeFile.swift", function: "testFunc", line: 100)
        // 不崩溃即通过
    }

    /// 多行消息不崩溃
    func testMultilineMessageDoesNotCrash() {
        MinimalLogger.shared.info("line1\nline2\nline3")
        MinimalLogger.shared.error("error\nwith\nnewlines")
    }

    /// 特殊字符消息不崩溃
    func testSpecialCharactersMessageDoesNotCrash() {
        MinimalLogger.shared.info("特殊字符: \t\\\"' emoji: 🎉")
        MinimalLogger.shared.error("path: /usr/local/bin")
    }

    /// 超长消息不崩溃
    func testVeryLongMessageDoesNotCrash() {
        let longMessage = String(repeating: "a", count: 10000)
        MinimalLogger.shared.info(longMessage)
        MinimalLogger.shared.error(longMessage)
    }
}
