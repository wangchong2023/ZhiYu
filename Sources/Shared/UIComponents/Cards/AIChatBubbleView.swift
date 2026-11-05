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
import UFPDesignSystem

// MARK: - 通用 AI 消息气泡组件

/// 跨模块复用的聊天消息气泡
public struct AIChatBubbleView: View {

    /// 消息文本
    public let text: String
    /// 是否为用户发送的消息
    public let isUser: Bool
    /// 可选的推理性能角标文案（如 "210ms TTFT · 28.4 tok/s"）
    public let metricsBadgeText: String?

    public init(text: String, isUser: Bool, metricsBadgeText: String? = nil) {
        self.text = text
        self.isUser = isUser
        self.metricsBadgeText = metricsBadgeText
    }

    public var body: some View {
        HStack {
            if isUser {
                Spacer()
                Text(text)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .aiBubbleStyle(background: Color.theme.cyan.opacity(DesignTokens.Opacity.soft), foreground: .white)
                    .contextMenu {
                        Button {
                            AppPasteboard.string = text
                            HapticFeedback.shared.trigger(.success)
                        } label: {
                            Label(L10n.Common.copy, systemImage: DesignTokens.Icons.docOnDocFill)
                        }
                    }
                    .padding(.leading, DesignTokens.Spacing.huge)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
                    Text(text)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .aiBubbleStyle(background: Color.appCard.opacity(DesignTokens.Opacity.dim), foreground: .appText)
                        .contextMenu {
                            Button {
                                AppPasteboard.string = text
                                HapticFeedback.shared.trigger(.success)
                            } label: {
                                Label(L10n.Common.copy, systemImage: DesignTokens.Icons.docOnDocFill)
                            }
                        }

                    if let badge = metricsBadgeText, !badge.isEmpty {
                        HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                            Image(systemName: DesignTokens.Icons.bolt)
                                .font(.system(size: DesignTokens.SystemFontSize.nano))
                            Text(badge)
                                .font(.system(size: DesignTokens.SystemFontSize.micro, design: .monospaced))
                        }
                        .foregroundStyle(Color.theme.cyan)
                        .padding(.horizontal, DesignTokens.Spacing.tiny)
                    }
                }
                .padding(.trailing, DesignTokens.Spacing.huge)
                Spacer()
            }
        }
    }
}

// MARK: - 气泡样式共享修饰符

/// 统一的 AI 气泡内边距 + 背景 + 圆角裁切样式，消除用户/AI/思考中三处重复的修饰符链。
private extension View {
    func aiBubbleStyle(background: Color, foreground: Color) -> some View {
        self
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.ComponentSpacing.section)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius))
    }
}

// MARK: - 通用 AI 思考中指示器组件

/// 跨模块复用的 AI 思考中 ProgressView 气泡
public struct AIThinkingBubbleView: View {

    /// 自定义加载状态文案（为 nil 时展示默认“思考中...”）
    public let customText: String?

    public init(customText: String? = nil) {
        self.customText = customText
    }

    public var body: some View {
        HStack {
            HStack(spacing: DesignTokens.Spacing.tightPadding) {
                ProgressView()
                    .tint(.appAccent)
                Text(customText ?? L10n.AI.Status.thinking)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
            }
            .aiBubbleStyle(background: Color.appCard.opacity(DesignTokens.Opacity.dim), foreground: .appText)
            .padding(.trailing, DesignTokens.Spacing.huge)

            Spacer()
        }
    }
}
