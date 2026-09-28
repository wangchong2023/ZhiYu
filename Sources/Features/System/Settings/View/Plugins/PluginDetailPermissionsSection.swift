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
import UFPDesignSystem

// MARK: - 权限声明

extension PluginDetailView {

    /// 规整后的插件权限清单，提供稳定的非空数组语义
    var permissionsList: [String] {
        plugin.requiredPermissions ?? []
    }

    var permissionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Text(L10n.Plugin.section.permissions)
                    .font(.headline)
                    .foregroundStyle(.appText)

                if !permissionsList.isEmpty {
                    AppSubtlePill(text: "\(permissionsList.count)")
                }
            }

            if !permissionsList.isEmpty {
                VStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(permissionsList, id: \.self) { perm in
                        HStack(spacing: DesignTokens.Spacing.medium) {
                            Image(systemName: permIcon(for: perm))
                                .foregroundStyle(permColor(for: perm))
                                .font(.subheadline)
                                .frame(width: DesignTokens.IconSize.small)

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                                Text(L10n.Plugin.permTitle(perm))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.appText)
                                Text(L10n.Plugin.permDesc(perm))
                                    .font(.caption)
                                    .foregroundStyle(.appSecondary)
                            }
                        }
                        .permissionContainerStyle()
                    }
                }
            } else {
                HStack {
                    Image(systemName: DesignTokens.Icons.checkmarkShieldFill)
                        .foregroundStyle(Color.theme.green)
                    Text(L10n.Plugin.perm.none)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                }
                .permissionContainerStyle()
            }
        }
    }

    // MARK: - 权限辅助方法

    /// 权限图标（静态复用）
    static func permIcon(for perm: String) -> String {
        switch perm {
        case FeatureConstants.PermissionName.readContent: return DesignTokens.Icons.docMagnify
        case FeatureConstants.PermissionName.writeContent: return DesignTokens.Icons.squareAndPencil
        case FeatureConstants.PermissionName.network: return DesignTokens.Icons.globe
        case FeatureConstants.PermissionName.aiAccess: return DesignTokens.Icons.brainProfile
        case FeatureConstants.PermissionName.log: return DesignTokens.Icons.listBulletClipboard
        default: return DesignTokens.Icons.keyFill
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

/// 权限容器样式修饰符，消除重复的 padding+frame+background+clipShape 链
extension View {
    func permissionContainerStyle(cornerRadius: CGFloat = DesignTokens.SystemRadius.small) -> some View {
        self
            .padding(DesignTokens.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard.opacity(DesignTokens.Opacity.disabled))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
