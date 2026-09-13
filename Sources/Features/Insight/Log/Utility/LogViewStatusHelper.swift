//
//  LogViewStatusHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：操作日志状态视觉属性与时间区间的安全解析，修复 processing 误显示为 failure 缺陷
//

import SwiftUI
import UFPCore

/// 操作日志视图状态样式与文本格式化辅助工具
public enum LogViewStatusHelper {

    /// 解析日志状态对应的背景色
    /// - Parameters:
    ///   - status: 日志执行状态
    ///   - opacity: 背景透明度
    /// - Returns: SwiftUI Color
    public static func statusBackgroundColor(for status: LogStatus?, opacity: Double) -> Color {
        guard let status = status else { return .clear }
        switch status {
        case .success:
            return Color.theme.green.opacity(opacity)
        case .failure:
            return Color.theme.red.opacity(opacity)
        case .processing:
            return Color.theme.blue.opacity(opacity)
        }
    }

    /// 解析日志状态对应的前景文字颜色
    /// - Parameter status: 日志执行状态
    /// - Returns: SwiftUI Color
    public static func statusForegroundColor(for status: LogStatus?) -> Color {
        guard let status = status else { return .clear }
        switch status {
        case .success:
            return Color.theme.green
        case .failure:
            return Color.theme.red
        case .processing:
            return Color.theme.blue
        }
    }

    /// 解析日志时间范围展示字符串
    /// - Parameters:
    ///   - startTime: 启动时间
    ///   - endTime: 结束时间
    ///   - timestamp: 默认记录时间戳
    /// - Returns: 格式化后的时间范围
    public static func resolveTimeRange(startTime: Date?, endTime: Date?, timestamp: Date) -> String {
        if let start = startTime, let end = endTime {
            let startStr = start.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Localized.currentLocale))
            let endStr = end.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Localized.currentLocale))
            return "\(startStr) - \(endStr)"
        } else {
            return timestamp.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: Localized.currentLocale))
        }
    }
}
