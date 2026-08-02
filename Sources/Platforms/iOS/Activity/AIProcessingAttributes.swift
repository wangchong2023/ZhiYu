//
//  AIProcessingAttributes.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
import Foundation
#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

#if os(iOS) && !targetEnvironment(macCatalyst)
/// 实时活动任务类型
public enum ActivityKind: String, Codable, Hashable, Sendable {
    case synthesis
    case ingestOCR
    case voiceNote
}

/// AI 治理/处理任务的实时活动属性
public struct AIProcessingAttributes: ActivityAttributes, Hashable, Sendable {
    /// 动态数据：在活动期间会频繁变化的内容（如进度、状态文本）
    public struct ContentState: Codable, Hashable, Sendable {
        /// 当前处理进度 (0.0 - 1.0)
        public var progress: Double
        /// 当前步骤的状态描述文字
        public var status: String
        /// 活动类型
        public var kind: ActivityKind
        /// 关联引用源数量
        public var sourceCount: Int
        /// 当前处理的文件名/笔记标题
        public var currentFileName: String
        /// 预估剩余秒数
        public var estimatedSecondsRemaining: Int
        
        public init(
            progress: Double,
            status: String,
            kind: ActivityKind = .synthesis,
            sourceCount: Int = 0,
            currentFileName: String = "",
            estimatedSecondsRemaining: Int = 0
        ) {
            self.progress = progress
            self.status = status
            self.kind = kind
            self.sourceCount = sourceCount
            self.currentFileName = currentFileName
            self.estimatedSecondsRemaining = estimatedSecondsRemaining
        }
    }

    /// 静态数据：在活动开启时确定且不再变化的内容
    /// 任务显示名称 (例如: "AI 合成", "文档解析", "语音速记")
    public var taskName: String
    /// 任务启动时间
    public var startTime: Date
    
    public init(taskName: String, startTime: Date) {
        self.taskName = taskName
        self.startTime = startTime
    }
}
#endif
