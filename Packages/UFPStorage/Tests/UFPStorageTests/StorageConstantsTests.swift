//
//  StorageConstantsTests.swift
//  UFPStorageTests
//
//  系统层级：[UFPStorageTests]
//  核心职责：验证 StorageConstants 常量的语义正确性与不变量约束。
//           这些常量是 SQLite 引擎调优的基础，错误值会导致性能退化或数据损坏。
//

import XCTest
@testable import UFPStorage

final class StorageConstantsTests: XCTestCase {

    /// WAL 检查点阈值必须为正数（0 或负数会导致 SQLite 立即 checkpoint，性能崩溃）
    func testWalCheckpointThresholdPositive() {
        XCTAssertGreaterThan(StorageConstants.walCheckpointThreshold, 0,
                             "WAL checkpoint 阈值必须为正数，否则每次写入都触发 checkpoint")
    }

    /// 连接超时必须合理（过短导致误超时，过长导致死锁无法恢复）
    func testConnectionTimeoutReasonable() {
        XCTAssertGreaterThanOrEqual(StorageConstants.connectionTimeout, 5,
                                    "连接超时不应短于 5 秒")
        XCTAssertLessThanOrEqual(StorageConstants.connectionTimeout, 120,
                                 "连接超时不应超过 120 秒（避免死锁过长）")
    }

    /// 默认页大小必须是 2 的幂（SQLite 要求）
    func testDefaultPageSizeIsPowerOfTwo() {
        let page = StorageConstants.defaultPageSize
        XCTAssertGreaterThan(page, 0)
        XCTAssertEqual(page & (page - 1), 0, "SQLite 页大小必须是 2 的幂")
    }

    /// 默认页大小应在合理范围（512 ~ 65536）
    func testDefaultPageSizeInRange() {
        let page = StorageConstants.defaultPageSize
        XCTAssertGreaterThanOrEqual(page, 512, "页大小不应小于 512")
        XCTAssertLessThanOrEqual(page, 65536, "页大小不应超过 65536")
    }

    /// 批量写入上限必须为正数
    func testBatchInsertLimitPositive() {
        XCTAssertGreaterThan(StorageConstants.defaultBatchInsertLimit, 0)
    }

    /// 默认分页大小必须为正数且合理（不超过批量写入上限的合理比例）
    func testDefaultPageLimitPositive() {
        XCTAssertGreaterThan(StorageConstants.defaultPageLimit, 0)
        XCTAssertLessThanOrEqual(StorageConstants.defaultPageLimit, 1000,
                                 "默认分页不应超过 1000，避免内存压力")
    }

    /// 常量值稳定性测试（防止意外修改导致行为变化）
    func testConstantValuesStability() {
        XCTAssertEqual(StorageConstants.walCheckpointThreshold, 1000)
        XCTAssertEqual(StorageConstants.connectionTimeout, 30)
        XCTAssertEqual(StorageConstants.defaultPageSize, 4096)
        XCTAssertEqual(StorageConstants.defaultBatchInsertLimit, 500)
        XCTAssertEqual(StorageConstants.defaultPageLimit, 20)
    }
}
