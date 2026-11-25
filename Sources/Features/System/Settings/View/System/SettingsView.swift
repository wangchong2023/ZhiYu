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
import UFPDesignSystem
import UFPCore

/// 设置页二级子路由（强类型值路由，确保点击左侧任意分类时可编程式清空导航栈）
enum SettingsSubRoute: Hashable {
    case systemStats
    case iCloudSync
    case backup
    case log
    case ragEvaluation
    case performanceDashboard
    case taskRoutingRules

    var displayTitle: String {
        switch self {
        case .systemStats: return L10n.Common.usage
        case .iCloudSync: return L10n.Settings.iCloudSync
        case .backup: return L10n.Backup.title
        case .log: return L10n.Settings.operationLog
        case .ragEvaluation: return L10n.Dashboard.stats.benchmark
        case .performanceDashboard: return L10n.Common.Perf.title
        case .taskRoutingRules: return L10n.ModelManager.Routing.taskRules
        }
    }
}

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
    
    /// 设置分类枚举，表示各个设置大类（人工智能与插件中心已统一收敛至头像菜单独立入口）
    enum SettingsSection: String, CaseIterable, Identifiable {
        case appearance      // 界面外观
        case security        // 安全隐私
        case data            // 数据与日志
        case feedback        // 反馈改进
        #if DEBUG
        case developer       // 开发调试
        #endif
        case about           // 关于软件

        static var allCases: [SettingsSection] {
            #if DEBUG
            return [.appearance, .security, .data, .feedback, .developer, .about]
            #else
            return [.appearance, .security, .data, .feedback, .about]
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
                return DesignTokens.Icons.settingsAppearance
            case .security:
                return DesignTokens.Icons.settingsSecurity
            case .data:
                return DesignTokens.Icons.settingsData
            case .feedback:
                return "bubble.left.and.bubble.right.fill"
            #if DEBUG
            case .developer:
                return "hammer.fill"
            #endif
            case .about:
                return DesignTokens.Icons.settingsAbout
            }
        }
    }
    
    @State var selectedLanguage: LanguageMode = Localized.languageMode
    @State var languageChanged = false
    @State var showInjectConfirmation = false
    @State var isInjecting = false
    /// 免费用户尝试开启安全功能时弹出升级提示
    @State var showUpgradeSheet = false
    /// 当前大屏布局下选中的设置分类，默认选中“外观”
    @State private var selectedSection: SettingsSection? = .appearance
    /// 右侧详情区导航栈路径（切换左侧分类时立即清空，彻底解决停留在子页面无法切换的问题）
    @State private var detailPath: [SettingsSubRoute] = []
    /// 当前悬停的设置分类（用于桌面端即时悬停反馈）
    @State private var hoveredSection: SettingsSection?
    
    var body: some View {
        @Bindable var router = router
        
        Group {
            if idiom == .macCatalyst || idiom == .mac {
                ZStack {
                    themeManager.pageBackground()
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        sidebarColumn
                            .frame(width: DesignTokens.Metrics.settingsSidebarWidth)

                        Divider()
                            .opacity(DesignTokens.Opacity.soft)

                        VStack(spacing: 0) {
                            macDetailHeaderBar

                            NavigationStack(path: $detailPath) {
                                detailColumn(for: selectedSection, router: router)
                                    .navigationDestination(for: SettingsSubRoute.self) { route in
                                        subRouteDestination(for: route)
                                            .navigationBarBackButtonHidden(true)
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationStack(path: $detailPath) {
                    ZStack {
                        themeManager.pageBackground()
                            .ignoresSafeArea()

                        compactList
                    }
                    .navigationDestination(for: SettingsSubRoute.self) { route in
                        subRouteDestination(for: route)
                    }
                    .navigationTitle(L10n.Common.settings)
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
        .appToast()
        .alert(L10n.Settings.injectConfirm.title, isPresented: $showInjectConfirmation) {
            Button(L10n.Common.confirm) {
                Task {
                    isInjecting = true
                    let result = await store.generateInitialNotebooks()
                    isInjecting = false

                    let feedbackDelayNs: UInt64 = 300_000_000
                    try? await Task.sleep(nanoseconds: feedbackDelayNs)

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
        .adaptiveListStyle()
        .scrollContentBackground(.hidden)
    }

    /// 桌面端右侧内联标题栏（进入二级子页面时在左上角展示内联返回按钮，彻底避免 macOS Settings 双行居中工具栏）
    private var macDetailHeaderBar: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            if !detailPath.isEmpty {
                Button {
                    detailPath.removeLast()
                } label: {
                    Image(systemName: DesignTokens.Icons.back)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.appText)
                        .frame(width: DesignTokens.IconSize.large, height: DesignTokens.IconSize.large)
                        .background(
                            Circle()
                                .fill(Color.appCard.opacity(DesignTokens.Opacity.soft))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(detailPath.last?.displayTitle ?? selectedSection?.displayName ?? L10n.Common.settings)
                .font(.title3.bold())
                .foregroundStyle(.appText)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.loosePadding)
        .padding(.top, DesignTokens.Spacing.standardPadding)
        .padding(.bottom, DesignTokens.Spacing.small)
    }

    /// 构建大屏左侧分类侧边栏（参考现代 macOS 设置风格：顶部大标题 + 柔和选中胶囊 + 单行无折行）
    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.Common.settings)
                .font(.title3.bold())
                .foregroundStyle(.appText)
                .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                .padding(.top, DesignTokens.Spacing.standardPadding)
                .padding(.bottom, DesignTokens.Spacing.medium)

            ScrollView {
                VStack(spacing: DesignTokens.SystemSpacing.tiny) {
                    ForEach(SettingsSection.allCases) { section in
                        let isSelected = selectedSection == section
                        let isHovered = hoveredSection == section
                        let rowShape = RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius, style: .continuous)
                        Button(action: {
                            detailPath.removeAll()
                            if selectedSection != section {
                                selectedSection = section
                            }
                        }) {
                            HStack(spacing: DesignTokens.Spacing.small) {
                                Image(systemName: section.iconName)
                                    .font(.subheadline)
                                    .foregroundStyle(isSelected ? Color.appAccent : .appSecondary)
                                    .frame(width: DesignTokens.IconSize.standard, alignment: .center)
                                Text(section.displayName)
                                    .font(.body.weight(isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? .appText : .appSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                            .padding(.vertical, DesignTokens.SystemSpacing.small)
                            .background(
                                rowShape.fill(
                                    isSelected
                                        ? Color.appAccent.opacity(DesignTokens.Opacity.glass)
                                        : (isHovered ? Color.appBorder.opacity(DesignTokens.Opacity.subtle) : Color.clear)
                                )
                            )
                            .contentShape(rowShape)
                        }
                        .buttonStyle(.plain)
                        .onHoverIfAvailable { hovering in
                            hoveredSection = hovering ? section : (hoveredSection == section ? nil : hoveredSection)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                .padding(.bottom, DesignTokens.SystemSpacing.content)
            }
        }
        .background(Color.appBackground.opacity(DesignTokens.Opacity.subtle))
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
                    AboutView(showsDismissButton: false, usesEmbeddedBackground: true)
                case .feedback:
                    FeedbackView(isEmbedded: true)
                        .environment(themeManager)
                #if DEBUG
                case .developer:
                    developerSettingsDestination
                #endif
                default:
                    defaultSettingsList(for: section)
                }
            }
            .navigationTitle(section.displayName)
            .appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !(idiom == .macCatalyst || idiom == .mac) {
                    ToolbarItem(placement: .confirmationAction) {
                        doneButton(router: router)
                    }
                }
            }
        } else {
            emptyDetailPlaceholder(router: router)
        }
    }
    
    /// 统一的设置二级子路由视图分发
    @ViewBuilder
    private func subRouteDestination(for route: SettingsSubRoute) -> some View {
        switch route {
        case .systemStats:
            SystemStatsView()
        case .iCloudSync:
            #if ICLOUD_ENABLED
            iCloudSyncView()
            #else
            EmptyView()
            #endif
        case .backup:
            BackupView()
        case .log:
            LogView()
        case .ragEvaluation:
            RAGEvaluationView()
        case .performanceDashboard:
            PerformanceDashboardView(service: store.performanceService)
        case .taskRoutingRules:
            TaskRoutingRulesView()
        }
    }

    /// 统一的设置页完成保存按钮组件
    /// - Parameter router: 路由实例
    @ViewBuilder
    func doneButton(router: Router) -> some View {
        Button(L10n.Common.done) {
            router.isShowingSettingsSheet = false
            dismiss()
        }
        .bold()
    }

    #if DEBUG
    var developerSection: some View {
        Section {
            NavigationLink {
                DeveloperSettingsView()
                    .environment(store)
                    .environment(store.knowledgeStore)
                    .environment(store.settingsStore)
                    .environmentObject(onboardingService)
            } label: {
                Label(L10n.Settings.Section.developer, systemImage: DesignTokens.Icons.settingsDeveloper)
                    .labelStyle(ColorfulIconLabelStyle(color: Color.theme.gray))
            }
        }
    }

    @ViewBuilder
    var developerSettingsDestination: some View {
        DeveloperSettingsView(isEmbedded: true)
            .environment(store)
            .environment(store.knowledgeStore)
            .environment(store.settingsStore)
            .environmentObject(onboardingService)
    }
    #endif
}
