//
//  TagBubbleRatioCalculator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层辅助工具
//  核心职责：提供标签气泡与胶囊大小缩放比例的归一化计算，内置极值越界防护（clamp 0.0...1.0）与除零/NaN 防御。
//

import Foundation

public enum TagBubbleRatioCalculator {
    /// 默认归一化比例（极值无跨度时的回退值）
    @usableFromInline static let defaultRatioValue: Double = FeatureConstants.TagBubbleCloud.defaultRatio

    /// 计算标签气泡在词频范围内的安全归一化比例 (0.0 到 1.0)
    /// - Parameters:
    ///   - count: 当前标签的引用计数
    ///   - counts: 活跃标签的计数列表
    ///   - defaultRatio: 当最大最小值相等或无足够跨度时的默认比例 (默认为 0.5)
    /// - Returns: 经过严格边界保护的比例值 (保证在 0.0...1.0 区间内，杜绝负数与 NaN)
    public static func calculate(for count: Int, from counts: [Int], defaultRatio: Double = defaultRatioValue) -> Double {
        let safeDefaultRatio = defaultRatio.isFinite
            ? max(0.0, min(1.0, defaultRatio))
            : defaultRatioValue
        guard let maxVal = counts.max(), let minVal = counts.min() else {
            return 0.0
        }
        // 使用 Double 差值避免 Int.max - Int.min 整数溢出崩溃
        let diff = Double(maxVal) - Double(minVal)
        guard diff > 0, diff.isFinite else {
            return safeDefaultRatio
        }
        let rawRatio = (Double(count) - Double(minVal)) / diff
        guard rawRatio.isFinite else {
            return safeDefaultRatio
        }
        return max(0.0, min(1.0, rawRatio))
    }
}
