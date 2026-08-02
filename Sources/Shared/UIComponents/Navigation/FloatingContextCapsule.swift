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

/// 方案 D 核心组件：悬浮上下文胶囊
/// 集成了侧边栏开关、当前笔记本标识及数据洞察入口
struct FloatingContextCapsule: View {
    @Environment(VaultService.self) var vaultService
    @EnvironmentObject var themeManager: ThemeManager
    
    var onToggleSidebar: (() -> Void)?
    var onShowInsights: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            // 1. 图 1 风格集成按钮：视图模式切换
            Button {
                HapticFeedback.shared.trigger(.selection)
                NotificationCenter.default.post(name: NSNotification.Name("toggleDisplayMode"), object: nil)
            } label: {
                Image(systemName: DesignSystem.Icons.line3Horizontal)
                    .font(.title3.weight(.medium))
                    .frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)
            }
            
            Divider()
                .frame(height: DesignSystem.IconSize.small)
                .background(.white.opacity(DesignSystem.Opacity.shadow))
            
            // 2. 语境标识 (Avenir Next 风格文字)
            if let currentVault = vaultService.currentVault {
                vaultMenu(currentVault)
            } else {
                hubIndicator
            }
        }
        .padding(.horizontal, DesignSystem.small)
        .accessibilityIdentifier("FloatingContextCapsule")
        .background(
            ZStack {
                // 方案 D：极高透明度的深色玻璃
                Capsule().fill(.black.opacity(DesignSystem.Opacity.disabled))
                Capsule().fill(.ultraThinMaterial)
            }
        )
        .overlay(
            // 方案 D 核心：绚丽的外发光描边
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(DesignSystem.Opacity.dim), .appAccent.opacity(DesignSystem.Opacity.disabled), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .shadow(color: .appAccent.opacity(DesignSystem.Opacity.soft), radius: 8, x: 0, y: 0)
        )
        .clipShape(Capsule())
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(DesignSystem.Opacity.shadow), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func vaultMenu(_ vault: Vault) -> some View {
        #if os(watchOS)
        HStack(spacing: DesignSystem.small) {
            Text(vault.name)
                .font(.custom("AvenirNext", size: 18).weight(.bold))
                .lineLimit(1)
        }
        .padding(.trailing, DesignSystem.medium)
        .frame(minHeight: Spacing.Action.buttonHeight)
        #else
        Menu {
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onShowInsights?()
            }) {
                Label(L10n.Dashboard.index.overview, systemImage: DesignSystem.Icons.comparison)
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                withAnimation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping)) {
                    vaultService.exitVault()
                }
            }) {
                Label(L10n.Vault.backToHub, systemImage: DesignSystem.Icons.backToHub)
            }
            .accessibilityIdentifier("vaultBackToHubButton")
        } label: {
            HStack(spacing: DesignSystem.small) {
                Text(vault.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                
                Image(systemName: DesignSystem.Icons.down)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(DesignSystem.Opacity.dim))
            }
            .padding(.trailing, DesignSystem.medium)
            .frame(minHeight: Spacing.Action.buttonHeight)
        }
        #endif
    }
    
    private var hubIndicator: some View {
        HStack(spacing: DesignSystem.small) {
            Text(L10n.Common.unknown) // 完美对齐图 1
                .font(.title3.weight(.bold))
            
            Image(systemName: DesignSystem.Icons.down)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(DesignSystem.Opacity.dim))
        }
        .padding(.trailing, DesignSystem.medium)
        .frame(minHeight: Spacing.Action.buttonHeight)
    }
}
