//
//  LogStatus.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：操作执行状态枚举，供 Logger 与日志审计共享。
//
import Foundation

/// 操作执行状态
public enum LogStatus: String, Codable, Sendable {
    case success
    case failure
    case processing
}
