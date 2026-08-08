//
//  VaultBadge.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPCore

/// 笔记本标识与快速切换组件
/// 采用平台感知的交互模式：
/// - 指针/触控设备：显示下拉菜单 (Menu)
/// - 旋钮/紧凑设备：显示纯展示标签 (Label)
struct VaultBadge: View {
    @Environment(VaultService.self) var vaultService
    @Inject var platformEnv: any AppEnvironmentProtocol // 使用 DI 注入平台环境能力集
    @EnvironmentObject var themeManager: ThemeManager

    /// UI 测试模式下使用直通 Button 替代 Menu（XCUITest 对 SwiftUI Menu 交互不可靠）
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }
    
    var body: some View {
        if let currentVault = vaultService.currentVault {
            adaptiveContainer(currentVault: currentVault)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func adaptiveContainer(currentVault: Vault) -> some View {
        #if os(watchOS)
        // watchOS 降级处理：仅显示标签，不支持下拉菜单
        badgeLabel(currentVault: currentVault)
        #else
        // 具有指针/触控能力的设备使用 Menu
        // UI 测试模式：附加一个透明直通按钮绕过 SwiftUI Menu（XCUITest 对 Menu 交互不可靠）
        if isUITesting {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    vaultService.exitVault()
                }
            } label: {
                badgeLabel(currentVault: currentVault)
            }
            .buttonStyle(.plain)
            .tint(.primary)
            .accessibilityLabel("\(L10n.Vault.label): \(currentVault.name)")
            .accessibilityIdentifier("vaultBadgeButton")
        } else {
            Menu {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        vaultService.exitVault()
                    }
                }) {
                    Label(L10n.Vault.backToHub, systemImage: DesignSystem.Icons.backToHub)
                }
                .accessibilityIdentifier("vaultBackToHubButton")
            } label: {
                badgeLabel(currentVault: currentVault)
            }
            .buttonStyle(.plain)
            .tint(.primary)
            .accessibilityLabel("\(L10n.Vault.label): \(currentVault.name)")
            .accessibilityIdentifier("vaultBadgeButton")
        }
        #endif
    }
    
    @ViewBuilder
    private func badgeLabel(currentVault _: any VaultProtocol) -> some View {
        HStack(spacing: DesignSystem.tiny) {
            Image(systemName: DesignSystem.Icons.booksVerticalFill)
                .imageScale(.small)
                .foregroundStyle(.primary)

            Text(vaultService.currentVault?.name ?? L10n.Vault.defaultName)
                .font(.system(size: DesignSystem.bodyFontSize, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: DesignSystem.Gallery.cardMinWidth)

            if platformEnv.interactionStyle != InteractionStyle.crown {
                Image(systemName: DesignSystem.Icons.chevronUpDown)
                    .imageScale(.small)
                    .foregroundStyle(.primary.opacity(DesignSystem.Opacity.disabled))
            }
        }
        .padding(.vertical, DesignSystem.tightPadding)
        .foregroundStyle(.primary)
    }
}
