//
//  DateFormatterFactory.swift
//  UFPCore
//
//  Created by Antigravity on 2026/10/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：线程安全的 DateFormatter 缓存工厂，按 format/locale/calendar/timeZone 组合复用实例，
//           消除各业务处散落独立构造的重复样板（DateFormatter 创建昂贵且非线程安全）。
//

import Foundation

/// 线程安全日期格式化工厂
/// 以 `Date+Formatting` 为唯一出口，按配置组合缓存 DateFormatter / ISO8601DateFormatter 实例。
/// 所有格式化操作在内部锁内完成，保证多线程并发访问线程安全（DateFormatter 本身非线程安全）。
public final class DateFormatterFactory: @unchecked Sendable {

    /// 共享实例
    public static let shared = DateFormatterFactory()

    private init() {}

    private let lock = NSLock()
    private var dateFormatterCache: [String: DateFormatter] = [:]
    private var iso8601Formatter: ISO8601DateFormatter?

    // MARK: - Date → String

    /// 将日期格式化为字符串（线程安全，锁内复用缓存实例）
    public func string(
        from date: Date,
        format: String,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .current,
        isLenient: Bool = false
    ) -> String {
        lock.lock()
        defer { lock.unlock() }
        let formatter = dateFormatterUnlocked(format: format, locale: locale, calendar: calendar, timeZone: timeZone, isLenient: isLenient)
        return formatter.string(from: date)
    }

    /// 将日期按系统本地化日期/时间样式格式化为字符串（线程安全）
    public func string(
        from date: Date,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .current
    ) -> String {
        lock.lock()
        defer { lock.unlock() }
        let key = "style|\(dateStyle.rawValue)|\(timeStyle.rawValue)|\(locale.identifier)|\(timeZone.identifier)"
        let formatter: DateFormatter
        if let cached = dateFormatterCache[key] {
            formatter = cached
        } else {
            let df = DateFormatter()
            df.dateStyle = dateStyle
            df.timeStyle = timeStyle
            df.locale = locale
            df.timeZone = timeZone
            dateFormatterCache[key] = df
            formatter = df
        }
        return formatter.string(from: date)
    }

    /// 将日期按 ISO8601 互联网时间戳格式化为字符串（线程安全，UTC）
    public func iso8601String(from date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return iso8601FormatterUnlocked().string(from: date)
    }

    // MARK: - String → Date

    /// 将字符串按指定格式解析为日期（线程安全，锁内复用缓存实例）
    public func date(
        from string: String,
        format: String,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .current,
        isLenient: Bool = false
    ) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let formatter = dateFormatterUnlocked(format: format, locale: locale, calendar: calendar, timeZone: timeZone, isLenient: isLenient)
        return formatter.date(from: string)
    }

    /// 将字符串按 ISO8601 互联网时间戳解析为日期（线程安全，UTC）
    public func iso8601Date(from string: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return iso8601FormatterUnlocked().date(from: string)
    }

    /// 严格解析：先解析再格式往返校验，杜绝宽松容错（如 "/" 误解析为 "-" 或日期溢出）
    /// - Returns: 解析且双向往返一致时的日期，否则 nil
    public func strictDate(
        from string: String,
        format: String,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .current
    ) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let formatter = dateFormatterUnlocked(format: format, locale: locale, calendar: calendar, timeZone: timeZone, isLenient: false)
        guard let parsed = formatter.date(from: string) else { return nil }
        guard formatter.string(from: parsed) == string else { return nil }
        return parsed
    }

    // MARK: - 私有辅助（调用方需持有 lock）

    private func dateFormatterUnlocked(
        format: String,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone,
        isLenient: Bool
    ) -> DateFormatter {
        let key = "fmt|\(format)|\(locale.identifier)|\(calendar.identifier)|\(timeZone.identifier)|\(isLenient)"
        if let cached = dateFormatterCache[key] {
            return cached
        }
        let df = DateFormatter()
        df.locale = locale
        df.calendar = calendar
        df.dateFormat = format
        df.timeZone = timeZone
        df.isLenient = isLenient
        dateFormatterCache[key] = df
        return df
    }

    private func iso8601FormatterUnlocked() -> ISO8601DateFormatter {
        if let formatter = iso8601Formatter {
            return formatter
        }
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]
        iso8601Formatter = df
        return df
    }
}