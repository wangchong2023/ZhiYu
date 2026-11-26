//
//  UserProfileMenu.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

struct UserProfileMenu: View {
    @Environment(AuthService.self) var authService
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @EnvironmentObject var onboardingService: OnboardingService
    @Environment(ThemeManager.self) var themeManager
    // property wrapper 必须位于 struct 顶层，禁止放在 body 内 #if 分支
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.interfaceIdiom) private var idiom
    
    @State private var isShowingPopover = false
    @State private var isHoveringMacSettingsRow = false
    @State private var showWatchMenu = false
    @State private var showAbout = false
    @State private var showSettings = false
    @State private var pendingMenuAction: MenuAction?

    enum MenuAction {
        case settings, profile, plan, plugins, aiSettings

        /// 在 Router 上派发对应 sheet 开关，消除 UserProfileMenu / UserProfileMenuSheetContent 两处 switch 重复。
        @MainActor
        func apply(to router: Router) {
            switch self {
            case .settings: router.isShowingSettingsSheet = true
            case .profile: router.isShowingProfileSheet = true
            case .plan: router.isShowingPlanSheet = true
            case .plugins: router.isShowingPluginsSheet = true
            case .aiSettings: router.isShowingAISettingsSheet = true
            }
        }
    }

    /// 判断是否允许打开辅助窗口（个人资料/订阅/插件）——登录态守卫
    /// 抽为纯函数便于跨平台测试断言（ZhiYuTests target 不含 macOS 目录，非 macOS-only 的纯函数可直接断言）。
    static func canOpenAuxWindow(isLoggedIn: Bool, isGuest: Bool) -> Bool {
        isLoggedIn || isGuest
    }
    
    var body: some View {
        if idiom == .watch {
            watchProfileButton
        } else if idiom == .mac {
            macProfileButton
        } else {
            iosProfileMenu
        }
    }

    // MARK: - Platform Specific Menus

    private var watchProfileButton: some View {
        Button(action: { showWatchMenu = true }) {
            profileLabel
        }
        .accessibilityIdentifier("userProfileMenuButton")
        .sheet(isPresented: $showWatchMenu) {
            List {
                Button(action: { showSettings = true; showWatchMenu = false }) {
                    Label(L10n.Common.settings, systemImage: DesignTokens.Icons.settings)
                }

                Button(role: .destructive, action: { authService.logout(); showWatchMenu = false }) {
                    Label(L10n.Common.logout, systemImage: DesignTokens.Icons.logout)
                }
            }
        }
        .sheet(isPresented: $showAbout) { aboutStack }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                Text(L10n.Common.settings)
                    .navigationTitle(L10n.Common.settings)
            }
        }
    }

    private var macProfileButton: some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            isShowingPopover.toggle()
        }) {
            profileLabel
        }
        .appToolbarButtonStyle()
        .accessibilityIdentifier("userProfileMenuButton")
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            CustomProfilePopover(
                showMenuPopover: $isShowingPopover,
                onAction: { action in
                    guard UserProfileMenu.canOpenAuxWindow(
                        isLoggedIn: AuthSession.shared.isLoggedIn,
                        isGuest: AuthSession.shared.isGuest
                    ) else { return }
                    let targetId: String
                    switch action {
                    case .profile: targetId = "profile"
                    case .plan: targetId = "plan"
                    case .plugins: targetId = "plugins"
                    case .aiSettings: targetId = "ai-settings"
                    case .settings: return
                    }
                    // 互斥关闭其余已打开的头像菜单辅助窗口与设置窗口，确保同时最多只打开 1 个
                    for otherId in ProfilePopoverConstants.auxWindowIDs where otherId != targetId {
                        dismissWindow(id: otherId)
                    }
                    AppWindowHelper.closeWindows(matching: "Settings")
                    openWindow(id: targetId)
                },
                customSettingsRow: {
                    PlatformSettingsLink {
                        CustomProfilePopover<EmptyView>.menuRowLabel(
                            icon: DesignTokens.Icons.settings,
                            color: .blue,
                            title: L10n.Common.settings,
                            trailingHint: "⌘,",
                            isHovered: isHoveringMacSettingsRow
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("settingsMenuButton")
                    .onHoverIfAvailable { hovering in
                        isHoveringMacSettingsRow = hovering
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        for auxId in ProfilePopoverConstants.auxWindowIDs {
                            dismissWindow(id: auxId)
                        }
                        isShowingPopover = false
                    })
                }
            )
            .frame(width: ProfilePopoverConstants.macMenuWidth)
            .environment(authService)
            .environment(themeManager)
        }
    }

    private var iosProfileMenu: some View {
        Menu {
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                router.isShowingProfileSheet = true
            }) {
                Label(authService.currentUser?.name ?? L10n.Auth.profileAndQuota, systemImage: "person.crop.circle.fill")
            }

            Divider()

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                router.isShowingSettingsSheet = true
            }) {
                Label(L10n.Common.settings, systemImage: "gearshape.fill")
            }
            .accessibilityIdentifier("settingsMenuButton")

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                router.isShowingPlanSheet = true
            }) {
                Label(L10n.Auth.subscription, systemImage: "creditcard.fill")
            }

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                router.isShowingAISettingsSheet = true
            }) {
                Label(L10n.Settings.Section.ai, systemImage: DesignTokens.Icons.sparkles)
            }
            .accessibilityIdentifier("aiSettingsMenuButton")

            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                router.isShowingPluginsSheet = true
            }) {
                Label(L10n.Plugin.title, systemImage: "puzzlepiece.extension.fill")
            }

            Divider()

            Button(role: .destructive, action: {
                HapticFeedback.shared.trigger(.selection)
                authService.logout()
            }) {
                Label(L10n.Common.logout, systemImage: DesignTokens.Icons.logout)
            }
            .accessibilityIdentifier("logoutButton")
        } label: {
            profileLabel
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("userProfileMenuButton")
    }

    private func executeMenuAction(_ action: MenuAction) {
        action.apply(to: router)
    }
    
    private var profileLabel: some View {
        Group {
            if authService.isGuest {
                Image(systemName: DesignTokens.Icons.personCrop)
                    .font(.system(size: DesignTokens.Metrics.titleFontSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            } else {
                Image(systemName: DesignTokens.Icons.personCropFill)
                    .font(.system(size: DesignTokens.Metrics.titleFontSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .foregroundStyle(.appAccent)
        .appToolbarAdaptiveTouchTarget()
    }
    
    private var aboutStack: some View {
        NavigationStack {
            AboutView()
        }
    }
}

/// 顶层承载的个人中心 Sheet 视图内容
struct UserProfileMenuSheetContent: View {
    @Environment(AuthService.self) var authService
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @EnvironmentObject var onboardingService: OnboardingService
    @Environment(ThemeManager.self) var themeManager
    
    @Binding var isShowingPopover: Bool
    @State private var pendingMenuAction: UserProfileMenu.MenuAction?
    
    var body: some View {
        VStack(spacing: 0) {
            CustomProfilePopover(
                showMenuPopover: Binding(
                    get: { isShowingPopover },
                    set: {
                        isShowingPopover = $0
                        router.isShowingProfileMenu = $0
                    }
                ),
                onAction: { action in
                    pendingMenuAction = action
                    isShowingPopover = false
                    router.isShowingProfileMenu = false
                }
            )
        }
        .frame(width: ProfilePopoverConstants.menuWidth, height: ProfilePopoverConstants.menuHeight)
        .environment(authService)
        .environment(store)
        .environment(router)
        .environment(themeManager)
        .environmentObject(onboardingService)
        .onDisappear {
            isShowingPopover = false
            router.isShowingProfileMenu = false
            if let action = pendingMenuAction {
                pendingMenuAction = nil
                // 延迟 0.3s 执行，避开 popover dismiss 与后续 sheet present 周期冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    executeMenuAction(action)
                }
            }
        }
        .presentationCompactAdaptation(.popover)
        .presentationBackground {
            themeManager.pageBackground()
        }
    }
    
    private func executeMenuAction(_ action: UserProfileMenu.MenuAction) {
        action.apply(to: router)
    }
}

// MARK: - 自定义个人中心悬浮弹窗
@MainActor
private enum ProfilePopoverConstants {
    /// 菜单标准宽度由 CrossPlatformConstants.profilePopoverMenuWidth 统一根据设备形态提供
    static var menuWidth: CGFloat { CrossPlatformConstants.profilePopoverMenuWidth }
    static let macMenuWidth: CGFloat = 236
    static let menuHeight: CGFloat = 360
    static let iconBoxSize: CGFloat = 30
    static let auxWindowIDs: [String] = ["profile", "plan", "ai-settings", "plugins"]
}

struct CustomProfilePopover<SettingsRow: View>: View {
    @Environment(AuthService.self) var authService
    @Environment(ThemeManager.self) var themeManager
    
    @State private var showSignOutAlert = false
    @State private var hoveredRowTitle: String?

    @Binding var showMenuPopover: Bool
    var onAction: ((UserProfileMenu.MenuAction) -> Void)?
    private let customSettingsRow: (() -> SettingsRow)?

    init(
        showMenuPopover: Binding<Bool>,
        onAction: ((UserProfileMenu.MenuAction) -> Void)? = nil,
        @ViewBuilder customSettingsRow: @escaping () -> SettingsRow
    ) {
        self._showMenuPopover = showMenuPopover
        self.onAction = onAction
        self.customSettingsRow = customSettingsRow
    }

    init(
        showMenuPopover: Binding<Bool>,
        onAction: ((UserProfileMenu.MenuAction) -> Void)? = nil
    ) where SettingsRow == EmptyView {
        self._showMenuPopover = showMenuPopover
        self.onAction = onAction
        self.customSettingsRow = nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部：头像与用户信息
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onAction?(.profile)
                showMenuPopover = false
            }) {
                HStack(spacing: DesignTokens.Spacing.medium) {
                    if let url = authService.currentUser?.avatarURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.appBorder
                        }
                        .frame(width: DesignTokens.IconSize.huge, height: DesignTokens.IconSize.huge)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.appAccent)
                            .frame(width: DesignTokens.IconSize.huge, height: DesignTokens.IconSize.huge)
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
                        Text(authService.currentUser?.name ?? L10n.Auth.profileAndQuota)
                            .font(.headline)
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                        if let subText = authService.currentUser?.email {
                            Text(subText)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(DesignTokens.Spacing.medium)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            AppDivider()

            // 菜单列表（一次性完整平铺展示，防止出现滚动截断）
            VStack(spacing: DesignTokens.Spacing.tiny) {
                if let customSettingsRow {
                    customSettingsRow()
                } else {
                    menuRow(icon: "gearshape.fill", color: .blue, title: L10n.Common.settings) {
                        onAction?(.settings)
                        showMenuPopover = false
                    }
                    .accessibilityIdentifier("settingsMenuButton")
                }
                
                menuRow(icon: "creditcard.fill", color: Color(hue: 0.62, saturation: 0.65, brightness: 0.82), title: L10n.Auth.subscription) {
                    onAction?(.plan)
                    showMenuPopover = false
                }
                
                menuRow(icon: DesignTokens.Icons.sparkles, color: .purple, title: L10n.Settings.Section.ai) {
                    onAction?(.aiSettings)
                    showMenuPopover = false
                }
                .accessibilityIdentifier("aiSettingsMenuButton")
                
                menuRow(icon: "puzzlepiece.extension.fill", color: .indigo, title: L10n.Plugin.title) {
                    onAction?(.plugins)
                    showMenuPopover = false
                }
                
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.tiny)
                    .opacity(DesignTokens.Opacity.soft)
                
                menuRow(icon: DesignTokens.Icons.logout, color: .red, title: L10n.Common.logout, textColor: .red, showsChevron: false) {
                    showMenuPopover = false
                    authService.logout()
                }
                .accessibilityIdentifier("logoutButton")
            }
            .padding(DesignTokens.Spacing.small)
        }
        .frame(maxWidth: .infinity)
        .background(
            themeManager.pageBackground().ignoresSafeArea()
        )
    }
    
    static func menuRowLabel(
        icon: String,
        color: Color,
        title: String,
        textColor: Color = .appText,
        trailingHint: String? = nil,
        showsChevron: Bool = false,
        isHovered: Bool = false
    ) -> some View {
        let rowShape = RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius, style: .continuous)
        return HStack(spacing: DesignTokens.Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)
                    .fill(color.opacity(DesignTokens.Opacity.glass))
                    .frame(width: ProfilePopoverConstants.iconBoxSize, height: ProfilePopoverConstants.iconBoxSize)
                Image(systemName: icon)
                    .font(.system(size: DesignTokens.SystemFontSize.body, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(textColor)
                .lineLimit(1)
            Spacer()
            if let trailingHint {
                Text(trailingHint)
                    .font(.caption.monospaced())
                    .foregroundStyle(.appSecondary)
            } else if showsChevron {
                Image(systemName: DesignTokens.Icons.forward)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.appSecondary.opacity(DesignTokens.Opacity.soft))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Spacing.small)
        .padding(.vertical, DesignTokens.SystemSpacing.small)
        .background(
            rowShape.fill(isHovered ? Color.appAccent.opacity(DesignTokens.Opacity.glass) : Color.clear)
        )
        .contentShape(rowShape)
    }

    private func menuRow(
        icon: String,
        color: Color,
        title: String,
        textColor: Color = .appText,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredRowTitle == title
        return Button(action: {
            HapticFeedback.shared.trigger(.selection)
            action()
        }) {
            Self.menuRowLabel(
                icon: icon,
                color: color,
                title: title,
                textColor: textColor,
                showsChevron: showsChevron,
                isHovered: isHovered
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHoverIfAvailable { hovering in
            hoveredRowTitle = hovering ? title : (hoveredRowTitle == title ? nil : hoveredRowTitle)
        }
    }
}
