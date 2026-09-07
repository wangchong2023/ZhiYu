//
//  IngestProgressCalculator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：计算与安全格式化文档导入进度与百分比，杜绝 NaN / Infinity 闪退
//

import Foundation
import UFPCore

/// 知识摄入进度安全计算器
public enum IngestProgressCalculator {

    /// 安全钳位进度至 [0.0, 1.0]，并在遇到 NaN / 无穷大时安全返回保底值 0.0
    /// - Parameter progress: 原始浮点进度
    /// - Returns: 安全钳位后的浮点进度
    public static func clampProgress(_ progress: Double) -> Double {
        guard !progress.isNaN && !progress.isInfinite else { return 0.0 }
        return max(0.0, min(1.0, progress))
    }

    /// 将浮点进度格式化为百分比整数（0 ~ 100），杜绝 NaN 转换为 Int 触发的崩溃
    /// - Parameter progress: 原始浮点进度
    /// - Returns: 0 ~ 100 整数
    public static func formatPercentage(_ progress: Double) -> Int {
        let clamped = clampProgress(progress)
        return Int(clamped * FeatureConstants.PercentageBase.full)
    }

    /// 提取任务的当前进度与执行阶段
    /// - Parameter task: 全局任务
    /// - Returns: (安全进度, 任务阶段)
    public static func resolveTaskProgress(_ task: GlobalTask?) -> (progress: Double, stage: TaskStage) {
        guard let task = task, case .running(let rawProgress, let stage) = task.status else {
            return (0.0, .pending)
        }
        return (clampProgress(rawProgress), stage)
    }
}
