//
//  SearchPanelSection.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：搜索输入栏通用组件（放大镜图标 + 文本框 + 清空按钮 + 发送胶囊按钮），供即时媒体检索与视频时刻检索面板复用。
//

import SwiftUI
import UFPDesignSystem

/// 搜索输入栏组件
/// 参数化搜索词绑定、占位文案、发送标题、强调色、发送禁用态与搜索/清空回调，供不同搜索面板复用。
@MainActor
struct SearchPanelSection: View {
    /// 搜索词绑定
    @Binding var query: String
    /// 文本框占位文案
    let placeholder: String
    /// 发送按钮文案
    let sendTitle: String
    /// 强调色（放大镜/发送按钮/发送胶囊底色）
    let accentColor: Color
    /// 发送按钮是否禁用（禁用时置灰不可点）
    let isSearchDisabled: Bool
    /// 搜索回调（提交与发送触发）
    let onSearch: () -> Void
    /// 清空回调（清空搜索词与结果）
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: DesignTokens.Icons.magnifyingglass)
                .foregroundStyle(accentColor)

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.theme.text)
                .onSubmit {
                    onSearch()
                }

            if !query.isEmpty {
                Button(action: {
                    onClear()
                }) {
                    Image(systemName: DesignTokens.Icons.xmarkCircle)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                onSearch()
            }) {
                Text(sendTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.theme.white)
                    .padding(.horizontal, DesignTokens.SystemSpacing.content)
                    .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSearchDisabled)
            .opacity(isSearchDisabled ? DesignTokens.Opacity.disabled : DesignTokens.Opacity.solid)
        }
        .padding(DesignTokens.Spacing.standardPadding)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .cornerRadius(DesignTokens.Spacing.mediumRadius)
    }
}
