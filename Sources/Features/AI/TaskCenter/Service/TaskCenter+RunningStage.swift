//
//  TaskCenter+RunningStage.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 功能层
//  核心职责：TaskCenter 扩展，提供当前运行任务阶段的便捷访问，消除 ChatView 与 AIPulseIndicator 间的重复逻辑。
//

import Foundation

extension TaskCenter {
    /// 当前正在运行任务的阶段（若无运行任务则返回 .general）
    var currentRunningStage: TaskStage {
        if let runningTask = tasks.first(where: { if case .running = $0.status { return true }; return false }) {
            if case .running(_, let stage) = runningTask.status {
                return stage
            }
        }
        return .general
    }
}
