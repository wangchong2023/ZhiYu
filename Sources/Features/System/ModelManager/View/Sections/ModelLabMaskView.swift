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

// MARK: - 引导与拦截遮罩

extension ModelLabView {

    var noModelMaskView: some View {
        VStack(spacing: DesignSystem.medium) {
            Image(systemName: "flask.fill")
                .font(.system(size: ComponentSpacing.iconLarge + 10))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, DesignSystem.tiny)

            Text(L10n.ModelManager.Lab.noActiveModelTitle)
                .font(.headline)
                .foregroundStyle(Color.theme.text)

            Text(L10n.ModelManager.Lab.noActiveModelSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.medium)

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onGoToStore()
            }) {
                HStack(spacing: DesignSystem.small) {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text(L10n.ModelManager.storeTitle)
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.medium)
                .padding(.vertical, DesignSystem.small)
                .background(Color.appAccent)
                .clipShape(Capsule())
            }
            .padding(.top, DesignSystem.small)
        }
        .padding(DesignSystem.large)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(DesignSystem.largeRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                .stroke(Color.theme.white.opacity(DesignSystem.Opacity.glass), lineWidth: SystemStroke.divider)
        )
        .padding(.vertical, DesignSystem.medium)
    }
}
