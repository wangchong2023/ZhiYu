//
//  WidgetWatchNumberFormattingTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台测试
//  核心职责：验证 WidgetWatch 数值格式化阈值、除数常量以及 ForEach 重复标题处理。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class WidgetWatchNumberFormattingTests: XCTestCase {

    /// 验证 ForEach 用 enumerated + offset 能正确保留重复标题
    func testForEachWithDuplicateTitles_retainsAllEntries() {
        let recentTitles = ["标题A", "标题A", "标题B", "标题A", "标题C"]
        let prefix = Array(recentTitles.prefix(PlatformConstants.WidgetWatch.maxRecentTitles).enumerated())
        XCTAssertEqual(prefix.count, 5, "重复标题不应被去重")
        XCTAssertEqual(prefix.map(\.element), recentTitles, "所有标题都应保留")
    }

    /// 验证 PlatformConstants.WidgetWatch 格式化常量配置
    func testWidgetWatchConstants_thresholdsAndDivisorsMatch() {
        XCTAssertEqual(PlatformConstants.WidgetWatch.tenThousandThreshold, 10000)
        XCTAssertEqual(PlatformConstants.WidgetWatch.thousandThreshold, 1000)
        XCTAssertEqual(PlatformConstants.WidgetWatch.tenThousandDivisor, 10000.0)
        XCTAssertEqual(PlatformConstants.WidgetWatch.thousandDivisor, 1000.0)
    }

    /// 验证进度环分母常量为 100.0
    func testProgressRingDenominator_isOneHundred() {
        XCTAssertEqual(PlatformConstants.WidgetWatch.progressRingDenominator, 100.0)
    }
}
