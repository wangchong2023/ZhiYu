//
//  BirthdayDateFormatter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：提供历法无关（POSIX/公历）的生日日期格式化与解析工具，防止非公历设备（如佛历）解析失败
//

import Foundation
import UFPCore

/// 跨平台用户生日日期格式化工具 (强制 POSIX Locale 与公历 Calendar)
public enum BirthdayDateFormatter {

    private static let posixLocale = Locale(identifier: "en_US_POSIX")
    private static let gregorianCalendar = Calendar(identifier: .gregorian)
    private static let dateFormat = "yyyy-MM-dd"

    /// 将日期转换为标准 yyyy-MM-dd 格式字符串
    /// - Parameter date: 输入日期
    /// - Returns: yyyy-MM-dd 字符串
    public static func string(from date: Date) -> String {
        DateFormatterFactory.shared.string(from: date, format: dateFormat, locale: posixLocale, calendar: gregorianCalendar)
    }

    /// 将标准 yyyy-MM-dd 字符串解析为 Date 对象
    /// - Parameter string: yyyy-MM-dd 格式字符串
    /// - Returns: 解析后的 Date 对象，解析失败或格式不严格匹配返回 nil
    public static func date(from string: String) -> Date? {
        // 严格双向往返校验，杜绝 DateFormatter 宽松容错（如将 "/" 误解析为 "-" 或日期溢出）
        DateFormatterFactory.shared.strictDate(from: string, format: dateFormat, locale: posixLocale, calendar: gregorianCalendar)
    }
}
