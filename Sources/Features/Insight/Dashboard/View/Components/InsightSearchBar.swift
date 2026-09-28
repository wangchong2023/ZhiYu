//
//  InsightSearchBar.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用搜索栏组件，消除 KnowledgePageListView 与 TagCloudMainContent 中重复的
//  搜索图标 + TextField + 清除按钮 + borderedCardStyle 布局链。
//

import SwiftUI
import UFPDesignSystem

/// [L3] 表现层：Insight 模块通用搜索栏
///
/// 统一封装搜索图标、文本输入、清除按钮与卡片边框样式，
/// 通过 `placeholder` 与 `onClear` 回调解耦不同调用方的文案与行为。
struct InsightSearchBar: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)?
    var accessibilityIdentifier: String?
    var horizontalPadding: CGFloat = DesignTokens.Spacing.tiny
    var bottomPadding: CGFloat = DesignTokens.Spacing.tiny

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.search)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.appAccent)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.appText)
                .submitLabel(.search)
                .onSubmit {
                    if !text.isEmpty {
                        onSubmit?()
                    }
                }

            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSubmit?()
                }) {
                    ClearSearchButton()
                }
                .buttonStyle(.plain)
            }
        }
        .borderedCardStyle(
            horizontalPadding: DesignTokens.Spacing.standardPadding,
            verticalPadding: DesignTokens.SystemSpacing.elementLarge,
            backgroundOpacity: DesignTokens.Opacity.dim,
            cornerRadius: DesignTokens.Spacing.mediumRadius,
            borderWidth: DesignTokens.Spacing.borderWidth,
            borderColor: .appAccent,
            borderOpacity: DesignTokens.Opacity.medium
        )
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
    }
}
