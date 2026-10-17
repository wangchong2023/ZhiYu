//
//  AppLoadingOverlay.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：全屏加载遮罩组件，统一各页面的 Loading 状态展示。
//

import SwiftUI

// MARK: - App Loading Overlay
/// 全屏加载遮罩，统一各页面的 Loading 状态展示。
/// 全屏加载覆盖层组件
/// 负责在执行高开销异步操作（如数据库重建、大文件导入）时提供沉浸式的 Loading 界面，防止误操作
public struct AppLoadingOverlay: View {
    /// 是否显示加载遮罩
    public let isLoading: Bool
    /// 加载提示文字（可选）
    public let message: String?
    /// 遮罩背景色（默认半透明黑色）
    public let backgroundColor: Color
    /// 前景色（默认 accent）
    public let foregroundColor: Color

    public init(
        isLoading: Bool,
        message: String? = nil,
        backgroundColor: Color = Color.theme.black.opacity(DesignTokens.Opacity.soft),
        foregroundColor: Color = .appAccent
    ) {
        self.isLoading = isLoading
        self.message = message
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    public var body: some View {
        if isLoading {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(message ?? AppFeedbackL10n.loading)

                VStack(spacing: DesignTokens.Spacing.standardPadding) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foregroundColor)
                        .scaleEffect(1.4)

                    if let message = message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(Color.theme.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(DesignTokens.Spacing.large)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius))
            }
        }
    }
}