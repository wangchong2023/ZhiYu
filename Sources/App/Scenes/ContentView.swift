//
//  ContentView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：构建 Content 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore

/// 应用程序根视图
/// 负责全局导航分发（Tab/SplitView）、安全遮罩及全局弹窗调度
@MainActor
struct ContentView: View {
    // MARK: - Environment & Dependencies
    @Environment(AppStore.self) var store
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(Router.self) var router
    @Environment(AuthService.self) var authService
    @Environment(VaultService.self) var vaultService
    @Environment(AppEnvironment.self) var appEnvironment
    @Environment(SettingsStore.self) var settingsStore
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject internal var tooltipManager = TooltipManager.shared
    @State internal var showCommandPalette = false
    @Namespace internal var heroNamespace
    @EnvironmentObject var onboardingService: OnboardingService
    @EnvironmentObject var medalService: MedalService
    
    @Inject internal var deepLinkService: DeepLinkService
    @Inject internal var appEnv: any AppEnvironmentProtocol
    
    @State internal var showSidebar = false 
    @State internal var authSession = AuthSession.shared
    @State private var dbState: DatabaseState = DatabaseManager.shared.state

    // MARK: - Body
    var body: some View {
        @Bindable var store = store
        @Bindable var router = router
        let tintColor = themeManager.accentColor
        
        ZStack {
            // 背景层
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            // 主内容层
            mainContainer(tintColor: tintColor)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name.toggleSidebar)) { _ in
                    withAnimation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping)) {
                        showSidebar.toggle()
                    }
                }
            
            // 数据库损坏或降级警告横幅
            VStack {
                if case .corrupted(let errorMsg) = dbState {
                    DatabaseCorruptedBanner(errorMessage: errorMsg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(DesignSystem.ZIndex.lockOverlay - 1)
                }
                Spacer()
            }
            
            // iPhone 侧边栏抽屉层 (Compact Size Class Only)
            if showSidebar && appEnv.screenClass == .compact {
                sidebarOverlayLayer
            }
            
            // 全局新手引导蒙层：确保在工作台及主界面均能正常展示与交互
            OnboardingOverlay(service: onboardingService)
            
            // 全局安全锁定覆盖层：覆盖所有笔记本及工作台视图
            if store.securityService.isLocked {
                LockOverlayView()
                    .transition(AnyTransition.opacity.combined(with: .scale(scale: 1.0 * DesignSystem.Metrics.lockOverlayScaleMultiplier)))
                    .zIndex(DesignSystem.ZIndex.lockOverlay)
            }
        }
        .fullScreenCover(isPresented: $router.isShowingSettingsSheet) {
            SettingsView()
                .environment(store)
                .environment(router)
                .environment(appEnvironment)
                .environment(settingsStore)
                .environmentObject(onboardingService)
                .environmentObject(themeManager)
                .environment(\.locale, router.currentLocale)
                .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
        }
        .fullScreenCover(isPresented: $router.isShowingAISettingsSheet) {
            NavigationStack {
                AISettingsView()
            }
            .environment(store)
            .environment(router)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
            .applyPagePresentationSizing()
        }

        .fullScreenCover(isPresented: $router.isShowingProfileSheet) {
            NavigationStack {
                UserProfileView()
            }
            .environment(authService)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
            .applyPresentationSizing()
        }
        .fullScreenCover(isPresented: $router.isShowingPlanSheet) {
            NavigationStack {
                SubscriptionPlanView()
            }
            .environment(authService)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
            .applyPagePresentationSizing()
        }
        .fullScreenCover(isPresented: $router.isShowingPluginsSheet) {
            NavigationStack {
                PluginCenterView()
            }
            .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
            .applyPagePresentationSizing()
        }
        .fullScreenCover(isPresented: $router.isShowingAboutSheet) {
            NavigationStack {
                AboutView()
            }
            .environment(store)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
            .applyPresentationSizing()
        }
        .animation(DesignSystem.Animation.Config.prominentSpring, value: authSession.isLoggedIn || authSession.isGuest)
        .animation(DesignSystem.Animation.Config.prominentSpring, value: vaultService.selectedVaultID)
        .environmentObject(MedalService.shared)
        .environment(\.locale, router.currentLocale)
        .onReceive(NotificationCenter.default.publisher(for: .databaseStateDidChange)) { _ in
            withAnimation(.spring()) {
                dbState = DatabaseManager.shared.state
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userAuthExpired)) { _ in
            // 收到 Token 彻底过期失效广播，安全强制登出并清空本地状态，平滑切回登录页
            authService.logout()
        }
        .onAppear {
            // 🎬 正常应用启动时，若处于未登录状态且非游客模式且非 UI 测试环境，自动尝试恢复本地 KeyChain Token 并登录
            let isTesting = ProcessInfo.processInfo.environment["UITesting"] == "true" ||
                            ProcessInfo.processInfo.arguments.contains("--uitesting")
            if !authSession.isLoggedIn && !authSession.isGuest && !isTesting {
                Task {
                    _ = await authService.tryAutoLogin()
                }
            }
            
            #if targetEnvironment(macCatalyst)
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    windowScene.titlebar?.titleVisibility = .hidden
                    windowScene.titlebar?.toolbar = nil
                }
            }
            #endif
        }
    }
    
    // MARK: - Sub-layers
    
    @ViewBuilder
    private var sidebarOverlayLayer: some View {
        Color.theme.black.opacity(DesignSystem.dimmedOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(DesignSystem.Animation.Config.prominentSpring) {
                    showSidebar = false
                }
            }
            .transition(.opacity)
        
        HStack {
            SidebarView(heroNamespace: heroNamespace)
                .frame(width: DesignSystem.Sidebar.width)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous))
                .shadow(color: .primary.opacity(DesignSystem.shadowOpacity), radius: DesignSystem.shadowRadius)
                .padding(.vertical, DesignSystem.Layout.sidebarOverlayVerticalPadding)
                .padding(.leading, DesignSystem.medium)
            Spacer()
        }
        .transition(.move(edge: .leading))
        .zIndex(DesignSystem.ZIndex.sidebarOverlay)
    }
}

