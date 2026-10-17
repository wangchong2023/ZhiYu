//
//  TaskModels.swift
//  ZhiYuDomain
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomain]
//  核心职责：定义跨 AI / Knowledge 域复用的后台任务模型 (GlobalTask / TaskType / TaskStatus / TaskStage)。
//           任务中心在 AI 与知识导入等场景复用同一套任务模型，纯数据定义不依赖 UI / L10n，
//           展示相关的 icon / defaultColor / localizedName 由 App 层以 extension 形式补充。
//

import Foundation

/// 任务类型
public enum TaskType: String, CaseIterable, Sendable {
    case ai             // 通用 AI 任务
    case ingest         // 导入任务
    case aiScan         // AI 扫描
    case healthCheck    // 健康检查
    case synthesis      // 知识合成
}

/// RAG / AI 执行阶段 (用于多维视觉反馈)
public enum TaskStage: String, Equatable, Sendable {
    case pending       // 准备阶段
    case extraction    // 文本提取/预处理 (Gray)
    case enrichment    // AI语义增强 (Indigo)
    case chunking      // 语义分块 (Cyan)
    case embedding     // 向量化/特征提取 (Teal)
    case retrieval     // 数据库检索/BM25 (Blue)
    case synthesis     // 大模型合成生成 (Purple)
    case general       // 通用执行 (Orange)
}

/// 任务执行状态
public enum TaskStatus: Equatable, Sendable {
    case pending                                      // 等待中
    case running(progress: Double, stage: TaskStage)  // 执行中（带进度与具体阶段）
    case completed                                    // 已完成
    case failed(error: String)                        // 执行失败（带错误信息）

    /// 判等比较
    public static func == (lhs: TaskStatus, rhs: TaskStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (.completed, .completed): return true
        case let (.running(p1, s1), .running(p2, s2)): return p1 == p2 && s1 == s2
        case let (.failed(e1), .failed(e2)): return e1 == e2
        default: return false
        }
    }
}

/// 全球异步任务模型
public struct GlobalTask: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let type: TaskType
    public let name: String                // 任务名称
    public let target: String              // 目标对象
    public var status: TaskStatus          // 当前状态
    public let startTime = Date()          // 启动时间
    public var isRead: Bool = false        // 用户是否已读
    public var associatedPageID: UUID?     // 关联页面
    public var subLogs: [String] = []      // 细粒度子状态日志 (消除信息真空)

    public init(type: TaskType, name: String, target: String, status: TaskStatus,
                isRead: Bool = false, associatedPageID: UUID? = nil, subLogs: [String] = []) {
        self.type = type
        self.name = name
        self.target = target
        self.status = status
        self.isRead = isRead
        self.associatedPageID = associatedPageID
        self.subLogs = subLogs
    }
}