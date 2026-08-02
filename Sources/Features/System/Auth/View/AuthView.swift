//
//  AuthView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Auth 界面容器 — 持有 @State 状态树、3D 翻转动画调度与认证逻辑编排。
//
import SwiftUI

/// 身份认证主视图
struct AuthView: View {
    @Environment(AuthService.self) var authService
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - 区域感知与3D翻转状态
    @State private var currentRegion: AuthRegion = AuthRegionDetector.shared.detectDefaultRegion()
    @State private var displayedRegion: AuthRegion = AuthRegionDetector.shared.detectDefaultRegion()
    @State private var rotateDegrees: Double = 0

    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isAgreementChecked: Bool = true
    @State private var showPrivacySheet: Bool = false
    @State private var showTermsSheet: Bool = false
    @State private var selectedLanguage: LanguageMode = Localized.languageMode

    var body: some View {
        ZStack {
            // 背景层
            themeManager.pageBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // 顶部控制条（区域选择与语言切换）
                topControlBar

                VStack(spacing: Spacing.huge) {
                    // 1. Logo & 标语 (品牌展示板块)
                    heroHeader

                    // 2. 卡片登录承载容器 (包含3D翻转动画)
                    Group {
                        if displayedRegion == .china {
                            AuthPhonePanel(
                                isLoading: $isLoading,
                                isAgreementChecked: $isAgreementChecked,
                                showPrivacySheet: $showPrivacySheet,
                                showTermsSheet: $showTermsSheet,
                                handleAuth: handleAuth
                            )
                        } else {
                            OverseasLoginCardView()
                                .id(Localized.currentLanguage)
                                .rotation3DEffect(.degrees(180), axis: (x: 0.0, y: 1.0, z: 0.0))
                        }
                    }
                    .rotation3DEffect(.degrees(rotateDegrees), axis: (x: 0.0, y: 1.0, z: 0.0))

                    // 3. 第三方 OAuth 面板
                    AuthOAuthPanel(
                        isLoading: $isLoading,
                        isAgreementChecked: $isAgreementChecked,
                        errorMessage: $errorMessage,
                        handleThirdPartyLogin: handleThirdPartyLogin
                    )

                    // 4. 游客模式
                    AuthGuestSection()
                }
                .padding(.horizontal, Spacing.wide)
                .padding(.vertical, Spacing.wide)
            }
        }
        .sheet(isPresented: $showPrivacySheet) {
            policySheetContent(
                title: L10n.Auth.privacyPolicyTitle,
                content: L10n.Auth.privacyPolicyContent,
                isPresented: $showPrivacySheet
            )
        }
        .sheet(isPresented: $showTermsSheet) {
            policySheetContent(
                title: L10n.Auth.termsOfServiceTitle,
                content: L10n.Auth.termsOfServiceContent,
                isPresented: $showTermsSheet
            )
        }
    }

    // MARK: - 子视图

    /// 系统语言与区域切换控制条
    private var topControlBar: some View {
        HStack {
            RegionSelectorToggle(currentRegion: $currentRegion) {
                triggerRegionFlip()
            }

            Spacer()

            languageSwitcher
        }
        .padding(.horizontal, Spacing.wide)
        .padding(.top, Spacing.tiny)
    }

    /// 触发 3D 卡片翻转动效
    private func triggerRegionFlip() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            rotateDegrees += 180
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            displayedRegion = currentRegion
        }
    }

    /// 系统语言切换按钮（右上角）
    private var languageSwitcher: some View {
        HStack {
            Spacer()
            Menu {
                Picker("", selection: Binding(
                    get: { selectedLanguage },
                    set: { mode in
                        selectedLanguage = mode
                        Localized.languageMode = mode
                    }
                )) {
                    ForEach(LanguageMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.subheadline)
                    Text(selectedLanguage.displayName)
                        .font(.caption)
                }
                .foregroundStyle(.appSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding(.trailing, Spacing.medium)
        .padding(.top, Spacing.tiny)
    }

    private var heroHeader: some View {
        VStack(spacing: Spacing.giant) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.appAccent.opacity(DesignSystem.Opacity.medium), .appConcept.opacity(DesignSystem.Opacity.subtle)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: DesignSystem.Domain.Auth.logoBackgroundSize, height: DesignSystem.Domain.Auth.logoBackgroundSize)
                    .blur(radius: Spacing.shadowRadius)

                Image(systemName: DesignSystem.Icons.knowledge)
                    .font(.system(size: DesignSystem.displayFontSize * 1.5))
                    .foregroundStyle(LinearGradient(colors: [.appAccent, .appConcept], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .appAccent.opacity(DesignSystem.Opacity.disabled), radius: Spacing.shadowRadius, y: Spacing.shadowY)
            }

            VStack(spacing: Spacing.small) {
                Text(L10n.Common.appName)
                    .font(.system(size: DesignSystem.titleFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(.appText)
                    .tracking(1)

                Text(L10n.Onboarding.subtitle)
                    .font(.system(size: DesignSystem.subheadlineFontSize, weight: .medium))
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Spacing.wide)
    }

    // MARK: - 公共 Sheet 组件

    /// 隐私政策 / 服务条款 通用弹窗
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
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text(content)
                            .font(.body)
                            .foregroundStyle(.appText)
                            .lineSpacing(Spacing.tiny)
                        Spacer()
                    }
                    .padding()
                    .appListRowBackground()
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Localized.currentLocale)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.confirm) {
                        isPresented.wrappedValue = false
                    }
                }
            }
        }
    }

    // MARK: - 逻辑

    private func handleAuth() {
        if !isAgreementChecked {
            ToastManager.shared.show(type: .error, message: L10n.Auth.agreementRequired)
            HapticFeedback.shared.trigger(.error)
            return
        }

        Task {
            isLoading = true
            errorMessage = nil

            let success = await authService.login(using: CarrierAuthStrategy())

            if !success {
                errorMessage = L10n.Auth.authFailed
                HapticFeedback.shared.trigger(.error)
            } else {
                HapticFeedback.shared.trigger(.success)
            }

            isLoading = false
        }
    }

    /// 触发第三方账号授权登录逻辑
    func handleThirdPartyLogin(using strategy: any AuthStrategy) {
        if !isAgreementChecked {
            ToastManager.shared.show(type: .error, message: L10n.Auth.agreementRequired)
            HapticFeedback.shared.trigger(.error)
            return
        }

        Task {
            isLoading = true
            errorMessage = nil

            let success = await authService.login(using: strategy)

            if !success {
                errorMessage = L10n.Auth.authFailed
                HapticFeedback.shared.trigger(.error)
            } else {
                HapticFeedback.shared.trigger(.success)
            }

            isLoading = false
        }
    }
}
