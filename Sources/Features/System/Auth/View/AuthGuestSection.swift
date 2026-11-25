//
//  AuthGuestSection.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：游客模式入口 — 虚线边框按钮提供免登录快速体验通道。
//
import SwiftUI
import UFPCore
import UFPDesignSystem

/// 游客模式入口组件
struct AuthGuestSection: View {
    @Environment(AuthService.self) var authService
    @Environment(\.interfaceIdiom) private var idiom
    @State private var isHovered = false

    var body: some View {
        Button(action: { authService.continueAsGuest() }) {
            if AuthView.isDesktopLayout(idiom) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    Text(L10n.Auth.guestMode)
                        .font(.subheadline.weight(.medium))
                    Image(systemName: DesignTokens.Icons.arrowRight)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(isHovered ? .appAccent : .appSecondary)
                .padding(.vertical, DesignTokens.Spacing.small)
                .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                .background(
                    Capsule()
                        .fill(Color.theme.white.opacity(isHovered ? DesignTokens.Opacity.light : DesignTokens.Opacity.faint))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Color.appBorder.opacity(isHovered ? DesignTokens.Opacity.soft : DesignTokens.Opacity.medium),
                            lineWidth: DesignTokens.Spacing.borderWidth
                        )
                )
                .contentShape(Capsule())
            } else {
                Text(L10n.Auth.guestMode)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                    .padding(.vertical, DesignTokens.Spacing.standardPadding)
                    .padding(.horizontal, DesignTokens.Spacing.giant)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius)
                            .strokeBorder(style: StrokeStyle(lineWidth: DesignTokens.Spacing.borderWidth, dash: [DesignTokens.Spacing.tightPadding]))
                            .foregroundStyle(.appBorder)
                    )
            }
        }
        // macOS 默认 Button 样式会给自定义边框再套一层灰色 bezel，plain 样式保证外观干净统一。
        .buttonStyle(.plain)
        .onHoverIfAvailable { hovering in
            isHovered = hovering
        }
        .padding(.top, DesignTokens.Spacing.Auth.guestButtonTopPadding)
        .accessibilityIdentifier("guestButton")
    }
}
