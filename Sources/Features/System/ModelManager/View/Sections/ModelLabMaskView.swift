//
//  ModelLabMaskView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：无可用本地模型时的毛玻璃引导遮罩视图，展示提示文案与跳转模型商店入口按钮。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 引导与拦截遮罩

extension ModelLabView {

    var noModelMaskView: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.flaskFill)
                .font(.system(size: DesignTokens.ComponentSpacing.iconDisplay))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.theme.purple, Color.theme.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, DesignTokens.Spacing.tiny)

            Text(L10n.ModelManager.Lab.noActiveModelTitle)
                .font(.headline)
                .foregroundStyle(Color.theme.text)

            Text(L10n.ModelManager.Lab.noActiveModelSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.medium)

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onGoToStore()
            }) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    Image(systemName: DesignTokens.Icons.stackFill)
                    Text(L10n.ModelManager.storeTitle)
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.vertical, DesignTokens.Spacing.small)
                .background(Color.appAccent)
                .clipShape(Capsule())
            }
            .padding(.top, DesignTokens.Spacing.small)
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(DesignTokens.Spacing.largeRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.largeRadius)
                .stroke(Color.theme.white.opacity(DesignTokens.Opacity.glass), lineWidth: DesignTokens.SystemStroke.divider)
        )
        .padding(.vertical, DesignTokens.Spacing.medium)
    }
}
