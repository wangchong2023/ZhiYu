//
//  LiveActivityProgressCalculator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 平台适配
//  核心职责：灵动岛与实时活动进度安全格式化，杜绝 NaN / Infinity 导致 Widget 崩溃
//

import Foundation
import UFPCore

/// 灵动岛与实时活动进度安全计算工具
public enum LiveActivityProgressCalculator {

    /// 钳制浮点进度至 [0.0, 1.0]，遇到 NaN / 无穷大时安全返回 0.0
    /// - Parameter progress: 原始浮点进度
    /// - Returns: 钳位后的有效进度
    public static func clampProgress(_ progress: Double) -> Double {
        if progress.isNaN || progress.isInfinite {
            return 0.0
        }
        if progress < 0.0 {
            return 0.0
        }
        if progress > 1.0 {
            return 1.0
        }
        return progress
    }

    /// 格式化为百分比整数字符，例如 "85%"，杜绝 "nan%" 或 Int(NaN) 崩溃
    /// - Parameter progress: 原始浮点进度
    /// - Returns: 格式化后的百分比字符串
    public static func formatPercentage(_ progress: Double) -> String {
        let valid = clampProgress(progress)
        let percent = Int((valid * FeatureConstants.PercentageBase.full).rounded(.toNearestOrAwayFromZero))
        return String(percent) + "%"
    }

    /// 安全倒计时秒数格式化
    /// - Parameter seconds: 剩余秒数
    /// - Returns: 格式化文本，非正数时返回 nil
    public static func formatRemainingSeconds(_ seconds: Int) -> String? {
        guard seconds > 0 else { return nil }
        return "\(seconds)s"
    }

    /// 安全解析小组件分类透明度，防御 NaN / 越界
    /// - Parameters:
    ///   - rawOpacity: 原始透明度浮点
    ///   - fallback: 保底默认值
    ///   - Returns: 安全透明度
    public static func clampOpacity(_ rawOpacity: Double?, fallback: Double) -> Double {
        guard let raw = rawOpacity, !raw.isNaN && !raw.isInfinite else { return fallback }
        if raw < 0.0 { return 0.0 }
        if raw > 1.0 { return 1.0 }
        return raw
    }
}
