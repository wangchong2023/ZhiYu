//
//  LabChatMessage.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：实验室多轮对话场景下的单条聊天消息数据模型，承载消息唯一标识、发送方角色与文本内容。
//

import Foundation

/// 实验室专属多轮聊天消息结构体
public struct LabChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let isUser: Bool
    public let text: String
    public let firstTokenLatencyMs: Int?
    public let tokensPerSecond: Double?

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        firstTokenLatencyMs: Int? = nil,
        tokensPerSecond: Double? = nil
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.firstTokenLatencyMs = firstTokenLatencyMs
        self.tokensPerSecond = tokensPerSecond
    }

    /// 格式化气泡底部实时性能角标文案
    public var metricsBadgeText: String? {
        guard !isUser,
              let ttft = firstTokenLatencyMs,
              let tps = tokensPerSecond,
              tps > 0 else {
            return nil
        }
        return L10n.ModelManager.Lab.Chat.metricsBadgeFormat(ttft, tps)
    }
}
