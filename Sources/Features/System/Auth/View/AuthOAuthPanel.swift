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
import UFPDesignSystem

/// 第三方 OAuth 登录面板
struct AuthOAuthPanel: View {
    @Environment(AuthService.self) var authService
    @Binding var isLoading: Bool
    @Binding var isAgreementChecked: Bool
    @Binding var errorMessage: String?
    var handleThirdPartyLogin: (any AuthStrategy) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            HStack {
                Rectangle().fill(Color.appBorder.opacity(DesignTokens.Opacity.shadow)).frame(height: DesignTokens.Spacing.borderWidth)
                Text(L10n.Auth.moreLoginMethods)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, DesignTokens.Spacing.small)
                Rectangle().fill(Color.appBorder.opacity(DesignTokens.Opacity.shadow)).frame(height: DesignTokens.Spacing.borderWidth)
            }

            HStack(spacing: DesignTokens.Spacing.large) {
                ThirdPartyIconButton(id: FeatureConstants.OAuthProviderId.apple, icon: DesignTokens.Icons.appleLogo, isSystem: true, color: .primary) {
                    handleThirdPartyLogin(AppleAuthStrategy())
                }
                ThirdPartyIconButton(id: FeatureConstants.OAuthProviderId.google, icon: DesignTokens.Icons.googleLogo, isSystem: false, color: Color.theme.blue) {
                    handleThirdPartyLogin(GoogleAuthStrategy())
                }
                ThirdPartyIconButton(id: FeatureConstants.OAuthProviderId.github, icon: DesignTokens.Icons.githubLogo, isSystem: false, color: .primary) {
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
    let icon: String
    let isSystem: Bool
    let color: Color
    let action: () -> Void

    init(id: String, icon: String, isSystem: Bool = true, color: Color, action: @escaping () -> Void) {
        self.id = id
        self.icon = icon
        self.isSystem = isSystem
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.appCard)
                    .frame(width: DesignTokens.Spacing.Auth.thirdPartyIconContainerSize, height: DesignTokens.Spacing.Auth.thirdPartyIconContainerSize)
                    .shadow(color: .primary.opacity(DesignTokens.Opacity.ghost), radius: DesignTokens.Spacing.tiny, y: DesignTokens.Spacing.atomic)

                if isSystem {
                    Image(systemName: icon)
                        .font(.system(size: DesignTokens.Spacing.Auth.thirdPartyIconFontSize))
                        .foregroundStyle(color)
                } else {
                    if icon == FeatureConstants.AssetName.githubLogo {
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
            .overlay(
                Circle()
                    .stroke(color.opacity(DesignTokens.Opacity.soft), lineWidth: DesignTokens.Spacing.borderWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
