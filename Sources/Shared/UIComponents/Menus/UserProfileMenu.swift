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

#if targetEnvironment(macCatalyst)
import UIKit

/// Mac Catalyst 悬浮菜单窗口管理器
/// 使用独立 UIWindow 替代 UIPopoverPresentationController，避免 UIKit 转场冲突
@MainActor
final class CatalystFloatingMenuManager: NSObject {
    static let shared = CatalystFloatingMenuManager()

    private var overlayWindow: UIWindow?
    private var windowFrameTimer: Timer?

    fileprivate func show(
        onAction: @escaping (UserProfileMenu.MenuAction) -> Void,
        onDismiss: @escaping () -> Void,
        authService: AuthService,
        store: AppStore,
        router: Router,
        themeManager: ThemeManager,
        onboardingService: OnboardingService
    ) {
        dismiss {}

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first
        else { return }

        // 捕获 app 主窗口 frame（屏幕坐标系），用于将 popover 对齐 app 窗口右上角
        // 必须在创建 overlay window 之前获取，否则 keyWindow 可能指向 overlay 自身
        let appWindow = windowScene.windows.first(where: {
            !$0.isHidden && $0.windowLevel == .normal
        })
        let appWindowFrame = appWindow?.frame ?? windowScene.screen.bounds
        let screenBounds = windowScene.screen.bounds

        let content = CatalystMenuContent(
            onAction: { action in
                self.dismiss {
                    DispatchQueue.main.async {
                        onAction(action)
                    }
                }
            },
            authService: authService,
            store: store,
            router: router,
            themeManager: themeManager,
            onboardingService: onboardingService,
            appWindowFrame: appWindowFrame,
            screenBounds: screenBounds
        )

        let hosting = UIHostingController(rootView: content.ignoresSafeArea())
        hosting.view.backgroundColor = .clear

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.rootViewController = hosting
        window.backgroundColor = .clear
        // 全屏 overlay 保留用于点击外部关闭
        window.frame = screenBounds
        window.makeKeyAndVisible()

        window.alpha = 0
        UIView.animate(withDuration: 0.2) { window.alpha = 1 }

        overlayWindow = window

        // 监听 app 窗口 frame 变化：用户拖拽/缩放窗口时自动关闭菜单
        let capturedFrame = appWindowFrame
        windowFrameTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            runOnMainSync {
                let currentFrame = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first?
                    .windows.first(where: { !$0.isHidden && $0.windowLevel == .normal })?.frame ?? .zero
                if currentFrame != capturedFrame {
                    self.dismiss {}
                }
            }
        }
    }

    func dismiss(_ completion: @escaping () -> Void = {}) {
        windowFrameTimer?.invalidate()
        windowFrameTimer = nil

        guard let window = overlayWindow else {
            completion()
            return
        }
        UIView.animate(withDuration: 0.15, animations: {
            window.alpha = 0
        }, completion: { _ in
            window.isHidden = true
            self.overlayWindow = nil
            completion()
        })
    }
}

private struct CatalystMenuContent: View {
    let onAction: (UserProfileMenu.MenuAction) -> Void
    let authService: AuthService
    let store: AppStore
    let router: Router
    let themeManager: ThemeManager
    let onboardingService: OnboardingService
    let appWindowFrame: CGRect
    let screenBounds: CGRect

    var body: some View {
        let menuWidth: CGFloat = CustomProfilePopover.Constants.menuWidth
        // 工具栏区域：titlebar（~28pt）+ 工具栏（~44pt），取 60pt 使菜单出现在工具栏下方
        let toolbarVerticalOffset: CGFloat = 60

        // 动态计算 padding：将 popover 从屏幕右上角偏移到 app 窗口右上角
        // trailingPadding = 屏幕右边缘到 app 窗口右边缘的距离 + 安全间距
        let trailingPadding = max(
            DesignSystem.small,
            screenBounds.maxX - appWindowFrame.maxX + DesignSystem.small
        )
        // topPadding = app 窗口顶部到屏幕顶部的距离 + 工具栏区域偏移
        let topPadding = max(
            DesignSystem.small,
            appWindowFrame.minY + toolbarVerticalOffset
        )

        ZStack(alignment: .topTrailing) {
            // 全屏透明背景用于点击外部关闭
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { CatalystFloatingMenuManager.shared.dismiss {} }

            CustomProfilePopover(
                showMenuPopover: Binding(
                    get: { true },
                    set: { if !$0 { CatalystFloatingMenuManager.shared.dismiss {} } }
                ),
                onAction: { action in onAction(action) }
            )
            .environment(authService)
            .environment(store)
            .environment(router)
            .environmentObject(themeManager)
            .environmentObject(onboardingService)
            .frame(width: menuWidth)
            .padding(.top, topPadding)
            .padding(.trailing, trailingPadding)
        }
    }
}
#endif

