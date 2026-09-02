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

    /// 规整后的插件权限清单，提供稳定的非空数组语义
    var permissionsList: [String] {
        plugin.requiredPermissions ?? []
    }

    var permissionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: DesignSystem.small) {
                Text(L10n.Plugin.section.permissions)
                    .font(.headline)
                    .foregroundStyle(.appText)

                if !permissionsList.isEmpty {
                    AppSubtlePill(text: "\(permissionsList.count)")
                }
            }

            if !permissionsList.isEmpty {
                VStack(spacing: DesignSystem.small) {
                    ForEach(permissionsList, id: \.self) { perm in
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
                    Image(systemName: DesignSystem.Icons.checkmarkShieldFill)
                        .foregroundStyle(Color.theme.green)
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

    /// 权限图标（静态复用）
    static func permIcon(for perm: String) -> String {
        switch perm {
        case FeatureConstants.PermissionName.readContent: return DesignSystem.Icons.docMagnify
        case FeatureConstants.PermissionName.writeContent: return DesignSystem.Icons.squareAndPencil
        case FeatureConstants.PermissionName.network: return DesignSystem.Icons.globe
        case FeatureConstants.PermissionName.aiAccess: return DesignSystem.Icons.brainProfile
        case FeatureConstants.PermissionName.log: return DesignSystem.Icons.listBulletClipboard
        default: return DesignSystem.Icons.keyFill
        }
    }

    /// 权限图标（实例快捷方式）
    func permIcon(for perm: String) -> String {
        Self.permIcon(for: perm)
    }

    /// 权限颜色
    func permColor(for perm: String) -> Color {
        switch perm {
        case FeatureConstants.PermissionName.readContent: return Color.theme.blue
        case FeatureConstants.PermissionName.writeContent: return Color.theme.orange
        case FeatureConstants.PermissionName.network: return Color.theme.purple
        case FeatureConstants.PermissionName.aiAccess: return Color.theme.pink
        case FeatureConstants.PermissionName.log: return Color.theme.gray
        default: return .appSecondary
        }
    }
}
