//
//  BackgroundTaskProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 BackgroundTask 模块的抽象契约接口。
//
import Foundation

/// 后台任务调度协议
@MainActor
public protocol BackgroundTaskProtocol: Sendable {
    /// 注册后台处理任务
    func register(handler: @escaping @Sendable @MainActor () -> Void)
    
    /// 调度后台任务
    func schedule()
}
