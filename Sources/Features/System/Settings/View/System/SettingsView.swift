//
//  SettingsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Settings 界面的 UI 视图层组件。
//
import SwiftUI
import Dependencies

struct SettingsView: View {
    @Dependency(\.toastService) private var toastManager
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Environment(AppEnvironment.self) var appEnv
    @Environment(\.dismiss) var dismiss
    @Environment(SettingsStore.self) var settingsStore
    @EnvironmentObject var onboardingService: OnboardingService
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.interfaceIdiom) private var idiom
    
    /// 设置分类枚举，表示各个设置大类
    private enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance      // 界面外观
        case security        // 安全隐私
        case data            // 数据与日志
        case plugins         // 插件与扩展
        case feedback        // 反馈改进
        #if DEBUG
        case developer       // 开发调试
        #endif
        case about           // 关于软件

        static var allCases: [SettingsSection] {
            #if DEBUG
            return [.appearance, .security, .data, .plugins, .feedback, .developer, .about]
            #else
            return [.appearance, .security, .data, .plugins, .feedback, .about]
            #endif
        }

        var id: String { rawValue }

        /// 各分类的本地化展示名称
        var displayName: String {
            switch self {
            case .appearance:
                return L10n.Settings.Section.appearance
            case .security:
                return L10n.Settings.Section.security
            case .data:
                return L10n.Settings.Section.data
            case .plugins:
                return L10n.Settings.Section.plugins
            case .feedback:
                return L10n.Settings.Feedback.title
            #if DEBUG
            case .developer:
                return L10n.Settings.Section.developer
            #endif
            case .about:
                return L10n.Settings.Section.about
            }
        }

        /// 各分类对应的系统 SF Symbol 图标名称
        var iconName: String {
            switch self {
            case .appearance:
                return DesignSystem.Icons.settingsAppearance
            case .security:
                return DesignSystem.Icons.settingsSecurity
            case .data:
                return DesignSystem.Icons.settingsData
            case .plugins:
                return DesignSystem.Icons.settingsPlugins
            case .feedback:
                return "bubble.left.and.bubble.right.fill"
            #if DEBUG
            case .developer:
                return "hammer.fill"
            #endif
            case .about:
                return DesignSystem.Icons.settingsAbout
            }
        }
    }
    
    @State private var selectedLanguage: LanguageMode = Localized.languageMode
    @State private var languageChanged = false
    @State private var showInjectConfirmation = false
    @State private var isInjecting = false
    /// Lite 用户尝试开启安全功能时弹出升级提示
    @State private var showUpgradeSheet = false
    /// 当前大屏布局下选中的设置分类，默认选中“外观”
    @State private var selectedSection: SettingsSection? = .appearance
    
    var body: some View {
        @Bindable var router = router
        
        Group {
            if idiom == .macCatalyst {
                HStack(spacing: 0) {
                    sidebarColumn
                        .frame(width: DesignSystem.Metrics.settingsSidebarWidth)

                    Divider()
                        .background(Color.appBorder.opacity(DesignSystem.Opacity.shadow))

                    ZStack {
                        themeManager.pageBackground()
                            .ignoresSafeArea()

                        NavigationStack {
                            detailColumn(for: selectedSection, router: router)
                        }
                                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                NavigationStack {
                    ZStack {
                        themeManager.pageBackground()
                            .ignoresSafeArea()

                        compactList
                    }
                                    .navigationTitle(L10n.Settings.title)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            doneButton(router: router)
                        }
                    }
                }
            }
        }
        .environment(\.locale, router.currentLocale)
        // 绑定当前主题对应的 preferredColorScheme，使深色模式和浅色模式切换能立即在该视图层实时生效
        .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
        .id(themeManager.colorSchemeMode)
        .appToast()
        .alert(L10n.Settings.injectConfirm.title, isPresented: $showInjectConfirmation) {
            Button(L10n.Common.confirm) {
                Task {
                    isInjecting = true
                    let result = await store.generateInitialNotebooks()
                    isInjecting = false

                    try? await Task.sleep(nanoseconds: 300_000_000)

                    HapticFeedback.shared.trigger(result.total > 0 ? .success : .error)
                    let total = result.total
                    let details = result.details
                    if total > 0 {
                        let prefix = String(format: L10n.Settings.InjectDemo.injectedNotebooks, details.count)
                        let suffix = L10n.Settings.InjectDemo.pageUnit
                        let sep = L10n.Settings.InjectDemo.itemsSeparator
                        var vaultsDesc = ""
                        for (i, detail) in details.enumerated() {
                            if i > 0 { vaultsDesc += sep }
                            vaultsDesc += detail.name + String(detail.count) + suffix
                        }
                        let msg = prefix + vaultsDesc
                        toastManager.show(type: .success, message: msg)
                    } else {
                        toastManager.show(type: .error, message: L10n.Settings.InjectDemo.errorMessage)
                    }
                }
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Settings.injectConfirm.message)
        }
    }
    
    /// 构建小屏下的紧凑设置列表
    private var compactList: some View {
        List {
            appearanceSection
                .appListRowBackground()
            
            dataManagementSection
                .appListRowBackground()

            PluginExtensionsSection()
                .appListRowBackground()

            securitySection(store: store)
                .appListRowBackground()

            feedbackSection
                .appListRowBackground()

            #if DEBUG
            developerSection
                .appListRowBackground()
            #endif

            aboutSection
                .appListRowBackground()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    /// 构建大屏左侧分类侧边栏（气泡圆角卡片样式，具备呼吸感与选中高亮）
    private var sidebarColumn: some View {
        ScrollView {
            VStack(spacing: SystemSpacing.small) {
                ForEach(SettingsSection.allCases) { section in
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        selectedSection = section
                    }) {
                        HStack(spacing: DesignSystem.medium) {
                            Image(systemName: section.iconName)
                                .font(.subheadline)
                                .foregroundStyle(selectedSection == section ? .white : .appAccent)
                                .frame(width: DesignSystem.IconSize.standard, alignment: .center)
                            Text(section.displayName)
                                .font(.body.weight(.medium))
                                .foregroundStyle(selectedSection == section ? .white : .appText)
                            Spacer()
                        }
                        .padding(.horizontal, SystemSpacing.content)
                        .padding(.vertical, SystemSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous)
                                .fill(selectedSection == section ? Color.appAccent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SystemSpacing.medium)
            .padding(.vertical, SystemSpacing.content)
        }
        .background(Color.appCard.opacity(DesignSystem.Opacity.disabled)) // 侧边栏微暗色半透明质感
    }
    
    /// 根据当前选中的分类，渲染右侧具体详情面板
    /// - Parameters:
    ///   - section: 当前选中的设置大类
    ///   - router: 路由实例，用于触发全局事件
    @ViewBuilder
    private func detailColumn(for section: SettingsSection?, router: Router) -> some View {
        if let section = section {
            Group {
                switch section {
                case .about:
                    AboutView()
                case .feedback:
                    FeedbackView()
                        .environment(themeManager)
                case .plugins:
                    PluginExtensionsDetailView()
                #if DEBUG
                case .developer:
                    developerSettingsDestination
                #endif
                default:
                    defaultSettingsList(for: section)
                }
            }
            .navigationTitle(section.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    doneButton(router: router)
                }
            }
        } else {
            emptyDetailPlaceholder(router: router)
        }
    }
    
    /// 统一的设置页完成保存按钮组件
    /// - Parameter router: 路由实例
    @ViewBuilder
    private func doneButton(router: Router) -> some View {
        Button(L10n.Common.done) {
            router.isShowingSettingsSheet = false
            dismiss()
        }
        .bold()
    }
    
    private var appearanceSection: some View {
        @Bindable var bindableThemeManager = themeManager
        return Section {
            Picker(selection: $bindableThemeManager.colorSchemeMode) {
                ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label(L10n.Settings.systemTheme, systemImage: DesignSystem.Icons.settingsAppearance)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.indigo))
            }

            Picker(selection: $selectedLanguage) {
                ForEach(LanguageMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Label(L10n.Settings.systemLanguage, systemImage: DesignSystem.Icons.globe)
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
    
    private var dataManagementSection: some View {
        Section {
            // 将用量统计调整至首行，提高核心运营数据的展示优先级
            NavigationLink {
                SystemStatsView()
            } label: {
                Label(L10n.Common.usage, systemImage: DesignSystem.Icons.chartBarFill)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.teal))
            }

            #if ICLOUD_ENABLED
            NavigationLink {
                iCloudSyncView()
            } label: {
                Label(L10n.Settings.iCloudSync, systemImage: DesignSystem.Icons.icloud)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.blue))
            }
            #endif
            
            // 将恢复备份调整至第三行，降低非常规操作的入口级别
            NavigationLink {
                BackupView()
            } label: {
                Label(L10n.Settings.backupRestore, systemImage: DesignSystem.Icons.settingsData)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.brown))
            }
            
            NavigationLink {
                LogView()
            } label: {
                Label(L10n.Settings.operationLog, systemImage: DesignSystem.Icons.listBulletRectangleFill)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.mint))
            }
            
            // 恢复预设：生成默认的演示笔记本
            Button(action: { showInjectConfirmation = true }) {
                HStack {
                    Label(L10n.Settings.rebuildInitialNotebooks, systemImage: DesignSystem.Icons.arrowCounterclockwise)
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
    
    private func securitySection(store _: AppStore) -> some View {
        @Bindable var settingsStore = settingsStore
        let hasFeature = AuthSession.shared.currentUser?.hasPrivacySecurity == true
        let showBiometric = appEnv.platformEnv.interactionStyle == .touch
        
        // 自定义 Binding：Lite 用户尝试开启时拦截并弹出升级提示
        let privacyBinding = Binding<Bool>(
            get: { settingsStore.isPrivacyModeEnabled },
            set: { newValue in
                if hasFeature {
                    settingsStore.isPrivacyModeEnabled = newValue
                } else if newValue {
                    // Lite 用户尝试开启 → 弹出升级提示，不修改状态
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
                Label(L10n.Settings.privacyMode, systemImage: DesignSystem.Icons.settingsSecurity)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.purple))
            }
            
            if showBiometric {
                Toggle(isOn: biometricBinding) {
                    Label(L10n.Settings.biometricProtection, systemImage: DesignSystem.Icons.faceid)
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
        }
    }
    
    private var feedbackSection: some View {
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
    
    private var aboutSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Label(L10n.Settings.Section.about, systemImage: DesignSystem.Icons.settingsAbout)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.gray))
            }
        }
    }
    
    #if DEBUG
    private var developerSection: some View {
        Section {
            NavigationLink {
                DeveloperSettingsView()
                    .environment(store)
                    .environment(store.knowledgeStore)
                    .environment(store.settingsStore)
                    .environmentObject(onboardingService)
            } label: {
                Label(L10n.Settings.Section.developer, systemImage: DesignSystem.Icons.settingsDeveloper)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.gray))
            }
        }
    }
    
    @ViewBuilder
    private var developerSettingsDestination: some View {
        DeveloperSettingsView()
            .environment(store)
            .environment(store.knowledgeStore)
            .environment(store.settingsStore)
            .environmentObject(onboardingService)
    }
    #endif
    
    @ViewBuilder
    private func defaultSettingsList(for section: SettingsSection) -> some View {
        List {
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    @ViewBuilder
    private func emptyDetailPlaceholder(router: Router) -> some View {
        VStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.gearshape2)
                .font(.system(size: Reference.FontSize.mega)) // Dynamic Type
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
        HStack(spacing: DesignSystem.medium) {
            configuration.icon
                .font(.system(size: SystemFontSize.body, weight: .medium)) // Dynamic Type
                .foregroundStyle(.white)
                .frame(width: DesignSystem.Metrics.settingsIconFrameSize, height: DesignSystem.Metrics.settingsIconFrameSize)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small, style: .continuous))
            
            configuration.title
        }
    }
}
