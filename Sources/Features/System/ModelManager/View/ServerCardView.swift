//
//  ServerCardView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 模型服务器卡片组件
//  核心职责：提供单个远端/本地模型服务器配置卡片视图（ServerCardView）与健康状态指示器，
//           展示连通状态、延迟信息与快捷操作按钮。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 服务器卡片组件

/// 单个服务器配置卡片视图，展示状态、延迟等细节信息并提供快捷测试及配置动作
struct ServerCardView: View {
    /// 绑定的服务器配置数据
    let server: MockServerConfig

    /// 测试连通性动作
    let onTestConnection: () -> Void

    /// 编辑服务器配置动作
    let onEdit: () -> Void

    /// 删除服务器动作
    let onDelete: () -> Void

    /// 设置默认服务器动作
    let onSetDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack {
                statusIndicator(for: server)

                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
                    Text(server.name)
                        .font(.headline)
                        .foregroundStyle(.appText)

                    Text(server.baseURL)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if server.isDefault {
                    Image(systemName: DesignTokens.Icons.pinFill)
                        .foregroundStyle(Color.theme.orange)
                        .font(.caption)
                }
            }

            if let lastTested = server.lastTestedAt, let latency = server.latencyMs {
                HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                    Text(L10n.ModelManager.Server.lastTested(formatDate(lastTested)))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)

                    Text(FeatureConstants.Decorator.middleDot)
                        .foregroundStyle(.appSecondary)

                    Text(L10n.ModelManager.Server.latencyMs(latency))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
            }

            Divider()

            HStack(spacing: DesignTokens.Spacing.medium) {
                Button(action: onTestConnection) {
                    Text(L10n.ModelManager.Server.testConnection)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appAccent)
                }

                Button(action: onEdit) {
                    Text(L10n.ModelManager.Server.editAction)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appAccent)
                }

                Button(action: onDelete) {
                    Text(L10n.ModelManager.Server.deleteAction)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.theme.red)
                }

                Spacer()

                if !server.isDefault {
                    Button(action: onSetDefault) {
                        Text(L10n.ModelManager.Server.setDefaultAction)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.theme.orange)
                    }
                }
            }
        }
        .cardStyle(horizontalPadding: DesignTokens.Spacing.standardPadding, verticalPadding: DesignTokens.Spacing.standardPadding, backgroundOpacity: DesignTokens.Opacity.solid)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius)
                .stroke(server.isDefault ? Color.appAccent : Color.appBorder.opacity(DesignTokens.Opacity.shadow), lineWidth: server.isDefault ? 2 : 1)
        )
    }

    private func statusIndicator(for server: MockServerConfig) -> some View {
        serverStatusIndicator(isHealthy: server.isHealthy)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// 服务器健康状态指示器，消除 ServerConfigView 与 ServerCardView 的重复
func serverStatusIndicator(isHealthy: Bool) -> some View {
    Circle()
        .fill(isHealthy ? Color.theme.green : Color.theme.red)
        .frame(width: DesignTokens.Spacing.medium, height: DesignTokens.Spacing.medium)
}
