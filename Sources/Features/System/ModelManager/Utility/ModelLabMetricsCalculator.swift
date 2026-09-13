//
//  ModelLabMetricsCalculator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：端侧大模型实验室性能指标与置信度安全格式化计算，杜绝 NaN 与无穷大异常
//

import Foundation
import UFPCore

/// 模型实验室指标安全计算器
public enum ModelLabMetricsCalculator {

    /// 校验并安全钳位置信度至 [0.0, 1.0]，异常/NaN/Infinite 时保底返回 0.0
    /// - Parameter score: 原始置信度评分
    /// - Returns: 钳位后的有效浮点数
    public static func clampConfidence(_ score: Double) -> Double {
        guard !score.isNaN && !score.isInfinite else { return 0.0 }
        return max(0.0, min(1.0, score))
    }

    /// 格式化置信度百分比字符，例如 "85%"，杜绝 "nan%" 或 "inf%"
    /// - Parameter score: 原始置信度评分
    /// - Returns: 格式化后的百分比字符
    public static func formatConfidencePercentage(_ score: Double) -> String {
        let clamped = clampConfidence(score)
        return String(format: "%.0f%%", clamped * FeatureConstants.PercentageBase.full)
    }

    /// 格式化推理速度，例如 "45.2"，在 NaN/无穷大时保底 "0.0"
    /// - Parameter speed: 每秒生成 Token 数量
    /// - Returns: 格式化字符串
    public static func formatSpeed(_ speed: Double) -> String {
        guard !speed.isNaN && !speed.isInfinite else { return "0.0" }
        return String(format: "%.1f", max(0.0, speed))
    }

    /// 格式化物理运存开销，例如 "1024"，在 NaN/无穷大时保底 "0"
    /// - Parameter memory: 运存大小（MB）
    /// - Returns: 格式化字符串
    public static func formatMemory(_ memory: Double) -> String {
        guard !memory.isNaN && !memory.isInfinite else { return "0" }
        return String(format: "%.0f", max(0.0, memory))
    }
}
