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
import Dependencies
import UFPDesignSystem
import UFPCore

/// 身份认证主视图
struct AuthView: View {
    @Dependency(\.toastService) private var toastManager
    @Environment(AuthService.self) var authService
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.interfaceIdiom) private var idiom

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
        // swiftlint:disable:next redundant_discardable_let
        let _ = (showPrivacySheet, showTermsSheet)
        if usesDesktopLayout {
            desktopLoginLayout
        } else {
            compactLoginLayout
        }
    }

    /// 是否走桌面形态布局：仅当运行时 Trait 为 `.mac` 时启用。
    /// body 分派与单测共用 `isDesktopLayout` 判定，保证分派逻辑可被测。
    var usesDesktopLayout: Bool {
        AuthView.isDesktopLayout(idiom)
    }

    /// 布局分派决策的纯函数形式：仅 `.mac` 走桌面形态布局。
    /// 与 `@Environment` 解耦，便于单测直接验证分派决策本身。
    static func isDesktopLayout(_ idiom: InterfaceIdiom) -> Bool {
        idiom == .mac
    }

    // MARK: - 运行时 Trait 分派的登录布局

    /// 桌面形态双栏画报布局（方案 B）：全窗统一协调背景 + 居中黄金比例双栏舞台（全屏超宽屏不再拉散）
    private var desktopLoginLayout: some View {
        ZStack(alignment: .topTrailing) {
            // 整窗统一连续背景层，消除左右栏色差割裂
            themeManager.pageBackground()
                .ignoresSafeArea()

            // 全屏/宽屏自适应居中双栏舞台：限制最大宽高保持 42%:58% 黄金视觉比例
            GeometryReader { proxy in
                let stageHeight = min(
                    max(proxy.size.height - DesignTokens.Spacing.huge * 2, DesignTokens.Metrics.minWindowHeight),
                    DesignTokens.Metrics.macAuthStageMaxHeight
                )
                HStack(spacing: DesignTokens.Spacing.huge) {
                    // 左侧内嵌品牌渐变画报卡
                    desktopBrandPanel
                        .frame(maxWidth: DesignTokens.Metrics.authHeroWidth, maxHeight: .infinity)

                    // 右侧通透垂直居中登录流
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DesignTokens.Spacing.giant) {
                            // 卡片登录承载容器 (保留 3D 翻转动画)
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
                                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1.0, z: 0.0))
                                }
                            }
                            .rotation3DEffect(.degrees(rotateDegrees), axis: (x: 0, y: 1.0, z: 0.0))

                            AuthOAuthPanel(
                                isLoading: $isLoading,
                                isAgreementChecked: $isAgreementChecked,
                                errorMessage: $errorMessage,
                                handleThirdPartyLogin: handleThirdPartyLogin
                            )

                            AuthGuestSection()
                        }
                        .frame(maxWidth: DesignTokens.Metrics.authFormWidth)
                        .padding(.horizontal, DesignTokens.Spacing.wide)
                        .padding(.vertical, DesignTokens.Spacing.giant)
                        .frame(maxWidth: .infinity, minHeight: stageHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: DesignTokens.Metrics.macAuthStageMaxWidth, maxHeight: stageHeight)
                .padding(.horizontal, DesignTokens.Spacing.huge)
                .padding(.vertical, DesignTokens.Spacing.giant)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 窗口右上角低调悬浮控制条（区域切换 + 语言胶囊）
            desktopTopControlBar
                .padding(.horizontal, DesignTokens.Spacing.giant)
                .padding(.top, DesignTokens.Spacing.large)
        }
        .policySheet(
            isPresented: $showPrivacySheet,
            title: L10n.Auth.privacyPolicyTitle,
            content: L10n.Auth.privacyPolicyContent
        )
        .policySheet(
            isPresented: $showTermsSheet,
            title: L10n.Auth.termsOfServiceTitle,
            content: L10n.Auth.termsOfServiceContent
        )
    }

    /// 桌面形态左侧内嵌品牌画报卡：同色系深邃极光渐变 + 干净书本图标 + 无框极简特性行
    private var desktopBrandPanel: some View {
        let posterShape = RoundedRectangle(cornerRadius: DesignTokens.Spacing.chipRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.huge) {
            // 顶部品牌徽章（干净圆角方块 + 无外圈书本图标，告别「方套圆」）
            HStack(spacing: DesignTokens.Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius, style: .continuous)
                        .fill(Color.theme.white.opacity(DesignTokens.Opacity.glass))
                        .frame(width: DesignTokens.Spacing.iconDisplay, height: DesignTokens.Spacing.iconDisplay)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius, style: .continuous)
                                .strokeBorder(
                                    Color.theme.white.opacity(DesignTokens.Opacity.soft),
                                    lineWidth: DesignTokens.Spacing.borderWidth
                                )
                        )

                    Image(systemName: DesignTokens.Icons.library)
                        .font(.system(size: DesignTokens.Typography.headlineFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(L10n.Common.appName)
                    .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(DesignTokens.Reference.Spacing.one)
            }

            Spacer(minLength: DesignTokens.Spacing.large)

            // 品牌主标语
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                Text(L10n.Onboarding.subtitle)
                    .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.Onboarding.pathTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.theme.white.opacity(DesignTokens.Opacity.prominent))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 三条无框极简特性短语（去掉灰色小盒，保持画报克制与通透）
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                desktopFeatureRow(
                    icon: DesignTokens.Icons.folderFill,
                    title: L10n.Onboarding.Step.vault.title,
                    description: L10n.Onboarding.Step.vault.desc
                )
                desktopFeatureRow(
                    icon: DesignTokens.Icons.mindmap,
                    title: L10n.Onboarding.Step.graph.title,
                    description: L10n.Onboarding.Step.graph.desc
                )
                desktopFeatureRow(
                    icon: DesignTokens.Icons.sparkles,
                    title: L10n.Onboarding.Step.aiLab.title,
                    description: L10n.Onboarding.Step.aiLab.desc
                )
            }

            Spacer(minLength: DesignTokens.Spacing.medium)
        }
        .padding(DesignTokens.Spacing.huge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(desktopBrandPosterBackground)
        .clipShape(posterShape)
        .overlay(
            posterShape
                .strokeBorder(
                    Color.theme.white.opacity(DesignTokens.Opacity.glass),
                    lineWidth: DesignTokens.Spacing.borderWidth
                )
        )
        .shadow(
            color: Color.theme.indigo.opacity(DesignTokens.Opacity.glass),
            radius: DesignTokens.Spacing.wide,
            y: DesignTokens.Spacing.small
        )
    }

    /// 左侧品牌画报协调深邃渐变背景
    private var desktopBrandPosterBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.theme.indigo, .appAccent, .appConcept],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 柔和深色渐变叠层，保证任意强调色下均具备高雅深邃质感与高对比白色文字
            LinearGradient(
                colors: [
                    Color.theme.black.opacity(DesignTokens.Opacity.soft),
                    Color.theme.black.opacity(DesignTokens.Opacity.medium)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 左上微光氛围点缀
            RadialGradient(
                colors: [
                    Color.theme.white.opacity(DesignTokens.Opacity.glass),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: DesignTokens.Metrics.backgroundDecorativeSize
            )
        }
    }

    /// 桌面形态品牌画报单条无框特性行
    private func desktopFeatureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.medium) {
            ZStack {
                Circle()
                    .fill(Color.theme.white.opacity(DesignTokens.Opacity.glass))
                    .frame(width: DesignTokens.IconSize.huge, height: DesignTokens.IconSize.huge)

                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.theme.white.opacity(DesignTokens.Opacity.prominent))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    /// 桌面形态顶部控制条：低调居于右上角，不干扰主视觉
    private var desktopTopControlBar: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Spacer()

            RegionSelectorToggle(currentRegion: $currentRegion) {
                triggerRegionFlip()
            }
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color.appBorder.opacity(DesignTokens.Opacity.soft),
                        lineWidth: DesignTokens.Spacing.borderWidth
                    )
            )

            desktopLanguageMenu
        }
    }

    /// 桌面形态语言切换菜单胶囊（无额外外边距，确保右缘对齐）
    private var desktopLanguageMenu: some View {
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
                Capsule()
                    .strokeBorder(
                        Color.appBorder.opacity(DesignTokens.Opacity.soft),
                        lineWidth: DesignTokens.Spacing.borderWidth
                    )
            )
            .contentShape(Capsule())
        }
        .plainMenuStyleIfMac()
    }

    /// 紧凑形态布局：原纵向单列布局，保留 3D 翻转卡片动画
    private var compactLoginLayout: some View {
        ZStack {
            // 背景层
            themeManager.pageBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // 顶部控制条（区域选择与语言切换）
                topControlBar

                VStack(spacing: DesignTokens.Spacing.huge) {
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
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1.0, z: 0.0))
                        }
                    }
                    .rotation3DEffect(.degrees(rotateDegrees), axis: (x: 0, y: 1.0, z: 0.0))

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
                .padding(.horizontal, DesignTokens.Spacing.wide)
                .padding(.vertical, DesignTokens.Spacing.wide)
            }
        }
        .policySheet(
            isPresented: $showPrivacySheet,
            title: L10n.Auth.privacyPolicyTitle,
            content: L10n.Auth.privacyPolicyContent
        )
        .policySheet(
            isPresented: $showTermsSheet,
            title: L10n.Auth.termsOfServiceTitle,
            content: L10n.Auth.termsOfServiceContent
        )
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
        .padding(.horizontal, DesignTokens.Spacing.wide)
        .padding(.top, DesignTokens.Spacing.tiny)
    }

    /// 触发 3D 卡片翻转动效
    private func triggerRegionFlip() {
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
    private var languageSwitcher: some View {
        HStack {
            Spacer()
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
                        .font(.caption)
                }
                .foregroundStyle(.appSecondary)
                .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                .padding(.vertical, DesignTokens.SystemSpacing.small)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .plainMenuStyleIfMac()
        }
        .padding(.trailing, DesignTokens.Spacing.medium)
        .padding(.top, DesignTokens.Spacing.tiny)
    }

    /// 判断指定语言是否为当前选中项
    static func isLanguageSelected(_ mode: LanguageMode, current: LanguageMode) -> Bool {
        mode == current
    }

    /// 为单个语言项生成顶层菜单勾选绑定，避免 macOS 上 Menu 内嵌 Picker 产生空白二级子菜单
    private func languageSelectionBinding(for mode: LanguageMode) -> Binding<Bool> {
        Binding(
            get: { AuthView.isLanguageSelected(mode, current: selectedLanguage) },
            set: { _ in
                selectedLanguage = mode
                Localized.languageMode = mode
            }
        )
    }

    private var heroHeader: some View {
        VStack(spacing: DesignTokens.Spacing.giant) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.appAccent.opacity(DesignTokens.Opacity.medium), .appConcept.opacity(DesignTokens.Opacity.subtle)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: DesignTokens.Spacing.Auth.logoBackgroundSize, height: DesignTokens.Spacing.Auth.logoBackgroundSize)
                    .blur(radius: DesignTokens.Spacing.shadowRadius)

                Image(systemName: DesignTokens.Icons.knowledge)
                    .font(.system(size: DesignTokens.Reference.FontSize.mega))
                    .foregroundStyle(LinearGradient(colors: [.appAccent, .appConcept], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .appAccent.opacity(DesignTokens.Opacity.disabled), radius: DesignTokens.Spacing.shadowRadius, y: DesignTokens.Spacing.shadowY)
            }

            VStack(spacing: DesignTokens.Spacing.small) {
                Text(L10n.Common.appName)
                    .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(.appText)
                    .tracking(DesignTokens.Reference.Spacing.one)

                Text(L10n.Onboarding.subtitle)
                    .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .medium))
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, DesignTokens.Spacing.wide)
    }

    // MARK: - 逻辑

    private func handleAuth() {
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
