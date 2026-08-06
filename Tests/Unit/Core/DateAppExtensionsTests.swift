//
//  DateAppExtensionsTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Date.AppFormat 格式常量与 formatted(as:) 方法的正确性。
//

import XCTest
@testable import ZhiYu

final class DateAppExtensionsTests: XCTestCase {

    // MARK: - AppFormat 常量值断言

    func testAppFormat_iso8601常量值() {
        XCTAssertEqual(Date.AppFormat.iso8601, "yyyy-MM-dd")
    }

    func testAppFormat_detailed常量值() {
        XCTAssertEqual(Date.AppFormat.detailed, "yyyy-MM-dd HH:mm")
    }

    func testAppFormat_slashDetailed常量值() {
        XCTAssertEqual(Date.AppFormat.slashDetailed, "yyyy/M/d HH:mm")
    }

    func testAppFormat_monthDay常量值() {
        XCTAssertEqual(Date.AppFormat.monthDay, "M-d")
    }

    func testAppFormat_year常量值() {
        XCTAssertEqual(Date.AppFormat.year, "yyyy")
    }

    // MARK: - formatted(as:) 格式化验证

    /// 固定日期验证 5 种格式（用 UTC 固定时区避免漂移）
    func testFormatted_固定日期_5种格式() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 6
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            XCTFail("无法构造测试日期")
            return
        }

        let utcFormatter = DateFormatter()
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")

        utcFormatter.dateFormat = Date.AppFormat.iso8601
        XCTAssertEqual(utcFormatter.string(from: date), "2026-08-06")

        utcFormatter.dateFormat = Date.AppFormat.detailed
        XCTAssertEqual(utcFormatter.string(from: date), "2026-08-06 14:30")

        utcFormatter.dateFormat = Date.AppFormat.slashDetailed
        XCTAssertEqual(utcFormatter.string(from: date), "2026/8/6 14:30")

        utcFormatter.dateFormat = Date.AppFormat.monthDay
        XCTAssertEqual(utcFormatter.string(from: date), "8-6")

        utcFormatter.dateFormat = Date.AppFormat.year
        XCTAssertEqual(utcFormatter.string(from: date), "2026")
    }

    /// formatted(as:) 返回非空字符串
    func testFormatted_任意日期_返回非空() {
        let date = Date()
        XCTAssertFalse(date.formatted(as: Date.AppFormat.iso8601).isEmpty)
        XCTAssertFalse(date.formatted(as: Date.AppFormat.detailed).isEmpty)
    }
}
