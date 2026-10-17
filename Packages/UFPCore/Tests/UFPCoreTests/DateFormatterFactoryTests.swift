//
//  DateFormatterFactoryTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证线程安全 DateFormatter 工厂的格式化、解析、ISO8601、严格解析及并发安全，
//           确保集中化后行为等价且无回归。
//

import XCTest
@testable import UFPCore

final class DateFormatterFactoryTests: XCTestCase {

    private let factory = DateFormatterFactory.shared
    private let referenceDate = Date(timeIntervalSince1970: 1_770_000_000) // 2026-02-04 左右

    // MARK: - Date → String

    /// 验证标准日期格式输出与直接 DateFormatter 等价
    func testString_StandardFormat() {
        let expected = Self.expectedDateString(format: "yyyy-MM-dd")
        let formatted = factory.string(from: referenceDate, format: "yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertEqual(formatted, expected)
    }

    /// 验证详细时间格式输出与直接 DateFormatter 等价
    func testString_DetailedFormat() {
        let expected = Self.expectedDateString(format: "yyyy-MM-dd HH:mm", timeZone: TimeZone(secondsFromGMT: 0)!)
        let formatted = factory.string(from: referenceDate, format: "yyyy-MM-dd HH:mm", locale: Locale(identifier: "en_US_POSIX"), timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(formatted, expected)
    }

    /// 验证日期/时间样式格式化不崩溃
    func testString_DateStyleTimeStyle() {
        let formatted = factory.string(from: referenceDate, dateStyle: .medium, timeStyle: .short)
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - String → Date

    /// 验证按格式解析
    func testDate_ParsesCorrectly() {
        let date = factory.date(from: "2026-02-04", format: "yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertNotNil(date)
    }

    /// 验证非法字符串解析返回 nil
    func testDate_InvalidStringReturnsNil() {
        let date = factory.date(from: "not a date", format: "yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertNil(date)
    }

    // MARK: - ISO8601

    /// 验证 ISO8601 格式化与解析往返
    func testISO8601_RoundTrip() {
        let now = Date(timeIntervalSince1970: 1_770_000_000)
        let string = factory.iso8601String(from: now)
        let parsed = factory.iso8601Date(from: string)
        XCTAssertEqual(parsed, now)
    }

    // MARK: - 严格解析

    /// 验证严格解析拒绝宽松容错（斜杠被误解析为横线）
    func testStrictDate_RejectsLooseParsing() {
        let date = factory.strictDate(from: "2026/02/04", format: "yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"), calendar: Calendar(identifier: .gregorian))
        XCTAssertNil(date)
    }

    /// 验证严格解析接受规范字符串
    func testStrictDate_AcceptsCanonicalString() {
        let date = factory.strictDate(from: "2026-02-04", format: "yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"), calendar: Calendar(identifier: .gregorian))
        XCTAssertNotNil(date)
    }

    // MARK: - 并发安全

    /// 验证并发格式化不崩溃且结果一致
    func testConcurrentFormatting_ThreadSafe() {
        let expectation = expectation(description: "concurrent")
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()
        let resultLock = NSLock()
        var results: [String] = []

        for _ in 0..<50 {
            group.enter()
            queue.async {
                let result = self.factory.string(from: self.referenceDate, format: "yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"))
                resultLock.lock()
                results.append(result)
                resultLock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(Set(results).count, 1, "并发格式化结果应一致")
    }

    // MARK: - 测试辅助

    /// 用独立 DateFormatter 计算期望输出（验证工厂等价性，避免硬编码日期）
    private static func expectedDateString(format: String, timeZone: TimeZone = .current) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = format
        df.timeZone = timeZone
        return df.string(from: Date(timeIntervalSince1970: 1_770_000_000))
    }
}