//
//  PluginDetailPermissionsSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：插件详情页权限声明区，展示插件所需权限列表（含图标、标题与详细说明），
//  以及无权限时的安全认证占位状态。同时提供权限图标与颜色的映射辅助方法。
//

import SwiftUI

// MARK: - 权限声明

extension PluginDetailView {

    var permissionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: DesignSystem.small) {
                Text(L10n.Plugin.section.permissions)
                    .font(.headline)
                    .foregroundStyle(.appText)

                if let perms = plugin.requiredPermissions, !perms.isEmpty {
                    Text("\(perms.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignSystem.small)
                        .padding(.vertical, DesignSystem.atomic)
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                        .clipShape(Capsule())
                }
            }

            if let perms = plugin.requiredPermissions, !perms.isEmpty {
                VStack(spacing: DesignSystem.small) {
                    ForEach(perms, id: \.self) { perm in
                        HStack(spacing: DesignSystem.medium) {
                            Image(systemName: permIcon(for: perm))
                                .foregroundStyle(permColor(for: perm))
                                .font(.subheadline)
                                .frame(width: DesignSystem.IconSize.small)

                            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                                Text(L10n.Plugin.permTitle(perm))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.appText)
                                Text(L10n.Plugin.permDesc(perm))
                                    .font(.caption)
                                    .foregroundStyle(.appSecondary)
                            }
                        }
                        .padding(DesignSystem.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
                        .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
                    }
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text(L10n.Plugin.perm.none)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                }
                .padding(DesignSystem.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
                .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
            }
        }
    }

    // MARK: - 权限辅助方法

    /// 权限图标
    func permIcon(for perm: String) -> String {
        switch perm {
        case "readContent": return "doc.text.magnifyingglass"
        case "writeContent": return "square.and.pencil"
        case "network": return "globe"
        case "aiAccess": return "brain.head.profile"
        case "log": return "list.bullet.clipboard"
        default: return "key.fill"
        }
    }

    /// 权限颜色
    func permColor(for perm: String) -> Color {
        switch perm {
        case "readContent": return .blue
        case "writeContent": return .orange
        case "network": return .purple
        case "aiAccess": return .pink
        case "log": return .gray
        default: return .appSecondary
        }
    }
}
