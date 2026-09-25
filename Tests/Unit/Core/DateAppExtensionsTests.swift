//
//  DateAppExtensionsTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Date.AppFormatStyle 格式常量与 formatted(as:) 方法的正确性。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class DateAppExtensionsTests: XCTestCase {

    // MARK: - AppFormatStyle 常量值断言

    func testAppFormatIso8601ConstantValue() {
        XCTAssertEqual(Date.AppFormatStyle.iso8601, "yyyy-MM-dd")
    }

    func testAppFormatDetailedConstantValue() {
        XCTAssertEqual(Date.AppFormatStyle.detailed, "yyyy-MM-dd HH:mm")
    }

    func testAppFormatSlashDetailedConstantValue() {
        XCTAssertEqual(Date.AppFormatStyle.slashDetailed, "yyyy/M/d HH:mm")
    }

    func testAppFormatMonthDayConstantValue() {
        XCTAssertEqual(Date.AppFormatStyle.monthDay, "M-d")
    }

    func testAppFormatYearConstantValue() {
        XCTAssertEqual(Date.AppFormatStyle.year, "yyyy")
    }

    // MARK: - formatted(as:) 格式化验证

    /// 固定日期验证 5 种格式（用 UTC 固定时区避免漂移）
    func testFormattedFixedDateFiveFormats() {
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

        utcFormatter.dateFormat = Date.AppFormatStyle.iso8601
        XCTAssertEqual(utcFormatter.string(from: date), "2026-08-06")

        utcFormatter.dateFormat = Date.AppFormatStyle.detailed
        XCTAssertEqual(utcFormatter.string(from: date), "2026-08-06 14:30")

        utcFormatter.dateFormat = Date.AppFormatStyle.slashDetailed
        XCTAssertEqual(utcFormatter.string(from: date), "2026/8/6 14:30")

        utcFormatter.dateFormat = Date.AppFormatStyle.monthDay
        XCTAssertEqual(utcFormatter.string(from: date), "8-6")

        utcFormatter.dateFormat = Date.AppFormatStyle.year
        XCTAssertEqual(utcFormatter.string(from: date), "2026")
    }

    /// formatted(as:) 返回非空字符串
    func testFormattedAnyDateReturnsNonEmpty() {
        let date = Date()
        XCTAssertFalse(date.formatted(as: Date.AppFormatStyle.iso8601).isEmpty)
        XCTAssertFalse(date.formatted(as: Date.AppFormatStyle.detailed).isEmpty)
    }
}
