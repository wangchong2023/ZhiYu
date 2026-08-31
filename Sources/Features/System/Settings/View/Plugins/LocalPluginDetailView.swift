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

    /// 根据插件 ID 智能映射默认 of SF Symbol 兜底图标，防止在未解压或无本地物理图片时各插件展示单一的拼图块
    private var fallbackIcon: String {
        let id = manifest.id
        if id.contains(PluginConstants.LocalIconKeyword.tocGenerator) {
            return "list.bullet.rectangle.portrait"
        } else if id.contains(PluginConstants.LocalIconKeyword.wordCounter) {
            return "character.textbox"
        } else if id.contains(PluginConstants.LocalIconKeyword.smartCleaner) {
            return "wand.and.stars"
        } else if id.contains(PluginConstants.LocalIconKeyword.aiSummary) {
            return "brain.head.profile"
        } else if id.contains(PluginConstants.LocalIconKeyword.codeHighlighter) {
            return "curlybraces"
        } else if id.contains(PluginConstants.LocalIconKeyword.linkPreview) {
            return "link"
        } else if id.contains(PluginConstants.LocalIconKeyword.aiTranslator) {
            return "translate"
        } else if id.contains(PluginConstants.LocalIconKeyword.markdownBeautifier) {
            return "doc.text.magnifyingglass"
        } else {
            return "puzzlepiece.extension.fill"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.giant) {

                // MARK: - 头部
                HStack(spacing: DesignSystem.wide) {
                    // 优先显示本地 icon.png，fallback SF Symbol
                    if let image = localIcon {
                        Image(uiImage: image)
                            .renderingMode(.original)
                            .resizable().scaledToFit()
                            .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.largeRadius))
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: DesignSystem.Gallery.mainIconSize * FeatureConstants.PluginDetailIconScale.main))
                            .foregroundStyle(.white)
                            .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                            .background(
                                LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(DesignSystem.Opacity.prominent)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.giant))
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.small) {
                        Text(manifest.name)
                            .font(.title2.bold()).foregroundStyle(.appText)
                        Text(L10n.Plugin.Detail.byAuthor(manifest.author))
                            .font(.subheadline).foregroundStyle(.appSecondary)

                        HStack(spacing: DesignSystem.small) {
                            Text("v\(manifest.version)")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, DesignSystem.small).padding(.vertical, DesignSystem.tiny)
                                .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle)).foregroundStyle(.appAccent)
                                .clipShape(Capsule())

                            if isInstalled {
                                Label(L10n.Plugin.Detail.installed, systemImage: DesignSystem.Icons.checkCircle)
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
                    Label(L10n.Plugin.Action.uninstall, systemImage: DesignSystem.Icons.delete)
                        .font(.headline).frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.small)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.theme.red)

                Divider()

                // MARK: - 元数据
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    Text(L10n.Plugin.Detail.metadataTitle).font(.headline).foregroundStyle(.appText)
                    VStack(spacing: 0) {
                        detailRow(icon: "number", label: L10n.Plugin.Detail.version, value: manifest.version)
                        Divider().padding(.leading, DesignSystem.medium)
                        detailRow(icon: DesignSystem.Icons.personFill, label: L10n.Plugin.Detail.author, value: manifest.author)
                        Divider().padding(.leading, DesignSystem.medium)
                        detailRow(icon: DesignSystem.Icons.keyFill, label: L10n.Plugin.Detail.idLabel, value: manifest.id)
                    }
                    .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
                    .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card))
                }

                Divider()

                // MARK: - 权限
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    Text(L10n.Plugin.section.permissions).font(.headline).foregroundStyle(.appText)
                    ForEach(manifest.permissions, id: \.self) { perm in
                        HStack(spacing: DesignSystem.medium) {
                            Image(systemName: permIcon(for: perm)).foregroundStyle(.appAccent)
                            Text(L10n.Plugin.permTitle(perm)).font(.subheadline).foregroundStyle(.appText)
                        }
                        .padding(DesignSystem.medium).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
                        .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card))
                    }
                }

                // MARK: - 描述
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    Text(L10n.Plugin.section.about).font(.headline).foregroundStyle(.appText)
                    MarkdownRendererView(content: localReadme ?? manifest.description, isPrivate: false, onLinkTap: { _ in }, isCompact: true)
                }
            }
            .padding()
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
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(.appAccent).frame(width: DesignSystem.IconSize.small)
            Text(label).font(.subheadline).foregroundStyle(.appSecondary).fixedSize(horizontal: true, vertical: false)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(.appText)
        }
        .padding(.horizontal, DesignSystem.medium).padding(.vertical, SystemSpacing.small)
    }

    private func permIcon(for perm: String) -> String {
        switch perm {
        case FeatureConstants.PermissionName.readContent: return DesignSystem.Icons.docMagnify
        case FeatureConstants.PermissionName.writeContent: return DesignSystem.Icons.squareAndPencil
        case FeatureConstants.PermissionName.network: return DesignSystem.Icons.globe
        case FeatureConstants.PermissionName.aiAccess: return DesignSystem.Icons.brainProfile
        case FeatureConstants.PermissionName.log: return DesignSystem.Icons.listBulletClipboard
        default: return DesignSystem.Icons.keyFill
        }
    }
}
