//
//  AppLoadingOverlay.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
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
        backgroundColor: Color = Color.theme.black.opacity(DesignSystem.Opacity.soft),
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
                    .accessibilityLabel(message ?? L10n.Common.loading)

                VStack(spacing: DesignSystem.standardPadding) {
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
                .padding(DesignSystem.large)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
            }
        }
    }
}
