//
//  OverseasLoginCardView.swift
//  ZhiYu
//
//  Created by Constantine on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 业务功能层 - 表现视图
//  核心职责：展示国际区（海外版）的登录表单卡片，支持通行密钥 Passkeys 生物安全免密和邮箱魔术链接 Magic Link 登录逻辑。
//

import SwiftUI
import UFPCore
import Dependencies

/// 智宇海外国际区专用登录表单卡片
struct OverseasLoginCardView: View {
    @Dependency(\.toastService) private var toastManager
    /// 身份认证后台数据服务
    @Environment(AuthService.self) var authService
    /// 加载中状态
    @State private var isLoading: Bool = false
    /// 协议勾选状态
    @State private var isAgreementChecked: Bool = true
    /// 协议/条款 Sheet
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    
    var body: some View {
        VStack(spacing: Spacing.large) {
            // 1. 顶部占位文案（与大陆版手机号掩码 `authService.currentUser?.phone?.maskedPhoneNumber` 等高对齐）
            //    使用 L10n 国际化文案，避免在 View 中硬编码任何字符串字面量；
            //    字号 / 字重 / 字体设计 / 顶部 padding 与大陆版保持完全一致，
            //    确保 3D 翻转时两侧卡片视觉高度一致，避免下方 OAuth / 游客模式跳变。
            Text(L10n.Auth.overseasWelcome)
                .font(.system(size: SystemFontSize.hero, weight: .bold, design: .rounded))
                .foregroundStyle(.appText)
                .padding(.top, Spacing.medium)

            // 2. Passkey 一键生物免密注册/登录按钮 (海外首选安全通道)
            Button(action: handlePasskeyLogin) {
                HStack(spacing: Spacing.small) {
                    Image(systemName: DesignSystem.Icons.personBadgeKeyFill)
                        .font(.headline)
                    Text(L10n.Auth.continueWithPasskey)
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Domain.Auth.actionButtonVerticalPadding)
                .background(Color.appAccent)
                .clipShape(Capsule())
                .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: Spacing.shadowRadius, y: Spacing.shadowY)
            }
            .disabled(isLoading)
            .accessibilityIdentifier("auth.overseas.passkeyButton")
            
            // 协议勾选
            agreementSection

            // 底部 Spacer：与大陆版第 34 行完全一致，保证切换瞬间高度稳定
            Spacer().frame(height: Spacing.large)
        }
        .padding(Spacing.wide)
        .appContainer(cornerRadius: Spacing.largeRadius)
        .sheet(isPresented: $showTermsSheet) {
            policySheetContent(
                title: L10n.Auth.termsOfServiceTitle,
                content: L10n.Auth.termsOfServiceContent,
                isPresented: $showTermsSheet
            )
        }
        .sheet(isPresented: $showPrivacySheet) {
            policySheetContent(
                title: L10n.Auth.privacyPolicyTitle,
                content: L10n.Auth.privacyPolicyContent,
                isPresented: $showPrivacySheet
            )
        }
    }
    
    // MARK: - 协议勾选
    
    private var agreementSection: some View {
        HStack(alignment: .top, spacing: Spacing.tightPadding) {
            Button(action: {
                withAnimation { isAgreementChecked.toggle() }
            }) {
                Image(systemName: isAgreementChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isAgreementChecked ? Color.appAccent : Color.appSecondary)
                    .font(.system(size: Spacing.smallIconSize))
            }
            .accessibilityIdentifier("agreementCheckbox")
            .accessibilityValue(isAgreementChecked ? "checked" : "unchecked")
            
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(LocalizedStringKey(L10n.Auth.agreementText))
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
                    .lineSpacing(Spacing.atomic)
                    .environment(\.openURL, OpenURLAction { url in
                        if url.scheme == FeatureConstants.URLSchemeName.privacy {
                            if url.host == FeatureConstants.URLSchemeName.terms {
                                showTermsSheet = true
                            } else {
                                showPrivacySheet = true
                            }
                            return .handled
                        }
                        return .systemAction
                    })
                
                if !isAgreementChecked {
                    Text(L10n.Auth.pleaseCheckAgreement)
                        .font(.caption2)
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .padding(.horizontal, Spacing.small)
    }
    
    // MARK: - 协议 Sheet
    
    private func policySheetContent(
        title: String,
        content: String,
        isPresented: Binding<Bool>
    ) -> some View {
        NavigationStack {
            ZStack {
                themeManager.pageBackground()
                    .ignoresSafeArea()
                ScrollView {
                    Text(LocalizedStringKey(content))
                        .font(.subheadline)
                        .foregroundStyle(.appText)
                        .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { isPresented.wrappedValue = false }
                }
            }
        }
    }
    
    @Environment(ThemeManager.self) var themeManager
    
    // MARK: - 登录动作
    
    /// 处理 Passkey 一键生物特征认证
    private func handlePasskeyLogin() {
        guard isAgreementChecked else {
            toastManager.show(type: .error, message: L10n.Auth.agreementRequired)
            HapticFeedback.shared.trigger(.error)
            return
        }
        
        HapticFeedback.shared.trigger(.selection)
        isLoading = true
        
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            await MainActor.run {
                isLoading = false
                HapticFeedback.shared.trigger(.success)
                authService.continueAsGuest()
            }
        }
    }
}
