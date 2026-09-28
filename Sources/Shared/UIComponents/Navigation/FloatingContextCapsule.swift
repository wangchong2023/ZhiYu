//
//  FloatingContextCapsule.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

/// 方案 D 核心组件：悬浮上下文胶囊
/// 集成了侧边栏开关、当前笔记本标识及数据洞察入口
struct FloatingContextCapsule: View {
    @Environment(VaultService.self) var vaultService
    @Environment(ThemeManager.self) var themeManager
    
    var onToggleSidebar: (() -> Void)?
    var onShowInsights: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            // 1. 图 1 风格集成按钮：视图模式切换
            Button {
                HapticFeedback.shared.trigger(.selection)
                NotificationCenter.default.post(name: NSNotification.Name("toggleDisplayMode"), object: nil)
            } label: {
                Image(systemName: DesignTokens.Icons.line3Horizontal)
                    .font(.title3.weight(.medium))
                    .frame(width: DesignTokens.IconSize.xlarge, height: DesignTokens.IconSize.xlarge)
            }
            
            Divider()
                .frame(height: DesignTokens.IconSize.small)
                .background(.white.opacity(DesignTokens.Opacity.shadow))
            
            // 2. 语境标识 (Avenir Next 风格文字)
            if let currentVault = vaultService.currentVault {
                vaultMenu(currentVault)
            } else {
                hubIndicator
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.small)
        .accessibilityIdentifier("FloatingContextCapsule")
        .background(
            ZStack {
                // 方案 D：极高透明度的深色玻璃
                Capsule().fill(.black.opacity(DesignTokens.Opacity.disabled))
                Capsule().fill(.ultraThinMaterial)
            }
        )
        .overlay(
            // 方案 D 核心：绚丽的外发光描边
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(DesignTokens.Opacity.dim), .appAccent.opacity(DesignTokens.Opacity.disabled), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DesignTokens.SystemStroke.emphasis
                )
                .shadow(color: .appAccent.opacity(DesignTokens.Opacity.soft), radius: 8, x: 0, y: 0)
        )
        .clipShape(Capsule())
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(DesignTokens.Opacity.shadow), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func vaultMenu(_ vault: Vault) -> some View {
        #if os(watchOS)
        HStack(spacing: DesignTokens.Spacing.small) {
            Text(vault.name)
                .font(.custom("AvenirNext", size: 18).weight(.bold))
                .lineLimit(1)
        }
        .padding(.trailing, DesignTokens.Spacing.medium)
        .frame(minHeight: DesignTokens.Spacing.Action.buttonHeight)
        #else
        Menu {
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onShowInsights?()
            }) {
                Label(L10n.Dashboard.index.overview, systemImage: DesignTokens.Icons.comparison)
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                withAnimation(.spring(response: DesignTokens.Animation.springResponse, dampingFraction: DesignTokens.Animation.springDamping)) {
                    vaultService.exitVault()
                }
            }) {
                Label(L10n.Vault.backToHub, systemImage: DesignTokens.Icons.backToHub)
            }
            .accessibilityIdentifier("vaultBackToHubButton")
        } label: {
            capsuleLabel(text: vault.name)
        }
        #endif
    }
    
    private var hubIndicator: some View {
        capsuleLabel(text: L10n.Common.unknown) // 完美对齐图 1
    }

    /// 胶囊标签：Text + 下拉箭头（消除 vaultIndicator 与 hubIndicator 的重复 HStack 链）
    private func capsuleLabel(text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Text(text)
                .font(.title3.weight(.bold))
                .lineLimit(1)

            Image(systemName: DesignTokens.Icons.down)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(DesignTokens.Opacity.dim))
        }
        .padding(.trailing, DesignTokens.Spacing.medium)
        .frame(minHeight: DesignTokens.Spacing.Action.buttonHeight)
    }
}
