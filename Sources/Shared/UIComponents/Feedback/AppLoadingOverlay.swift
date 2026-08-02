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

// MARK: - Loading Button Style
/// 内嵌在按钮中的 Loading 指示器修饰符。
/// 按钮加载状态修饰符
/// 负责在普通按钮中嵌入进度指示器，并自动处理禁用状态与文字切换逻辑
struct LoadingButtonModifier: ViewModifier {
    let isLoading: Bool
    let loadingText: String?
    let normalText: String
    let icon: String?

    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    HStack(spacing: DesignSystem.tightPadding) {
                        ProgressView()
                            .tint(Color.theme.white)
                            .scaleEffect(0.8)
                        if let loadingText = loadingText {
                            Text(loadingText)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.theme.white)
                }
            }
    }
}

extension View {
    /// 在按钮内显示 Loading 状态，替代按钮文字。
    func loadingOverlay(
        isLoading: Bool,
        loadingText: String? = nil,
        normalText: String,
        icon: String? = nil
    ) -> some View {
        self.modifier(LoadingButtonModifier(
            isLoading: isLoading,
            loadingText: loadingText,
            normalText: normalText,
            icon: icon
        ))
    }
}

// MARK: - Inline Progress Row
/// 行内加载指示器（用于 List 或 HStack 中的单行加载状态）。
/// 行内进度指示器组件
/// 负责在列表行或表单单元中展示轻量级的加载状态，不干扰全局交互
struct AppInlineProgress: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.appAccent)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)

            Spacer()
        }
        .padding(.vertical, DesignSystem.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
