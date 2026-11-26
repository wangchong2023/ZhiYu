//
//  AuthOAuthPanel.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：第三方 OAuth 登录面板 — Apple/Google/GitHub 图标按钮组与分隔线装饰。
//
import SwiftUI
import Dependencies
import UFPCore
import UFPDesignSystem

/// 第三方 OAuth 登录面板
struct AuthOAuthPanel: View {
    @Environment(AuthService.self) var authService
    @Environment(\.interfaceIdiom) private var idiom
    @Binding var isLoading: Bool
    @Binding var isAgreementChecked: Bool
    @Binding var errorMessage: String?
    var handleThirdPartyLogin: (any AuthStrategy) -> Void

    var body: some View {
        let isDesktop = AuthView.isDesktopLayout(idiom)
        VStack(spacing: isDesktop ? DesignTokens.Spacing.wide : DesignTokens.Spacing.large) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Rectangle()
                    .fill(Color.appBorder.opacity(DesignTokens.Opacity.soft))
                    .frame(height: DesignTokens.Spacing.borderWidth)
                Text(L10n.Auth.moreLoginMethods)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, DesignTokens.Spacing.tiny)
                Rectangle()
                    .fill(Color.appBorder.opacity(DesignTokens.Opacity.soft))
                    .frame(height: DesignTokens.Spacing.borderWidth)
            }

            HStack(spacing: isDesktop ? DesignTokens.Spacing.medium : DesignTokens.Spacing.large) {
                ThirdPartyIconButton(
                    id: FeatureConstants.OAuthProviderId.apple,
                    label: FeatureConstants.OAuthProviderName.apple,
                    icon: DesignTokens.Icons.appleLogo,
                    isSystem: true,
                    color: .primary,
                    isDesktopStyle: isDesktop
                ) {
                    handleThirdPartyLogin(AppleAuthStrategy())
                }
                ThirdPartyIconButton(
                    id: FeatureConstants.OAuthProviderId.google,
                    label: FeatureConstants.OAuthProviderName.google,
                    icon: DesignTokens.Icons.googleLogo,
                    isSystem: false,
                    color: Color.theme.blue,
                    isDesktopStyle: isDesktop
                ) {
                    handleThirdPartyLogin(GoogleAuthStrategy())
                }
                ThirdPartyIconButton(
                    id: FeatureConstants.OAuthProviderId.github,
                    label: FeatureConstants.OAuthProviderName.github,
                    icon: DesignTokens.Icons.githubLogo,
                    isSystem: false,
                    color: .primary,
                    isDesktopStyle: isDesktop
                ) {
                    handleThirdPartyLogin(GitHubAuthStrategy())
                }
            }

            // 错误提示：errorMessage 被赋值时显示错误文本
            if let message = errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.theme.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: errorMessage)
    }
}

// MARK: - 辅助组件

/// 第三方登录图标按钮
struct ThirdPartyIconButton: View {
    let id: String
    let label: String
    let icon: String
    let isSystem: Bool
    let color: Color
    let isDesktopStyle: Bool
    let action: () -> Void
    @State private var isHovered = false

    init(
        id: String,
        label: String = "",
        icon: String,
        isSystem: Bool = true,
        color: Color,
        isDesktopStyle: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.isSystem = isSystem
        self.color = color
        self.isDesktopStyle = isDesktopStyle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if isDesktopStyle {
                let cardShape = RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius, style: .continuous)
                HStack(spacing: DesignTokens.Spacing.small) {
                    providerIcon
                    if !label.isEmpty {
                        Text(label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Spacing.Auth.thirdPartyIconContainerSize)
                .background(
                    cardShape
                        .fill(Color.theme.white.opacity(isHovered ? DesignTokens.Opacity.subtle : DesignTokens.Opacity.light))
                )
                .overlay(
                    cardShape
                        .strokeBorder(
                            Color.theme.white.opacity(isHovered ? DesignTokens.Opacity.shadow : DesignTokens.Opacity.glass),
                            lineWidth: DesignTokens.Spacing.borderWidth
                        )
                )
                .contentShape(cardShape)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.appCard)
                        .frame(width: DesignTokens.Spacing.Auth.thirdPartyIconContainerSize, height: DesignTokens.Spacing.Auth.thirdPartyIconContainerSize)
                        .shadow(color: .primary.opacity(DesignTokens.Opacity.ghost), radius: DesignTokens.Spacing.tiny, y: DesignTokens.Spacing.atomic)

                    providerIcon
                }
                .overlay(
                    Circle()
                        .stroke(color.opacity(DesignTokens.Opacity.soft), lineWidth: DesignTokens.Spacing.borderWidth)
                )
            }
        }
        .buttonStyle(.plain)
        .onHoverIfAvailable { hovering in
            isHovered = hovering
        }
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var providerIcon: some View {
        if isSystem {
            Image(systemName: icon)
                .font(.system(size: DesignTokens.Spacing.Auth.thirdPartyIconFontSize))
                .foregroundStyle(color)
        } else if icon == FeatureConstants.AssetName.githubLogo {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: DesignTokens.Spacing.Auth.thirdPartyIconFontSize, height: DesignTokens.Spacing.Auth.thirdPartyIconFontSize)
                .foregroundStyle(color)
        } else {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: DesignTokens.Spacing.Auth.thirdPartyIconFontSize, height: DesignTokens.Spacing.Auth.thirdPartyIconFontSize)
        }
    }
}
