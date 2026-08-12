//
//  PluginDetailActionsSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：插件详情页操作按钮区，包含安装/卸载切换按钮（带加载进度态）与系统分享链接入口。
//

import SwiftUI
import Dependencies

// MARK: - 操作按钮

extension PluginDetailView {

    var actionButtons: some View {
        HStack(spacing: DesignSystem.small) {
            // 安装 / 卸载
            Button(action: {
                if isInstalled {
                    // 解析出沙盒加载的真实 ID（例如 com.zhiyu.plugin.local.toc-generator）以便成功物理注销
                    let targetID = registry.plugins.first(where: {
                        $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id)
                    })?.manifest.id ?? plugin.id
                    registry.unloadPlugin(id: targetID)
                    HapticFeedback.shared.trigger(.success)
                } else {
                    HapticFeedback.shared.trigger(.selection)
                    isInstalling = true
                    Task {
                        _ = await marketService.downloadPlugin(plugin)
                        isInstalling = false
                    }
                }
            }) {
                HStack(spacing: DesignSystem.tiny) {
                    if isInstalling || marketService.downloadingPluginID == plugin.id {
                        ProgressView().scaleEffect(DesignSystem.iconSmall / DesignSystem.largeIconSize)
                    } else {
                        Image(systemName: isInstalled ? "trash" : "icloud.and.arrow.down")
                    }
                    Text(isInstalled ? L10n.Plugin.Action.uninstall : L10n.Plugin.Action.install)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, DesignSystem.standardPadding)
                .padding(.vertical, DesignSystem.small)
            }
            .buttonStyle(.borderedProminent)
            .tint(isInstalled ? .red : .appAccent)
            .disabled(isInstalling || marketService.downloadingPluginID == plugin.id)

            // 分享
            ShareLink(item: "\(plugin.name) — v\(plugin.version)\n\(plugin.description)") {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
    }
}
