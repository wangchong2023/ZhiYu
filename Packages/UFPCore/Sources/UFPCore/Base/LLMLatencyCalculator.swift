//
//  LLMLatencyCalculator.swift
//  UFPCore
//
//  Created by CodeFree on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：LLM 调用延迟计算工具，消除多服务间的延迟计算公式重复。
//

import Foundation

/// LLM 延迟计算工具 (DRY)
/// 统一 `Int(Date().timeIntervalSince(start) * Double(SystemConstants.millisecondsPerSecond))` 计算逻辑。
public enum LLMLatencyCalculator {
    /// 计算从起始时间到当前的延迟（毫秒）
    /// - Parameter start: 起始时间戳
    /// - Returns: 毫秒级延迟整数
    public static func milliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * Double(SystemConstants.millisecondsPerSecond))
    }
}
