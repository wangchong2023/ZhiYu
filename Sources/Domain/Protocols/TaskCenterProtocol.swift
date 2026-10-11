//
//  TaskCenterProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 TaskCenter 模块的抽象契约接口。
//
import Foundation
import ZhiYuDomain

/// 任务中心协议 (L1.5-Domain)
/// 抽象任务进度追踪能力，使 Domain 层无需直接依赖 L2 TaskCenter
@MainActor
public protocol TaskCenterProtocol: Sendable {

    /// 派发并追踪一个新的异步任务
    /// - Parameters:
    ///   - type: 任务分类
    ///   - name: 面向用户展示的任务名称
    ///   - target: 任务处理的目标实体或操作对象
    /// - Returns: 分配的全局唯一任务追踪 ID
    func addTask(type: TaskType, name: String, target: String) -> UUID

    /// 上报或更新特定任务的生命周期状态及百分比进度
    /// - Parameters:
    ///   - id: 任务追踪 ID
    ///   - status: 最新的执行状态
    func updateTask(_ id: UUID, status: TaskStatus)

    /// 标记特定任务为已完成（这通常会触发 UI 层将任务状态流转为 success 并逐步清理）
    /// - Parameter id: 任务追踪 ID
    func completeTask(id: UUID)

    /// 标记特定任务为已失败并记录异常原因
    /// - Parameters:
    ///   - id: 任务追踪 ID
    ///   - error: 本地化的报错详细描述
    func failTask(id: UUID, error: String)
}
