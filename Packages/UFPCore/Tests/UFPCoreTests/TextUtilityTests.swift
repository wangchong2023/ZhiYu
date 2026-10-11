//
//  TextUtilityTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 CJK/耗时/文件/时间工具（CJKSpacingFormatter、LLMLatencyCalculator、
//           FileManager.folderSize、Date.relativeTimeUnit）的通用语义正确性。
//

import XCTest
@testable import UFPCore

final class TextUtilityTests: XCTestCase {

    // MARK: - CJK 空格注入

    func testSpacing_cjkFollowedByEnglish_insertsSpace() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("智宇AI"), "智宇 AI")
    }

    func testSpacing_englishFollowedByCJK_insertsSpace() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("AI智宇"), "AI 智宇")
    }

    func testSpacing_cjkFollowedByNumber_insertsSpace() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("版本6发布"), "版本 6 发布")
    }

    func testSpacing_numberFollowedByCJK_insertsSpace() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("6发布"), "6 发布")
    }

    func testSpacing_emptyString_returnsEmpty() {
        XCTAssertEqual(CJKSpacingFormatter.spacing(""), "")
    }

    func testSpacing_pureCJK_unchanged() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("智宇知识管理"), "智宇知识管理")
    }

    func testSpacing_pureEnglish_unchanged() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("Hello World"), "Hello World")
    }

    func testSpacing_hiraganaFollowedByEnglish_insertsSpace() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("こんにちはHello"), "こんにちは Hello")
    }

    func testSpacing_katakanaFollowedByNumber_insertsSpace() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("カタカナ123"), "カタカナ 123")
    }

    func testSpacing_alreadySpaced_notDoubleSpaced() {
        XCTAssertEqual(CJKSpacingFormatter.spacing("智宇 AI"), "智宇 AI", "已有空格不应被重复注入")
    }

    func testSpacing_cjkFollowedByAt_insertsSpace() {
        XCTAssertTrue(CJKSpacingFormatter.spacing("智宇@用户").contains("智宇 @"))
    }

    func testSpacing_cjkFollowedByDash_insertsSpace() {
        XCTAssertTrue(CJKSpacingFormatter.spacing("智宇-知识").contains("智宇 -"))
    }

    func testSpacing_mixedMultipleSegments_allSpaced() {
        let result = CJKSpacingFormatter.spacing("智宇AI知识管理v6版本")
        XCTAssertTrue(result.contains("智宇 AI"))
        XCTAssertTrue(result.contains("AI 知识"))
        XCTAssertTrue(result.contains("v6 版本"))
    }

    func testPanguFormatter_alias_equivalentToCJKSpacingFormatter() {
        let input = "智宇AI"
        XCTAssertEqual(
            CJKSpacingFormatter.spacing(input),
            PanguFormatter.spacing(input),
            "PanguFormatter 应为 CJKSpacingFormatter 的别名"
        )
    }

    // MARK: - LLM 延迟计算

    func testMilliseconds_zeroElapsed_returnsZero() {
        XCTAssertEqual(LLMLatencyCalculator.milliseconds(since: Date()), 0)
    }

    func testMilliseconds_elapsed_returnsNonNegative() {
        let start = Date().addingTimeInterval(-100)
        XCTAssertGreaterThanOrEqual(LLMLatencyCalculator.milliseconds(since: start), 0)
    }

    func testMilliseconds_approximatelyMatchesElapsed() {
        let start = Date().addingTimeInterval(-1.5)
        let ms = LLMLatencyCalculator.milliseconds(since: start)
        XCTAssertEqual(Double(ms), 1500.0, accuracy: 50.0)
    }

    // MARK: - 文件夹大小统计

    func testFolderSize_emptyDirectory_returnsZero() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        XCTAssertEqual(fm.folderSize(at: dir), 0)
    }

    func testFolderSize_directoryWithFiles_sumsSizes() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let data = Data(repeating: 0x41, count: 100)
        try data.write(to: dir.appendingPathComponent("a.bin"))
        try data.write(to: dir.appendingPathComponent("sub"))
        XCTAssertEqual(fm.folderSize(at: dir), 200)
    }

    func testFolderSize_nonexistentDirectory_returnsZero() {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertEqual(fm.folderSize(at: dir), 0)
    }

    // MARK: - 相对时间单位

    func testRelativeTimeUnit_now_returnsNow() {
        XCTAssertEqual(Date().relativeTimeUnit(), .now)
    }

    func testRelativeTimeUnit_seconds_returnsSeconds() {
        let date = Date().addingTimeInterval(-30)
        if case .seconds = date.relativeTimeUnit() {
            // 期望命中
        } else {
            XCTFail("30 秒前应返回 .seconds")
        }
    }

    func testRelativeTimeUnit_minutes_returnsMinutes() {
        let date = Date().addingTimeInterval(-5 * 60)
        if case .minutes(let v) = date.relativeTimeUnit(), v == 5 {
            // 期望命中
        } else {
            XCTFail("5 分钟前应返回 .minutes(5)")
        }
    }

    func testRelativeTimeUnit_hours_returnsHours() {
        let date = Date().addingTimeInterval(-2 * 3600)
        if case .hours(let v) = date.relativeTimeUnit(), v == 2 {
            // 期望命中
        } else {
            XCTFail("2 小时前应返回 .hours(2)")
        }
    }

    func testRelativeTimeUnit_oneDay_returnsDays1() {
        let date = Date().addingTimeInterval(-24 * 3600)
        XCTAssertEqual(date.relativeTimeUnit(), .days(1))
    }

    func testRelativeTimeUnit_twoDays_returnsDays2() {
        let date = Date().addingTimeInterval(-2 * 24 * 3600)
        if case .days(let v) = date.relativeTimeUnit(), v == 2 {
            // 期望命中
        } else {
            XCTFail("2 天前应返回 .days(2)")
        }
    }

    func testRelativeTimeUnit_months_returnsMonths() {
        let date = Date().addingTimeInterval(-35 * 24 * 3600)
        if case .months(let v) = date.relativeTimeUnit(), v >= 1 {
            // 期望命中
        } else {
            XCTFail("35 天前应返回 .months")
        }
    }

    func testRelativeTimeUnit_years_returnsYears() {
        let date = Date().addingTimeInterval(-400 * 24 * 3600)
        if case .years(let v) = date.relativeTimeUnit(), v >= 1 {
            // 期望命中
        } else {
            XCTFail("400 天前应返回 .years")
        }
    }
}
