//
//  PluginDetailMetadataSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：插件详情页底栏元数据面板（参照 VS Code 扩展详情页），以图标-标签-值行形式
//  展示版本、作者、最低应用版本、分类与商业化许可信息。
//

import SwiftUI

// MARK: - 元数据面板（参照 VS Code 扩展详情页）

extension PluginDetailView {

    var metadataSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Text(L10n.Plugin.Detail.metadataTitle)
                .font(.headline)
                .foregroundStyle(.appText)

            VStack(spacing: 0) {
                // 版本
                metadataRow(
                    icon: "number",
                    label: L10n.Plugin.Detail.version,
                    value: displayVersion
                )

                Divider().padding(.leading, ComponentSpacing.ultra)

                // 作者
                metadataRow(
                    icon: "person.fill",
                    label: L10n.Plugin.Detail.author,
                    value: plugin.author
                )

                Divider().padding(.leading, ComponentSpacing.ultra)

                // 最低应用版本
                if let minVersion = plugin.minAppVersion {
                    metadataRow(
                        icon: "app.badge.checkmark",
                        label: L10n.Plugin.Detail.minAppVersion,
                        value: minVersion
                    )
                    Divider().padding(.leading, ComponentSpacing.ultra)
                }

                // 分类
                metadataRow(
                    icon: "folder.fill",
                    label: L10n.Plugin.Detail.category,
                    value: categoryName
                )

                Divider().padding(.leading, ComponentSpacing.ultra)

                // 许可
                metadataRow(
                    icon: "checkmark.seal.fill",
                    label: L10n.Plugin.Detail.license,
                    value: monetizationLabel
                )
            }
            .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card))
        }
    }

    /// 单行元数据
    func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.IconSize.small, alignment: .center)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, DesignSystem.small + 2)
    }

    // MARK: - 辅助计算属性

    /// 分类名称（从插件元数据获取）
    var categoryName: String {
        return plugin.category ?? L10n.Plugin.Detail.categoryCommunity
    }

    /// 商业化模式标签
    var monetizationLabel: String {
        guard let model = plugin.monetization?.model else {
            return L10n.Plugin.Detail.licenseFree
        }
        switch model {
        case .free:
            return L10n.Plugin.Detail.licenseFree
        case .donation:
            return L10n.Plugin.Detail.licenseDonation
        case .subscription:
            return L10n.Plugin.Detail.licenseSubscription
        }
    }
}
