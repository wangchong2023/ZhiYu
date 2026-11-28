//
//  MemoryEngineDefaults.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/11/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICore]
//  核心职责：记忆引擎适配器默认配置常量（钳位下限、窗口参数等），消除魔鬼数字。
//

import Foundation

/// 记忆引擎共享默认参数（消除魔鬼数字）
enum MemoryEngineDefaults {
    /// recentCount 最小保留条数（防御 ≤ 0 输入导致近期上下文全部丢失）
    static let minimumRecentCount: Int = 1
}
