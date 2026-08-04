//
//  MockLoggerTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 MockLogger 存根的日志收集语义，确保测试隔离可靠。
//

import XCTest
@testable import UFPCore
import UFPCoreTestMocks

final class MockLoggerTests: XCTestCase {

    /// MockLogger.shared 必须是单例
    func testMockLoggerIsSingleton() {
        XCTAssertTrue(MockLogger.shared === MockLogger.shared)
    }

    /// clear() 后 logs 必须为空
    func testClearEmptiesLogs() {
        let logger = MockLogger.shared
        logger.info("a")
        logger.info("b")
        XCTAssertEqual(logger.logs.count, 2)

        logger.clear()
        XCTAssertTrue(logger.logs.isEmpty)
    }

    /// 各级别日志必须带正确前缀
    func testLogLevelPrefixes() {
        let logger = MockLogger.shared
        logger.clear()

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        XCTAssertEqual(logger.logs.count, 4)
        XCTAssertTrue(logger.logs[0].contains("[DEBUG]"))
        XCTAssertTrue(logger.logs[1].contains("[INFO]"))
        XCTAssertTrue(logger.logs[2].contains("[WARNING]"))
        XCTAssertTrue(logger.logs[3].contains("[ERROR]"))
    }

    /// MockLogger 可独立实例化（非仅 shared）
    /// → 测试用例可用独立实例避免 shared 状态污染
    func testMockLoggerIndependentInstance() {
        let independent = MockLogger()
        independent.info("isolated")
        XCTAssertEqual(independent.logs.count, 1)
        // shared 不受影响
        MockLogger.shared.clear()
        XCTAssertEqual(independent.logs.count, 1, "独立实例不受 shared.clear() 影响")
    }
}
