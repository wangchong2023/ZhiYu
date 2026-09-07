//
//  SubscriptionQuotaCalculator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：计算订阅套餐使用配额比例、警戒值判定及文本格式化
//

import Foundation
import UFPCore

/// 订阅配额使用率与警戒状态计算器
enum SubscriptionQuotaCalculator {

    /// 安全计算配额使用比例，防止除以零、负数及 NaN 越界，结果严格落在 [0.0, 1.0]
    /// - Parameters:
    ///   - current: 当前已用量
    ///   - max: 最大配额
    /// - Returns: 归一化比例 (0.0 ~ 1.0)
    static func calculateRatio(current: Int, max: Int) -> Double {
        guard max > 0 else { return 0.0 }
        let raw = Double(current) / Double(max)
        guard !raw.isNaN && !raw.isInfinite else { return 0.0 }
        return Swift.max(0.0, Swift.min(raw, 1.0))
    }

    /// 判定是否超过警戒阈值
    /// - Parameters:
    ///   - ratio: 当前比例
    ///   - threshold: 警戒线 (默认采用业务常量)
    /// - Returns: 是否处于警戒状态
    static func isDanger(
        ratio: Double,
        threshold: Double = FeatureConstants.SubscriptionQuota.dangerRatioThreshold
    ) -> Bool {
        ratio > threshold
    }

    /// 格式化配额展示文本
    /// - Parameters:
    ///   - current: 当前用量
    ///   - max: 最大额度
    ///   - unlimitedThreshold: 无限阈值
    ///   - unlimitedSymbol: 无限符号
    /// - Returns: 格式化文本 (如 "12 / 100" 或 "12 / ∞")
    static func formatLimitText(
        current: Int,
        max: Int,
        unlimitedThreshold: Int = 999999,
        unlimitedSymbol: String = FeatureConstants.SubscriptionQuota.unlimitedSymbol
    ) -> String {
        let maxString = max < unlimitedThreshold ? "\(max)" : unlimitedSymbol
        return "\(current) / \(maxString)"
    }
}
