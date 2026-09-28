//
//  LocalPluginDetailView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：展示已安装本地插件的详细信息（manifest 数据 + 卸载操作）。

import SwiftUI
import UFPCore
import Dependencies
import UFPDesignSystem

/// 本地已安装插件详情页（基于 PluginManifest，无需网络）
@MainActor
struct LocalPluginDetailView: View {
    let manifest: PluginManifest

    @Environment(\.dismiss) private var dismiss
    @Dependency(\.pluginRegistry) var registry
    @State private var showUninstallConfirm = false
    @State private var localIcon: UIImage?
    @State private var localReadme: String?

    private var isInstalled: Bool {
        registry.plugins.contains(where: { $0.manifest.id == manifest.id })
    }

    /// 根据插件 ID 智能映射默认 SF Symbol 兜底图标，防止在未解压或无本地物理图片时各插件展示单一的拼图块
    private var fallbackIcon: String {
        PluginIconResolver.localIconName(for: manifest.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.giant) {

                // MARK: - 头部
                HStack(spacing: DesignTokens.Spacing.wide) {
                    // 优先显示本地 icon.png，fallback SF Symbol
                    if let image = localIcon {
                        Image(uiImage: image)
                            .pluginLocalIconBase()
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.largeRadius))
                    } else {
                        Color.clear
                            .pluginFallbackIconStyle(iconName: fallbackIcon)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.giant))
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        Text(manifest.name)
                            .font(.title2.bold()).foregroundStyle(.appText)
                        Text(L10n.Plugin.Detail.byAuthor(manifest.author))
                            .font(.subheadline).foregroundStyle(.appSecondary)

                        HStack(spacing: DesignTokens.Spacing.small) {
                            Text("v\(manifest.version)")
                                .pluginVersionTagStyle()

                            if isInstalled {
                                Label(L10n.Plugin.Detail.installed, systemImage: DesignTokens.Icons.checkCircle)
                                    .font(.caption.weight(.medium)).foregroundStyle(Color.theme.green)
                            }
                        }
                    }
                }

                // MARK: - 操作
                Button(role: .destructive, action: {
                    registry.unloadPlugin(id: manifest.id)
                    dismiss()
                }) {
                    Label(L10n.Plugin.Action.uninstall, systemImage: DesignTokens.Icons.delete)
                        .font(.headline).frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.small)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.theme.red)

                Divider()

                // MARK: - 元数据
                PluginDetailSectionContainer(title: L10n.Plugin.Detail.metadataTitle) {
                    VStack(spacing: 0) {
                        detailRow(icon: "number", label: L10n.Plugin.Detail.version, value: manifest.version)
                        Divider().padding(.leading, DesignTokens.Spacing.medium)
                        detailRow(icon: DesignTokens.Icons.personFill, label: L10n.Plugin.Detail.author, value: manifest.author)
                        Divider().padding(.leading, DesignTokens.Spacing.medium)
                        detailRow(icon: DesignTokens.Icons.keyFill, label: L10n.Plugin.Detail.idLabel, value: manifest.id)
                    }
                    .background(Color.appCard.opacity(DesignTokens.Opacity.disabled))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.card))
                }

                Divider()

                // MARK: - 权限
                PluginDetailSectionContainer(title: L10n.Plugin.section.permissions) {
                    ForEach(manifest.permissions, id: \.self) { perm in
                        HStack(spacing: DesignTokens.Spacing.medium) {
                            Image(systemName: PluginDetailView.permIcon(for: perm)).foregroundStyle(.appAccent)
                            Text(L10n.Plugin.permTitle(perm)).font(.subheadline).foregroundStyle(.appText)
                        }
                        .permissionContainerStyle(cornerRadius: DesignTokens.SystemRadius.card)
                    }
                }

                // MARK: - 描述
                PluginDetailSectionContainer(title: L10n.Plugin.section.about) {
                    MarkdownRendererView(content: localReadme ?? manifest.description, isPrivate: false, onLinkTap: { _ in }, isCompact: true)
                }
            }
            .commonContentPadding(horizontal: DesignTokens.Spacing.standardPadding, vertical: DesignTokens.Spacing.standardPadding)
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .task {
            if let url = registry.iconURL(for: manifest.id), let data = try? Data(contentsOf: url) { localIcon = UIImage(data: data) }
            localReadme = registry.localizedReadme(for: manifest.id)
        }
        .navigationTitle(manifest.name)
        .appNavigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        PluginDetailRow(icon: icon, label: label, value: value)
    }
}
