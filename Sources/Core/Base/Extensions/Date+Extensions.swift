//
//  Date+Extensions.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：Swift 标准类型的便利扩展（Date 格式化、字符串工具等）。
//
import Foundation
import UFPCore

extension Date {
    /// 返回语义化的相对时间字符串 (例如: "", "5 ", "2 ")
    /// 时间单位计算委托 UFPCore.Date.relativeTimeUnit(to:)，本地化文案保留在 App 层。
    public func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale.current
        
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self, to: now)
        
        switch relativeTimeUnit(to: now) {
        case .now, .seconds:
            return L10n.Common.justNow
        case .days(1):
            return L10n.Common.yesterday
        case .years, .months, .days, .hours, .minutes:
            return formatter.localizedString(from: components)
        }
    }
}
