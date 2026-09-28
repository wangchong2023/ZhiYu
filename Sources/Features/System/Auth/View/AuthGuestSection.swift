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
import UFPDesignSystem

/// 游客模式入口组件
struct AuthGuestSection: View {
    @Environment(AuthService.self) var authService

    var body: some View {
        Button(action: { authService.continueAsGuest() }) {
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
        .padding(.top, DesignSystem.Domain.Auth.guestButtonTopPadding)
        .accessibilityIdentifier("guestButton")
    }
}
