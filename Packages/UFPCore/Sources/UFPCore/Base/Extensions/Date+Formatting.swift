//
//  Date+Formatting.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：通用日期格式化扩展，与业务无关。
//

import Foundation

extension Date {
    /// 预定义的日期格式规范
    public struct AppFormatStyle {
        /// 标准日期：2026-05-15
        public static let iso8601 = "yyyy-MM-dd"
        /// 详细时间：2026-05-15 14:30
        public static let detailed = "yyyy-MM-dd HH:mm"
        /// 斜杠详细时间：2026/5/15 14:30
        public static let slashDetailed = "yyyy/M/d HH:mm"
        /// 紧凑月份：5-15
        public static let monthDay = "M-d"
        /// 纯年份：2026
        public static let year = "yyyy"
    }

    /// 将日期格式化为指定的字符串
    /// - Parameter format: 日期格式字符串（推荐使用 `FormatStyle` 中的定义）
    /// - Returns: 格式化后的字符串
    public func formatted(as format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}
