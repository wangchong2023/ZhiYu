//
//  PluginDetailHeaderSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：插件详情页头部信息区，渲染 Squircle 圆角图标（优先本地缓存）、插件名称、版本标签、
//  作者信息与安装状态徽章。
//

import SwiftUI
import UFPCore

// MARK: - 头部信息区

extension PluginDetailView {

    var headerSection: some View {
        HStack(alignment: .top, spacing: DesignSystem.wide) {
            // 插件大图标 — 优先显示已缓存的本地 icon.png，使用 App Store 经典的 Squircle 平滑圆角
            if let uiImage = localIcon {
                Image(uiImage: uiImage)
                    .pluginLocalIconBase()
                    .iconClipShadow(cornerRadius: SystemRadius.chip, strokeOpacity: SystemOpacity.glass)
            } else if let iconURL = URL(string: plugin.icon), iconURL.scheme?.hasPrefix(SystemConstants.URLScheme.httpLiteral) == true {
                PluginRemoteIconLoader(
                    iconURL: iconURL,
                    size: DesignSystem.Gallery.itemSize,
                    cornerRadius: SystemRadius.chip,
                    strokeOpacity: SystemOpacity.glass,
                    strokeColor: Color.appBorder,
                    emptyContent: {
                        AppSkeleton(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize, cornerRadius: SystemRadius.chip)
                            .overlay(ProgressView().controlSize(.small))
                    },
                    fallback: { fallbackPluginIcon }
                )
            } else {
                fallbackPluginIcon
                    .iconContainerStyle(cornerRadius: SystemRadius.chip, strokeOpacity: SystemOpacity.glass)
            }

            VStack(alignment: .leading, spacing: DesignSystem.small) {
                // 名称 + 版本标签
                HStack(spacing: DesignSystem.small) {
                    Text(plugin.name)
                        .font(.title2.bold())
                        .foregroundStyle(.appText)

                    // 版本号标签
                    Text("v\(displayVersion)")
                        .pluginVersionTagStyle()
                }

                // 作者
                Text(L10n.Plugin.Detail.byAuthor(plugin.author))
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)

                // 安装状态标签 (移至大字号区域下端，保持视觉重点清晰)
                if isInstalled {
                    HStack(spacing: DesignSystem.tiny) {
                        Image(systemName: DesignSystem.Icons.checkCircle)
                            .font(.caption)
                            .foregroundStyle(Color.theme.green)
                        Text(L10n.Plugin.Detail.installed)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.theme.green)
                    }
                    .padding(.top, DesignSystem.atomic)
                }
            }
        }
    }

    /// 远程图标加载失败时的 fallback 拼图块默认图标（带渐变底）
    private var fallbackPluginIcon: some View {
        Color.clear
            .pluginFallbackIconStyle(iconName: DesignSystem.Icons.puzzlepieceExtensionFill, gradientOpacity: SystemOpacity.textSecondary)
    }
}

/// 插件图标容器样式修饰符，消除重复的 frame+clipShape+overlay+shadow 链
private extension View {
    func iconContainerStyle(cornerRadius: CGFloat, strokeOpacity: Double) -> some View {
        self
            .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
            .iconClipShadow(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity)
    }

    /// 仅 clipShape+overlay+shadow，用于已包含 frame 的图标
    func iconClipShadow(cornerRadius: CGFloat, strokeOpacity: Double) -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Color.appBorder.opacity(strokeOpacity), lineWidth: SystemStroke.hairline))
            .shadow(color: Color.theme.black.opacity(DesignSystem.subtleOpacity), radius: 12, x: 0, y: 6)
    }
}
