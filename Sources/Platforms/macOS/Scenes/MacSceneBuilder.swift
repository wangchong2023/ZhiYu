//
//  MacSceneBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 场景根构建器（主窗口 + Settings + 辅助窗口），对齐任务 2 计划占位。
//
import SwiftUI
import AppKit
import UFPCore
import UFPDesignSystem

/// macOS 场景构建器：主窗口、Settings 与辅助窗口的统一场景出口
@MainActor
enum MacSceneBuilder {
    /// 将应用级 NSApp.appearance 与 ThemeManager.colorSchemeMode 保持同步，
    /// 避免系统为浅色模式、应用为深色模式时，新打开的辅助窗口（如个人信息、设置）先闪浅色再渐变深色。
    private static func syncAppAppearance(with mode: ColorSchemeMode) {
        switch mode {
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        case .system:
            NSApp?.appearance = nil
        }
    }

    /// 主窗口：承载 MacMainWindow 外壳 + 依赖注入 + MacMenuCommands 菜单命令
    @SceneBuilder
    static func main(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService
    ) -> some Scene {
        WindowGroup(L10n.Common.appName, id: "main") {
            MacMainWindow()
                .frame(
                    minWidth: DesignTokens.Metrics.minWindowWidth,
                    minHeight: DesignTokens.Metrics.minWindowHeight
                )
                .modifier(SceneEnvironmentInjection(
                    appEnv: appEnv, appModel: appModel, dependencies: dependencies,
                    themeManager: themeManager, onboardingService: onboardingService
                ))
                .onAppear {
                    syncAppAppearance(with: themeManager.colorSchemeMode)
                }
                .onChange(of: themeManager.colorSchemeModeRaw) { _, _ in
                    syncAppAppearance(with: themeManager.colorSchemeMode)
                }
        }
        .defaultSize(
            width: DesignTokens.Metrics.macMainWindowWidth,
            height: DesignTokens.Metrics.macMainWindowHeight
        )
        .commands { MacMenuCommands() }
    }

    /// 设置窗口：复用 SettingsView 的 .mac 分支（sidebarColumn + detailColumn 布局）
    static func settings(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService
    ) -> some Scene {
        Settings {
            MacSettingsView()
                .frame(
                    width: DesignTokens.Metrics.macSettingsWindowWidth,
                    height: DesignTokens.Metrics.macSettingsWindowHeight
                )
                .modifier(MacAuxiliaryWindowCentering(hidesTitlebarText: true))
                .modifier(SceneEnvironmentInjection(
                    appEnv: appEnv, appModel: appModel, dependencies: dependencies,
                    themeManager: themeManager, onboardingService: onboardingService
                ))
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .defaultPosition(.center)
    }

    /// 辅助窗口：个人资料、订阅计划、插件中心、笔记本中心
    /// 每个窗口根视图必须包裹 SceneEnvironmentInjection，否则打开窗口时读取缺失的
    /// @Environment(AuthService.self) 等会触发 AttributeGraph fatal crash。
    /// 统一配置 .defaultSize、.defaultPosition(.center) 与相对主窗口居中，避免弹窗位置漂移。
    @SceneBuilder
    static func windows(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService
    ) -> some Scene {
        let injection = SceneEnvironmentInjection(
            appEnv: appEnv, appModel: appModel, dependencies: dependencies,
            themeManager: themeManager, onboardingService: onboardingService
        )
        auxiliaryWindow(
            title: L10n.Auth.profileAndQuota, id: "profile",
            width: DesignTokens.Metrics.macProfileWindowWidth,
            height: DesignTokens.Metrics.macProfileWindowHeight,
            injection: injection
        ) { UserProfileView() }

        auxiliaryWindow(
            title: L10n.Auth.subscription, id: "plan",
            width: DesignTokens.Metrics.macPlanWindowWidth,
            height: DesignTokens.Metrics.macPlanWindowHeight,
            injection: injection
        ) { SubscriptionPlanView() }

        auxiliaryWindow(
            title: L10n.Settings.Section.ai, id: "ai-settings",
            width: DesignTokens.Metrics.macSettingsWindowWidth,
            height: DesignTokens.Metrics.macSettingsWindowHeight,
            injection: injection
        ) { AISettingsView(showsDismissButton: false, usesEmbeddedBackground: false) }

        auxiliaryWindow(
            title: L10n.Plugin.title, id: "plugins",
            width: DesignTokens.Metrics.macPluginsWindowWidth,
            height: DesignTokens.Metrics.macPluginsWindowHeight,
            injection: injection
        ) { PluginCenterView() }

        auxiliaryWindow(
            title: L10n.Vault.homeTitle, id: "notebook-hub",
            width: DesignTokens.Metrics.macNotebookHubWindowWidth,
            height: DesignTokens.Metrics.macNotebookHubWindowHeight,
            minWidth: DesignTokens.Metrics.minWindowWidth,
            injection: injection
        ) { NotebookHubView() }
    }

    private static func auxiliaryWindow<Content: View>(
        title: String,
        id: String,
        width: CGFloat,
        height: CGFloat,
        minWidth: CGFloat? = nil,
        injection: SceneEnvironmentInjection,
        @ViewBuilder content: @escaping () -> Content
    ) -> some Scene {
        Window(title, id: id) {
            content()
                .frame(minWidth: minWidth ?? width, minHeight: height)
                .modifier(MacAuxiliaryWindowCentering())
                .modifier(injection)
        }
        .defaultSize(width: width, height: height)
        .defaultPosition(.center)
    }
}

// MARK: - 辅助窗口相对主窗口居中定位

/// 确保 macOS 辅助窗口每次打开时精准居中于主窗口（或屏幕）中央，消除系统级联偏移导致的漂移感。
private struct MacAuxiliaryWindowCentering: ViewModifier {
    var hidesTitlebarText: Bool = false

    func body(content: Content) -> some View {
        content.background(MacWindowCenteringAnchor(hidesTitlebarText: hidesTitlebarText))
    }
}

private struct MacWindowCenteringAnchor: NSViewRepresentable {
    var hidesTitlebarText: Bool = false

    func makeNSView(context: Context) -> CenteringNSView {
        let view = CenteringNSView()
        view.hidesTitlebarText = hidesTitlebarText
        return view
    }

    func updateNSView(_ nsView: CenteringNSView, context: Context) {
        nsView.hidesTitlebarText = hidesTitlebarText
    }

    final class CenteringNSView: NSView {
        private var hasCentered = false
        var hidesTitlebarText = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let targetWindow = window, !hasCentered else { return }
            hasCentered = true
            DispatchQueue.main.async { [hidesTitlebarText] in
                targetWindow.toolbarStyle = .unified
                if hidesTitlebarText {
                    targetWindow.titleVisibility = .hidden
                    targetWindow.titlebarAppearsTransparent = true
                }
                Self.center(window: targetWindow)
            }
        }

        private static func center(window targetWindow: NSWindow) {
            if let anchorWindow = NSApp?.windows.first(where: {
                $0 !== targetWindow && $0.isVisible && $0.canBecomeMain
            }) {
                let anchorFrame = anchorWindow.frame
                let targetSize = targetWindow.frame.size
                let originX = anchorFrame.midX - targetSize.width / 2
                let originY = anchorFrame.midY - targetSize.height / 2
                targetWindow.setFrameOrigin(NSPoint(x: originX, y: originY))
            } else {
                targetWindow.center()
            }
        }
    }
}