#Preview {
    ContentView()
        .environment(AppStore())
        .environmentObject(ThemeManager())
}

// MARK: - View Extension for Compatibility

extension View {
    /// 标准弹窗尺寸适配修饰符（中等内容，如用户资料、订阅计划）
    /// 在 iPad/Mac 大屏使用 `.form` 级别尺寸（约 540×680pt）
    @ViewBuilder
    func applyPresentationSizing() -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            self.presentationSizing(.form)
        } else {
            self
                .frame(minWidth: 540, minHeight: 680)
                .presentationDetents([.large])
        }
        #else
        self.frame(minWidth: 540, minHeight: 680)
        #endif
    }

    /// 大页面弹窗尺寸适配修饰符（内容丰富页面，如插件中心、开发者设置）
    /// 在 iPad/Mac 大屏使用 `.page` 级别尺寸，充分利用可用空间
    @ViewBuilder
    func applyPagePresentationSizing() -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            // iOS 18+ 使用 .page 撑满更大区域，比 .form 更宽更高
            self
                .presentationSizing(.page)
                .presentationDetents([.large])
        } else {
            // iOS 17 及以下：设定足够大的最小尺寸以近似 .page 效果
            self
                .frame(minWidth: 680, minHeight: 780)
                .presentationDetents([.large])
        }
        #else
        // macOS Catalyst：固定宽高以适配桌面窗口比例
        self.frame(minWidth: 720, minHeight: 820)
        #endif
    }
    
    /// 设置页面专用的自适应宽屏弹窗尺寸修饰符
    /// - Parameter screenClass: 屏幕类型
    @ViewBuilder

    /// 应用SettingsPresentationSizing
    /// - Parameter screenClass: screenClass
    func applySettingsPresentationSizing(screenClass: ScreenClass) -> some View {
        if screenClass == .compact {
            // 手机/紧凑尺寸下，不做多余限制，让系统自动以标准半屏/全屏形式拉起
            self
        } else {
            // iPad 与 Mac 大屏下，差异化控制尺寸，为双栏左右分栏提供完美的自适应呈现空间
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst 运行模式下，指定适合 macOS 系统的固定宽屏尺寸
            self.frame(width: DesignSystem.Metrics.minWindowWidth, height: DesignSystem.Metrics.minWindowHeight)
            #else
            // iPad 设备运行模式下：防止强设 minWidth 导致系统默认的 sheet 内容发生截断。
            if #available(iOS 18.0, *) {
                // iOS 18+ 利用 .page 级别的大宽度撑开 sheet，使其直接展开为双栏，消除多一级菜单的体验
                self
                    .presentationSizing(.page)
                    .presentationDetents([.large])
            } else {
                // iOS 17 及以下低版本：为了防止内容被截断，不设大宽度 minWidth，让 NavigationSplitView 在窄屏下优雅自适应为单栏折叠
                self
                    .frame(minHeight: 650)
                    .presentationDetents([.large])
            }
            #endif
        }
    }
}

// MARK: - 数据库异常 Banner 视图

/// 数据库损坏/降级只读内存模式的警告 Banner 组件
struct DatabaseCorruptedBanner: View {
    /// 异常错误信息
    let errorMessage: String
    
    /// 状态控制：是否正在重新验证中
    @State private var isRetrying = false
    /// 状态控制：是否展示详细的报错堆栈
    @State private var showDetail = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // 安全警告图标
                Image(systemName: DesignSystem.Icons.exclamationShieldFill)
                    .font(.title3)
                    .foregroundColor(.theme.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    // 主警告文案 (从强类型本地化 L10n 中拉取)
                    Text(L10n.Security.databaseCorrupted)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // 可选折叠的物理错误堆栈详情
                    if showDetail {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.theme.red)
                            .padding(.top, 2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // 动作按钮组
                HStack(spacing: 12) {
                    // 折叠切换按钮
                    Button(action: {
                        withAnimation {
                            showDetail.toggle()
                        }
                    }) {
                        Image(systemName: showDetail ? DesignSystem.Icons.chevronUp : DesignSystem.Icons.chevronDown)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    // 重新验证物理库连接按钮
                    Button(action: {
                        triggerReverification()
                    }) {
                        if isRetrying {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(L10n.Security.retryConnection)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.theme.orange))
                                .foregroundColor(.theme.white)
                        }
                    }
                    .disabled(isRetrying)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .primary.opacity(DesignSystem.Opacity.subtle), radius: 6, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                    .stroke(Color.theme.orange.opacity(DesignSystem.Opacity.shadow), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    /// 触发重新挂载与完整性校验逻辑
    private func triggerReverification() {
        isRetrying = true
        Task {
            do {
                guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw NSError(domain: "Insight", code: -1) }
                let dbURL = appSupport.appendingPathComponent(AppConstants.Storage.databaseName)
                
                // 重新执行 setup 挂载物理沙盒
                try DatabaseManager.shared.setup(at: dbURL)
                Logger.shared.info("[DatabaseCorruptedBanner] Reverification succeeded! Remounted physical database.")
            } catch {
                Logger.shared.error("[DatabaseCorruptedBanner] Reverification" + " failed: \(error)", error: error)
            }
            isRetrying = false
        }
    }
}