struct UserProfileMenu: View {
    @Environment(AuthService.self) var authService
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @EnvironmentObject var onboardingService: OnboardingService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showWatchMenu = false
    @State private var showAbout = false
    @State private var showSettings = false
    @State private var pendingMenuAction: MenuAction?

    enum MenuAction {
        case settings, profile, plan, plugins, aiSettings
    }
    
    var body: some View {
        #if os(watchOS)
        Button(action: { showWatchMenu = true }) {
            profileLabel
        }
        .accessibilityIdentifier("userProfileMenuButton")
        .sheet(isPresented: $showWatchMenu) {
            List {
                Button(action: { showSettings = true; showWatchMenu = false }) {
                    Label(L10n.Common.settings, systemImage: DesignSystem.Icons.settings)
                }

                Button(role: .destructive, action: { authService.logout(); showWatchMenu = false }) {
                    Label(L10n.Common.logout, systemImage: DesignSystem.Icons.logout)
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
        #else
        #if targetEnvironment(macCatalyst)
        // Mac Catalyst: 使用 UIWindow 悬浮覆盖层，避开 UIPopoverPresentationController 的转场崩溃
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            CatalystFloatingMenuManager.shared.show(
                onAction: { action in pendingMenuAction = action },
                onDismiss: {},
                authService: authService,
                store: store,
                router: router,
                themeManager: themeManager,
                onboardingService: onboardingService
            )
        }) {
            profileLabel
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("userProfileMenuButton")
        .onChange(of: pendingMenuAction) { _, newValue in
            guard let action = newValue else { return }
            pendingMenuAction = nil
            DispatchQueue.main.async {
                executeMenuAction(action)
            }
        }
        #else
        // iOS/iPadOS：只返回触发按钮，不在此嵌套 sheet/popover，交由顶层 ContentView 统一调度
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            router.isShowingProfileMenu = true
        }) {
            profileLabel
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("userProfileMenuButton")
        #endif
        #endif
    }

    private func executeMenuAction(_ action: MenuAction) {
        switch action {
        case .settings: router.isShowingSettingsSheet = true
        case .profile: router.isShowingProfileSheet = true
        case .plan: router.isShowingPlanSheet = true
        case .plugins: router.isShowingPluginsSheet = true
        case .aiSettings: router.isShowingAISettingsSheet = true
        }
    }
    
    private var profileLabel: some View {
        Group {
            if authService.isGuest {
                Image(systemName: DesignSystem.Icons.personCrop)
                    .font(.system(size: DesignSystem.bodyFontSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            } else {
                Image(systemName: DesignSystem.Icons.personCropFill)
                    .font(.system(size: DesignSystem.headlineFontSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .foregroundStyle(.appAccent)
        // 1. 限制头像视觉大小为 medium 尺寸
        .frame(width: DesignSystem.IconSize.medium, height: DesignSystem.IconSize.medium)
        // 2. 使用 xlarge 框架扩展其透明外包，使其达到 HIG 推荐的 44x44 物理像素点击热区
        .frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)
        // 3. 将点击热区设为完整的正方形矩形，大幅提升边缘点击灵敏度
        .contentShape(Rectangle())
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
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var pendingMenuAction: UserProfileMenu.MenuAction?
    
    private var isUITesting: Bool {
        NSClassFromString("XCTest") != nil ||
        ProcessInfo.processInfo.arguments.contains("--uitesting") ||
        ProcessInfo.processInfo.environment["UITesting"] == "true"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: DesignSystem.medium) // 为拖拽条留出空间
            CustomProfilePopover(
                showMenuPopover: Binding(
                    get: { router.isShowingProfileMenu },
                    set: { router.isShowingProfileMenu = $0 }
                ),
                onAction: { action in
                    pendingMenuAction = action
                    router.isShowingProfileMenu = false
                }
            )
        }
        .environment(authService)
        .environment(store)
        .environment(router)
        .environmentObject(themeManager)
        .environmentObject(onboardingService)
        .onDisappear {
            if let action = pendingMenuAction {
                pendingMenuAction = nil
                // 延迟 0.5s 执行，彻底避开 UIKit Dismiss/Present 周期冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    executeMenuAction(action)
                }
            }
        }
        .presentationDetents(
            isUITesting
                ? [.large]
                : [.height(340)]
        )
        .presentationDragIndicator(.visible)
        .background(
            themeManager.pageBackground().ignoresSafeArea()
        )
    }
    
    private func executeMenuAction(_ action: UserProfileMenu.MenuAction) {
        switch action {
        case .settings: router.isShowingSettingsSheet = true
        case .profile: router.isShowingProfileSheet = true
        case .plan: router.isShowingPlanSheet = true
        case .plugins: router.isShowingPluginsSheet = true
        case .aiSettings: router.isShowingAISettingsSheet = true
        }
    }
}

// MARK: - 自定义个人中心悬浮弹窗
struct CustomProfilePopover: View {
    @Environment(AuthService.self) var authService
    @EnvironmentObject var themeManager: ThemeManager
    
    @MainActor
    fileprivate enum Constants {
        #if targetEnvironment(macCatalyst)
        /// Mac Catalyst 大屏：菜单宽度 320pt，充分利用桌面空间
        static let menuWidth: CGFloat = 320
        #elseif os(iOS)
        /// iPad 大屏：菜单宽度 300pt
        static let menuWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 300 : 240
        #else
        static let menuWidth: CGFloat = 240
        #endif
        static let iconBoxSize: CGFloat = 30
    }
    
    @State private var showSignOutAlert = false

    @Binding var showMenuPopover: Bool
    fileprivate var onAction: ((UserProfileMenu.MenuAction) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 头部：头像与用户信息
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                onAction?(.profile)
                showMenuPopover = false
            }) {
                HStack(spacing: DesignSystem.medium) {
                    if let url = authService.currentUser?.avatarURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.appBorder
                        }
                        .frame(width: DesignSystem.IconSize.huge, height: DesignSystem.IconSize.huge)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.appAccent)
                            .frame(width: DesignSystem.IconSize.huge, height: DesignSystem.IconSize.huge)
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
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
                .padding(DesignSystem.medium)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            AppDivider()

            // 菜单列表
            ScrollView {
                VStack(spacing: DesignSystem.small) {
                    menuRow(icon: "gearshape.fill", color: .blue, title: L10n.Common.settings) {
                        onAction?(.settings)
                        showMenuPopover = false
                    }
                    .accessibilityIdentifier("settingsMenuButton")
                    
                    menuRow(icon: "creditcard.fill", color: Color(hue: 0.62, saturation: 0.65, brightness: 0.82), title: L10n.Auth.subscription) {
                        onAction?(.plan)
                        showMenuPopover = false
                    }
                    
                    menuRow(icon: DesignSystem.Icons.sparkles, color: .purple, title: L10n.Settings.Section.ai) {
                        onAction?(.aiSettings)
                        showMenuPopover = false
                    }
                    .accessibilityIdentifier("aiSettingsMenuButton")
                    
                    menuRow(icon: "puzzlepiece.extension.fill", color: .indigo, title: L10n.Plugin.title) {
                        onAction?(.plugins)
                        showMenuPopover = false
                    }
                    
                    Divider()
                        .padding(.vertical, DesignSystem.tiny)
                        .opacity(DesignSystem.Opacity.soft)
                    
                    menuRow(icon: DesignSystem.Icons.logout, color: .red, title: L10n.Common.logout, textColor: .red) {
                        showMenuPopover = false
                        authService.logout()
                    }
                    .accessibilityIdentifier("logoutButton")
                }
                .padding(DesignSystem.small)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            themeManager.pageBackground().ignoresSafeArea()
        )
    }
    
    private func menuRow(icon: String, color: Color, title: String, textColor: Color = .appText, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            action()
        }) {
            HStack(spacing: DesignSystem.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                        .fill(color.opacity(DesignSystem.Opacity.glass))
                        .frame(width: Constants.iconBoxSize, height: Constants.iconBoxSize)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold)) // Dynamic Type
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.small)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
