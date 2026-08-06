//
//  DateExtensionsTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Date.timeAgoDisplay() 相对时间显示的分支正确性。
//

import XCTest
@testable import ZhiYu

final class DateExtensionsTests: XCTestCase {

    // MARK: - 刚刚（秒级差）

    /// 当前时间 → "刚刚"
    func testTimeAgoDisplay_当前时间_返回刚刚() {
        let now = Date()
        let result = now.timeAgoDisplay()
        XCTAssertEqual(result, L10n.Common.justNow)
    }

    /// 30 秒前 → "刚刚"（秒级差不触发 minute 分支）
    func testTimeAgoDisplay_30秒前_返回刚刚() {
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        let result = thirtySecondsAgo.timeAgoDisplay()
        XCTAssertEqual(result, L10n.Common.justNow)
    }

    // MARK: - 分钟级

    /// 5 分钟前 → 非空字符串（走 minute 分支）
    func testTimeAgoDisplay_5分钟前_返回非空() {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        let result = fiveMinutesAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty, "5 分钟前应返回非空字符串")
        XCTAssertNotEqual(result, L10n.Common.justNow, "5 分钟前不应返回'刚刚'")
    }

    // MARK: - 小时级

    /// 2 小时前 → 非空字符串（走 hour 分支）
    func testTimeAgoDisplay_2小时前_返回非空() {
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        let result = twoHoursAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, L10n.Common.justNow)
    }

    // MARK: - 天级

    /// 1 天前 → "昨天"
    func testTimeAgoDisplay_1天前_返回昨天() {
        let oneDayAgo = Date().addingTimeInterval(-24 * 3600)
        let result = oneDayAgo.timeAgoDisplay()
        XCTAssertEqual(result, L10n.Common.yesterday)
    }

    /// 2 天前 → 非空字符串（走 day > 1 分支，非"昨天"）
    func testTimeAgoDisplay_2天前_返回非昨天() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 3600)
        let result = twoDaysAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, L10n.Common.yesterday, "2 天前不应返回'昨天'")
    }

    // MARK: - 月级

    /// 35 天前 → 非空字符串（走 month 分支）
    func testTimeAgoDisplay_35天前_返回非空() {
        let thirtyFiveDaysAgo = Date().addingTimeInterval(-35 * 24 * 3600)
        let result = thirtyFiveDaysAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - 年级

    /// 400 天前 → 非空字符串（走 year 分支）
    func testTimeAgoDisplay_400天前_返回非空() {
        let fourHundredDaysAgo = Date().addingTimeInterval(-400 * 24 * 3600)
        let result = fourHundredDaysAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - 返回值类型

    /// 任何时间都应返回非空字符串
    func testTimeAgoDisplay_任意时间_返回非空字符串() {
        let pastDate = Date().addingTimeInterval(-100)
        XCTAssertFalse(pastDate.timeAgoDisplay().isEmpty)
    }
}
