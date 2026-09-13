//
//  DateFormattingAppStyleTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 Date.AppFormatStyle 预设格式常量与 Date.formatted(as:) 格式化输出。
//

import XCTest
@testable import UFPCore

final class DateFormattingAppStyleTests: XCTestCase {

    func testAppFormatStyle_constants_matchExpectedPatterns() {
        XCTAssertEqual(Date.AppFormatStyle.iso8601, "yyyy-MM-dd")
        XCTAssertEqual(Date.AppFormatStyle.detailed, "yyyy-MM-dd HH:mm")
        XCTAssertEqual(Date.AppFormatStyle.slashDetailed, "yyyy/M/d HH:mm")
        XCTAssertEqual(Date.AppFormatStyle.monthDay, "M-d")
        XCTAssertEqual(Date.AppFormatStyle.year, "yyyy")
    }

    func testFormatted_givenFixedDate_formatsCorrectly() {
        var calendar = Calendar(identifier: .gregorian)
        guard let utcTimeZone = TimeZone(secondsFromGMT: 0) else {
            XCTFail("无法构造 UTC 时区")
            return
        }
        calendar.timeZone = utcTimeZone

        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = 14
        components.minute = 30
        components.second = 0

        guard let testDate = calendar.date(from: components) else {
            XCTFail("无法根据组件构造测试日期")
            return
        }

        let yearStr = testDate.formatted(as: Date.AppFormatStyle.year)
        XCTAssertFalse(yearStr.isEmpty, "年份格式化结果不应为空")

        let customFormat = "yyyy-MM"
        let customStr = testDate.formatted(as: customFormat)
        XCTAssertTrue(customStr.contains("-"), "自定义格式化结果应包含连字符: \(customStr)")
    }
}
