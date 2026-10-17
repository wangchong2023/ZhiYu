//
//  Date+RelativeTime.swift
//  UFPCore
//
//  Created by CodeFree on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：Date 相对时间差纯计算，与本地化文案解耦，供 App 层组合 L10n 输出。
//

import Foundation

/// 相对时间单位枚举（纯计算，无本地化文案）
public enum RelativeTimeUnit: Sendable, Equatable {
    /// 刚刚（当前时间）
    case now
    /// 秒级差值（过去若干秒）
    case seconds
    /// 分钟级差值
    case minutes(Int)
    /// 小时级差值
    case hours(Int)
    /// 天级差值
    case days(Int)
    /// 月级差值
    case months(Int)
    /// 年级差值
    case years(Int)
}

extension Date {
    /// 计算从 `self` 到 `now` 的相对时间单位（纯计算，不依赖 L10n）
    /// - Parameter now: 参照时间，默认当前时间
    /// - Returns: 相对时间单位；优先级与 App 层 timeAgoDisplay 分支对齐
    public func relativeTimeUnit(to now: Date = Date()) -> RelativeTimeUnit {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: self,
            to: now
        )
        if let year = components.year, year > 0 { return .years(year) }
        if let month = components.month, month > 0 { return .months(month) }
        if let day = components.day, day > 0 {
            return day == 1 ? .days(1) : .days(day)
        }
        if let hour = components.hour, hour > 0 { return .hours(hour) }
        if let minute = components.minute, minute > 0 { return .minutes(minute) }
        if let second = components.second, second > 0 { return .seconds }
        return .now
    }
}
