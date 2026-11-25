//
//  ReminderServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 ReminderService 模块的抽象契约接口。
//
import Foundation

/// 提醒事项服务协议
public protocol ReminderServiceProtocol: Sendable {
    /// 请求提醒事项访问权限
    func requestAccess() async -> Bool
    
    /// 创建单条提醒事项
    /// - Parameters:
    ///   - title: 标题
    ///   - notes: 备注
    func createReminder(title: String, notes: String) async throws
}
