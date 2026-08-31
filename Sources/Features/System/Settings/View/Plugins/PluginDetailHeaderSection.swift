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
                    .renderingMode(.original)
                    .resizable().scaledToFit()
                    .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                    .clipShape(RoundedRectangle(cornerRadius: SystemRadius.chip, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SystemRadius.chip, style: .continuous).stroke(Color.appBorder.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline))
                    .shadow(color: Color.theme.black.opacity(DesignSystem.subtleOpacity), radius: 12, x: 0, y: 6)
            } else if let iconURL = URL(string: plugin.icon), iconURL.scheme?.hasPrefix(SystemConstants.URLScheme.httpLiteral) == true {
                CachedAsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable().scaledToFit()
                    case .empty:
                        AppSkeleton(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize, cornerRadius: SystemRadius.chip)
                            .overlay(
                                ProgressView()
                                    .controlSize(.small)
                            )
                    case .failure:
                        // 远程图标拉取失败时，fallback 到带渐变底的拼图块默认图标
                        Image(systemName: DesignSystem.Icons.puzzlepieceExtensionFill)
                            .font(.system(size: DesignSystem.Gallery.mainIconSize * FeatureConstants.PluginDetailIconScale.main))
                            .foregroundStyle(.white)
                            .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                            .background(
                                LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(SystemOpacity.textSecondary)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    @unknown default:
                        Image(systemName: DesignSystem.Icons.puzzlepieceExtensionFill)
                            .font(.system(size: DesignSystem.Gallery.mainIconSize * FeatureConstants.PluginDetailIconScale.main))
                            .foregroundStyle(.white)
                            .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                            .background(
                                LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(SystemOpacity.textSecondary)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                .clipShape(RoundedRectangle(cornerRadius: SystemRadius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SystemRadius.chip, style: .continuous).stroke(Color.appBorder.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline))
                .shadow(color: Color.theme.black.opacity(DesignSystem.subtleOpacity), radius: 12, x: 0, y: 6)
            } else {
                Image(systemName: plugin.icon)
                    .font(.system(size: DesignSystem.Gallery.mainIconSize * FeatureConstants.PluginDetailIconScale.main))
                    .foregroundStyle(.white)
                    .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                    .background(
                        LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(SystemOpacity.textSecondary)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: SystemRadius.chip, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SystemRadius.chip, style: .continuous).stroke(Color.appBorder.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline))
                    .shadow(color: Color.theme.black.opacity(DesignSystem.subtleOpacity), radius: 12, x: 0, y: 6)
            }

            VStack(alignment: .leading, spacing: DesignSystem.small) {
                // 名称 + 版本标签
                HStack(spacing: DesignSystem.small) {
                    Text(plugin.name)
                        .font(.title2.bold())
                        .foregroundStyle(.appText)

                    // 版本号标签
                    Text("v\(displayVersion)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, DesignSystem.small)
                        .padding(.vertical, DesignSystem.tiny)
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                        .foregroundStyle(.appAccent)
                        .clipShape(Capsule())
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
}
