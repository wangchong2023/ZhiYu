//
//  SettingsView+Sections.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 设置页分组区块扩展
//  核心职责：承载 SettingsView 的外观、数据管理、安全隐私、反馈、关于、开发者调试区块
//           与 ColorfulIconLabelStyle，按单一职责与主容器路由逻辑解耦。
//

import SwiftUI
import UFPCore
import UFPDesignSystem

extension SettingsView {

    var appearanceSection: some View {
        @Bindable var bindableThemeManager = themeManager
        return Section {
            Picker(selection: $bindableThemeManager.colorSchemeMode) {
                ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label(L10n.Settings.systemTheme, systemImage: DesignTokens.Icons.settingsAppearance)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.indigo))
            }

            Picker(selection: $selectedLanguage) {
                ForEach(LanguageMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label(L10n.Settings.systemLanguage, systemImage: DesignTokens.Icons.globe)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.blue))
            }
            .onChange(of: selectedLanguage) { _, newValue in
                Localized.languageMode = newValue
                languageChanged = true
                router.triggerLanguageRefresh()
            }
        } header: {
            Text(L10n.Settings.Section.appearance)
        }
        .id(router.currentLocale)
    }

    var dataManagementSection: some View {
        Section {
            // 将用量统计调整至首行，提高核心运营数据的展示优先级
            NavigationLink(value: SettingsSubRoute.systemStats) {
                Label(L10n.Common.usage, systemImage: DesignTokens.Icons.chartBarFill)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.teal))
            }

            #if ICLOUD_ENABLED
            NavigationLink(value: SettingsSubRoute.iCloudSync) {
                Label(L10n.Settings.iCloudSync, systemImage: DesignTokens.Icons.icloud)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.blue))
            }
            #endif

            // 将恢复备份调整至第三行，降低非常规操作的入口级别
            NavigationLink(value: SettingsSubRoute.backup) {
                Label(L10n.Settings.backupRestore, systemImage: DesignTokens.Icons.settingsData)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.brown))
            }

            NavigationLink(value: SettingsSubRoute.log) {
                Label(L10n.Settings.operationLog, systemImage: DesignTokens.Icons.listBulletRectangleFill)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.mint))
            }

            // 恢复预设：生成默认的演示笔记本
            Button(action: { showInjectConfirmation = true }) {
                HStack {
                    Label(L10n.Settings.rebuildInitialNotebooks, systemImage: DesignTokens.Icons.arrowCounterclockwise)
                        .labelStyle(ColorfulIconLabelStyle(color: Color.theme.red))
                        .foregroundStyle(.appText)
                    Spacer()
                    if isInjecting {
                        ProgressView()
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isInjecting)
        } header: {
            Text(L10n.Settings.Section.data)
        }
    }

    func securitySection(store _: AppStore) -> some View {
        @Bindable var settingsStore = settingsStore
        let hasFeature = AuthSession.shared.currentUser?.hasPrivacySecurity == true
        let showBiometric = appEnv.platformEnv.interactionStyle == .touch

        // 自定义 Binding：免费用户尝试开启时拦截并弹出升级提示
        let privacyBinding = Binding<Bool>(
            get: { settingsStore.isPrivacyModeEnabled },
            set: { newValue in
                if hasFeature {
                    settingsStore.isPrivacyModeEnabled = newValue
                } else if newValue {
                    // 免费用户尝试开启 → 弹出升级提示，不修改状态
                    showUpgradeSheet = true
                } else {
                    settingsStore.isPrivacyModeEnabled = newValue
                }
            }
        )
        let biometricBinding = Binding<Bool>(
            get: { settingsStore.isBiometricEnabled },
            set: { newValue in
                if hasFeature {
                    settingsStore.isBiometricEnabled = newValue
                } else if newValue {
                    showUpgradeSheet = true
                } else {
                    settingsStore.isBiometricEnabled = newValue
                }
            }
        )

        return Section {
            Toggle(isOn: privacyBinding) {
                Label(L10n.Settings.privacyMode, systemImage: DesignTokens.Icons.settingsSecurity)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.purple))
            }

            if showBiometric {
                Toggle(isOn: biometricBinding) {
                    Label(L10n.Settings.biometricProtection, systemImage: DesignTokens.Icons.faceid)
                        .labelStyle(ColorfulIconLabelStyle(color: Color.theme.green))
                }
            }
        } header: {
            Text(L10n.Settings.Section.security)
        } footer: {
            // 帮助文案：说明隐私模式与生物识别的作用。若支持生物识别，则使用合并后的一句话描述，否则使用基础描述。
            if showBiometric {
                Text(L10n.Settings.privacyCombinedDesc)
            } else {
                Text(L10n.Settings.privacyModeDesc)
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            SubscriptionPlanView()
                .appDesktopSheetSize(.large)
        }
    }

    var feedbackSection: some View {
        Section {
            NavigationLink {
                FeedbackView()
                    .environment(themeManager)
            } label: {
                Label(L10n.Settings.Feedback.title, systemImage: "bubble.left.and.bubble.right.fill")
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.blue))
            }
        }
    }

    var aboutSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Label(L10n.Settings.Section.about, systemImage: DesignTokens.Icons.settingsAbout)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.gray))
            }
        }
    }

    @ViewBuilder
    func defaultSettingsList(for section: SettingsSection) -> some View {
        Form {
            switch section {
            case .appearance:
                appearanceSection
                    .appListRowBackground()
            case .security:
                securitySection(store: store)
                    .appListRowBackground()
            case .data:
                dataManagementSection
                    .appListRowBackground()
            default:
                EmptyView()
            }
        }
        .appGroupedFormStyle()
        .scrollContentBackground(.hidden)
        .tint(Color.appAccent)
    }

    @ViewBuilder
    func emptyDetailPlaceholder(router: Router) -> some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.gearshape2)
                .font(.system(size: DesignTokens.SystemFontSize.mega)) // Dynamic Type
                .foregroundStyle(.appAccent)
            Text(L10n.Settings.selectCategoryTip)
                .font(.headline)
                .foregroundStyle(.appText)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                doneButton(router: router)
            }
        }
    }
}

/// A custom label style that adds an iOS-Settings-like colored rounded background to the icon
struct ColorfulIconLabelStyle: LabelStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            configuration.icon
                .font(.system(size: DesignTokens.SystemFontSize.body, weight: .medium)) // Dynamic Type
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Metrics.settingsIconFrameSize, height: DesignTokens.Metrics.settingsIconFrameSize)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small, style: .continuous))

            configuration.title
        }
    }
}
