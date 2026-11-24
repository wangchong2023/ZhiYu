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
import UFPDesignSystem

/// 国内手机号一键登录面板
struct AuthPhonePanel: View {
    @Binding var isLoading: Bool
    @Binding var isAgreementChecked: Bool
    @Binding var showPrivacySheet: Bool
    @Binding var showTermsSheet: Bool
    var handleAuth: () -> Void
    @Environment(AuthService.self) var authService
    @Environment(\.interfaceIdiom) private var idiom

    var body: some View {
        let isDesktop = AuthView.isDesktopLayout(idiom)
        Group {
            if isDesktop {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                        Text(authService.carrierMaskedPhone ?? authService.currentUser?.phone?.maskedPhoneNumber ?? L10n.Auth.login)
                            .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.appText)

                        Text(L10n.Auth.overseasSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.appSecondary)
                    }

                    actionButton

                    agreementSection
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.large) {
                    // 手机号掩码显示：优先展示运营商 SDK 预取的掩码号，已登录后回退到 currentUser.phone
                    Text(authService.carrierMaskedPhone ?? authService.currentUser?.phone?.maskedPhoneNumber ?? L10n.Auth.phonePlaceholder)
                        .authHeroTextStyle()

                    // 登录动作按钮
                    actionButton

                    Spacer().frame(height: DesignTokens.Spacing.large)

                    // 协议勾选（靠近卡片底部）
                    agreementSection
                }
                .padding(DesignTokens.Spacing.wide)
                .appContainer(cornerRadius: DesignTokens.Spacing.largeRadius)
            }
        }
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
            .authActionButtonStyle()
        }
        // macOS 默认 Button 样式会在自定义胶囊背景外再套一层系统 bezel，
        // 使用 plain 样式让 label 自绘的胶囊成为唯一可见外观。
        .buttonStyle(.plain)
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
