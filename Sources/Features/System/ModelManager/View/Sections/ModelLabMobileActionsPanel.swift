//
//  ModelLabMobileActionsPanel.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层
//  核心职责：提供端侧系统行为沙盒 (Mobile Actions) 的快捷指令胶囊栏与硬件执行状态看板
//

import SwiftUI
import UFPDesignSystem

/// 端侧系统行为沙盒控制面板
struct ModelLabMobileActionsPanel: View {
    @Binding var testPrompt: String
    @ObservedObject private var executor = MobileActionExecutor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // 预置系统快捷行为胶囊栏
            mobileQuickActionChips

            // 硬件行为沙盒状态看板
            mobileDeviceStatusBoard
        }
        .padding(.bottom, DesignTokens.SystemSpacing.element)
    }

    // MARK: - 快捷动作预置胶囊栏

    @ViewBuilder
    private var mobileQuickActionChips: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tight) {
            Text(L10n.ModelManager.Lab.Mobile.quickActionsTitle)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    mobileActionPresetButton(
                        title: L10n.ModelManager.Lab.Mobile.cmdTorchOn,
                        icon: DesignTokens.Icons.boltFill,
                        action: .torch(on: true)
                    )
                    mobileActionPresetButton(
                        title: L10n.ModelManager.Lab.Mobile.cmdTorchOff,
                        icon: DesignTokens.Icons.boltShieldFill,
                        action: .torch(on: false)
                    )
                    mobileActionPresetButton(
                        title: L10n.ModelManager.Lab.Mobile.cmdHaptic,
                        icon: DesignTokens.Icons.iphoneRadiowaves,
                        action: .haptic(pattern: .success)
                    )
                    mobileActionPresetButton(
                        title: L10n.ModelManager.Lab.Mobile.cmdNotify,
                        icon: DesignTokens.Icons.bell,
                        action: .localNotification(
                            title: FeatureConstants.MobileActionConstants.defaultNotificationTitle,
                            body: FeatureConstants.MobileActionConstants.defaultNotificationBody
                        )
                    )
                    mobileActionPresetButton(
                        title: L10n.ModelManager.Lab.Mobile.cmdDarkMode,
                        icon: DesignTokens.Icons.paintpalette,
                        action: .themeMode(isDark: true)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func mobileActionPresetButton(title: String, icon: String, action: MobileAction) -> some View {
        Button {
            HapticFeedback.shared.trigger(.selection)
            testPrompt = title
            Task {
                await MobileActionExecutor.shared.execute(action: action)
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.tiny) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
            .padding(.vertical, DesignTokens.Spacing.tiny)
            .background(Color.theme.blue.opacity(DesignTokens.Opacity.subtle))
            .cornerRadius(DesignTokens.SystemRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                    .stroke(Color.theme.blue.opacity(DesignTokens.Opacity.prominent), lineWidth: DesignTokens.SystemStroke.divider)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 设备行为与安全沙盒状态看板

    @ViewBuilder
    private var mobileDeviceStatusBoard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
            Text(L10n.ModelManager.Lab.Mobile.statusTitle)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: DesignTokens.Spacing.small) {
                // 手电筒状态指示卡片
                deviceStatusItem(
                    icon: DesignTokens.Icons.boltFill,
                    title: L10n.ModelManager.Lab.Mobile.torchState,
                    statusText: executor.isTorchOn ? L10n.ModelManager.Lab.Mobile.stateOn : L10n.ModelManager.Lab.Mobile.stateOff,
                    isActive: executor.isTorchOn
                )

                // 触感马达状态卡片
                deviceStatusItem(
                    icon: DesignTokens.Icons.iphoneRadiowaves,
                    title: L10n.ModelManager.Lab.Mobile.hapticState,
                    statusText: L10n.ModelManager.Lab.Mobile.stateReady,
                    isActive: true
                )

                // 本地通知状态卡片
                deviceStatusItem(
                    icon: DesignTokens.Icons.bell,
                    title: L10n.ModelManager.Lab.Mobile.notificationState,
                    statusText: L10n.ModelManager.Lab.Mobile.stateReady,
                    isActive: true
                )
            }
        }
        .padding(.top, DesignTokens.SystemSpacing.tiny)
    }

    @ViewBuilder
    private func deviceStatusItem(icon: String, title: String, statusText: String, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
            HStack {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(isActive ? Color.theme.green : .secondary)
                Spacer()
                Circle()
                    .fill(isActive ? Color.theme.green : Color.theme.gray)
                    .frame(width: DesignTokens.SystemSpacing.atomic, height: DesignTokens.SystemSpacing.atomic)
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(statusText)
                .font(.caption2.bold())
                .foregroundStyle(isActive ? Color.theme.green : .secondary)
        }
        .padding(DesignTokens.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .cornerRadius(DesignTokens.SystemRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                .stroke(Color.appBorder.opacity(DesignTokens.Opacity.subtle), lineWidth: DesignTokens.SystemStroke.divider)
        )
    }
}
