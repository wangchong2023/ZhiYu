//
//  HapticFeedbackProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 HapticFeedback 模块的抽象契约接口。
//
import Foundation

/// 触感模式枚举：定义了系统通用的交互语义
public enum HapticPattern: Sendable {
    case success    // 操作成功
    case error      // 操作失败或拒绝
    case warning    // 警告
    case processing // AI 正在处理
    case lock       // 笔记本加锁
    case unlock     // 笔记本解锁
    case link       // 链接建立
    case selection  // UI 选择反馈
    case pulse      // AI 思考脉搏 (循环轻触)
}

/// 触感反馈协议：平台无关的触感接口
@MainActor
public protocol HapticFeedbackProtocol: Sendable {
    /// 触发指定模式的触感反馈
    func trigger(_ pattern: HapticPattern)
}
