//
//  AIChatBubbleView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层 / UI 组件
//  核心职责：提供 AI 智能对话与端侧大模型沙盒通用的消息气泡 (AIChatBubbleView) 与思考中加载组件 (AIThinkingBubbleView)。
//

import SwiftUI

// MARK: - 通用 AI 消息气泡组件

/// 跨模块复用的聊天消息气泡
public struct AIChatBubbleView: View {

    /// 消息文本
    public let text: String
    /// 是否为用户发送的消息
    public let isUser: Bool

    public init(text: String, isUser: Bool) {
        self.text = text
        self.isUser = isUser
    }

    public var body: some View {
        HStack {
            if isUser {
                Spacer()
                Text(text)
                    .font(.subheadline)
                    .padding(.horizontal, DesignSystem.medium)
                    .padding(.vertical, ComponentSpacing.section)
                    .background(Color.theme.cyan.opacity(DesignSystem.Opacity.soft))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
                    .padding(.leading, DesignSystem.huge)
            } else {
                Text(text)
                    .font(.subheadline)
                    .padding(.horizontal, DesignSystem.medium)
                    .padding(.vertical, ComponentSpacing.section)
                    .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
                    .foregroundStyle(.appText)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
                    .padding(.trailing, DesignSystem.huge)
                Spacer()
            }
        }
    }
}

// MARK: - 通用 AI 思考中指示器组件

/// 跨模块复用的 AI 思考中 ProgressView 气泡
public struct AIThinkingBubbleView: View {

    public init() {}

    public var body: some View {
        HStack {
            HStack(spacing: DesignSystem.tightPadding) {
                ProgressView()
                    .tint(.appAccent)
                Text(L10n.AI.Status.thinking)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
            }
            .padding(.horizontal, DesignSystem.medium)
            .padding(.vertical, ComponentSpacing.section)
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
            .padding(.trailing, DesignSystem.huge)

            Spacer()
        }
    }
}
