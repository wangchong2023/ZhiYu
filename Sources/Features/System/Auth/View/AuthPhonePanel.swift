//
//  AuthPhonePanel.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：中国大陆手机号一键登录面板 — 掩码展示、操作按钮与用户协议勾选。
//
import SwiftUI
import UFPCore

/// 国内手机号一键登录面板
struct AuthPhonePanel: View {
    @Binding var isLoading: Bool
    @Binding var isAgreementChecked: Bool
    @Binding var showPrivacySheet: Bool
    @Binding var showTermsSheet: Bool
    var handleAuth: () -> Void
    @Environment(AuthService.self) var authService

    var body: some View {
        VStack(spacing: Spacing.large) {
            // 手机号掩码显示
            Text(authService.currentUser?.phone?.maskedPhoneNumber ?? "180****6625")
                .font(.system(size: SystemFontSize.hero, weight: .bold, design: .rounded))
                .foregroundStyle(.appText)
                .padding(.top, Spacing.medium)

            // 登录动作按钮
            actionButton

            // 协议勾选
            agreementSection

            Spacer().frame(height: Spacing.large)
        }
        .padding(Spacing.wide)
        .appContainer(cornerRadius: Spacing.largeRadius)
    }

    private var actionButton: some View {
        Button(action: handleAuth) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(L10n.Auth.oneClickLogin)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Domain.Auth.actionButtonVerticalPadding)
            .background(Color.appAccent)
            .clipShape(Capsule())
            .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: Spacing.shadowRadius, y: Spacing.shadowY)
        }
        .disabled(isLoading)
        .accessibilityIdentifier("oneClickLoginButton")
    }

    private var agreementSection: some View {
        AgreementCheckboxView(
            isAgreementChecked: $isAgreementChecked,
            showTermsSheet: $showTermsSheet,
            showPrivacySheet: $showPrivacySheet
        )
    }
}
