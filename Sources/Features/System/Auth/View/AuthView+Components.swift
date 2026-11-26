//
//  AuthView+Components.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 登录子组件与交互扩展
//  核心职责：承载 AuthView 的顶部区域/语言控制条、Hero 品牌头视图与统一登录执行逻辑，
//           按单一职责与双端主布局容器解耦。
//

import SwiftUI
import UFPCore
import UFPDesignSystem

extension AuthView {

    // MARK: - 子视图

    /// 系统语言与区域切换控制条
    var topControlBar: some View {
        HStack {
            RegionSelectorToggle(currentRegion: $currentRegion) {
                triggerRegionFlip()
            }

            Spacer()

            languageSwitcher
        }
        .padding(.horizontal, DesignTokens.Spacing.wide)
        .padding(.top, DesignTokens.Spacing.tiny)
    }

    /// 触发 3D 卡片翻转动效
    func triggerRegionFlip() {
        withAnimation(.appSlow) {
            rotateDegrees += FeatureConstants.AuthFlip.rotationDegrees
        }
        Task {
            try? await Task.sleep(for: .seconds(AppConfig.UI.animationDuration))
            await MainActor.run {
                displayedRegion = currentRegion
            }
        }
    }

    /// 系统语言切换按钮（右上角）
    var languageSwitcher: some View {
        HStack {
            Spacer()
            languageMenuCapsule(showBorder: false)
        }
        .padding(.trailing, DesignTokens.Spacing.medium)
        .padding(.top, DesignTokens.Spacing.tiny)
    }

    /// 通用语言切换菜单胶囊（紧凑态与桌面态共用，避免重复构建 Menu）
    func languageMenuCapsule(showBorder: Bool) -> some View {
        Menu {
            ForEach(LanguageMode.allCases) { mode in
                Toggle(isOn: languageSelectionBinding(for: mode)) {
                    Text(mode.displayName)
                }
            }
        } label: {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                Image(systemName: DesignTokens.Icons.globe)
                    .font(.subheadline)
                Text(selectedLanguage.displayName)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.appSecondary)
            .padding(.horizontal, DesignTokens.SystemSpacing.medium)
            .padding(.vertical, DesignTokens.SystemSpacing.small)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Group {
                    if showBorder {
                        Capsule()
                            .strokeBorder(
                                Color.appBorder.opacity(DesignTokens.Opacity.soft),
                                lineWidth: DesignTokens.Spacing.borderWidth
                            )
                    }
                }
            )
            .contentShape(Capsule())
        }
        .plainMenuStyleIfMac()
    }

    /// 判断指定语言是否为当前选中项
    static func isLanguageSelected(_ mode: LanguageMode, current: LanguageMode) -> Bool {
        mode == current
    }

    /// 为单个语言项生成顶层菜单勾选绑定，避免 macOS 上 Menu 内嵌 Picker 产生空白二级子菜单
    func languageSelectionBinding(for mode: LanguageMode) -> Binding<Bool> {
        Binding(
            get: { AuthView.isLanguageSelected(mode, current: selectedLanguage) },
            set: { _ in
                selectedLanguage = mode
                Localized.languageMode = mode
            }
        )
    }

    var heroHeader: some View {
        VStack(spacing: DesignTokens.Spacing.giant) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.appAccent.opacity(DesignTokens.Opacity.medium), .appConcept.opacity(DesignTokens.Opacity.subtle)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: DesignTokens.Spacing.Auth.logoBackgroundSize, height: DesignTokens.Spacing.Auth.logoBackgroundSize)
                    .blur(radius: DesignTokens.Spacing.shadowRadius)

                Image(systemName: DesignTokens.Icons.knowledge)
                    .font(.system(size: DesignTokens.SystemFontSize.mega))
                    .foregroundStyle(LinearGradient(colors: [.appAccent, .appConcept], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .appAccent.opacity(DesignTokens.Opacity.disabled), radius: DesignTokens.Spacing.shadowRadius, y: DesignTokens.Spacing.shadowY)
            }

            VStack(spacing: DesignTokens.Spacing.small) {
                Text(L10n.Common.appName)
                    .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(.appText)
                    .tracking(DesignTokens.SystemSpacing.divider)

                Text(L10n.Onboarding.subtitle)
                    .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .medium))
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, DesignTokens.Spacing.wide)
    }

    // MARK: - 逻辑

    func handleAuth() {
        performLogin(using: CarrierAuthStrategy())
    }

    /// 触发第三方账号授权登录逻辑
    func handleThirdPartyLogin(using strategy: any AuthStrategy) {
        performLogin(using: strategy)
    }

    /// 统一的登录执行逻辑
    private func performLogin(using strategy: any AuthStrategy) {
        if !isAgreementChecked {
            toastManager.show(type: .error, message: L10n.Auth.agreementRequired)
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
