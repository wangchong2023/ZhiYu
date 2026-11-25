//
//  AITaskProgress.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 AI 任务进度 (AITaskMetadata/AITaskProgressState) 的领域模型，追踪异步任务生命周期。
//
import Foundation

/// AI 任务进度元数据
public struct AITaskMetadata: Codable, Hashable, Sendable {
    /// 任务名称 (例如: "AI ", "")
    public let taskName: String
    /// 任务启动时间
    public let startTime: Date
    
    public init(taskName: String, startTime: Date) {
        self.taskName = taskName
        self.startTime = startTime
    }
}

/// AI 任务实时进度状态
public struct AITaskProgressState: Codable, Hashable, Sendable {
    /// 当前处理进度 (0.0 - 1.0)
    public let progress: Double
    /// 当前步骤的状态描述文字
    public let status: String
    
    public init(progress: Double, status: String) {
        self.progress = progress
        self.status = status
    }
}
