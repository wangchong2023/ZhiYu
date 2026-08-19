//
//  AppWindowSceneDelegate.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：App 模块的 AppWindowSceneDelegate 实现。
//
#if !os(watchOS)
import SwiftUI
import UFPCore
import UIKit

// MARK: - 场景代理（多窗口支持）
@available(iOS 16.0, macCatalyst 16.0, *)
class AppWindowSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    /// scene
    /// - Parameter scene: scene
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let themeManager = ThemeManager()
        let store: AppStore = ServiceContainer.shared.resolve(AppStore.self) // inject_exempt: DI 初始化代码
        let llmService: LLMService = ServiceContainer.shared.resolve(LLMService.self) // inject_exempt: DI 初始化代码

        let contentView = ContentView()
            .environment(store)
            .environment(themeManager)
            .environmentObject(llmService)
            .tint(themeManager.accentColor)

        window.rootViewController = UIHostingController(rootView: AnyView(contentView))
        self.window = window
        window.makeKeyAndVisible()

        #if targetEnvironment(macCatalyst)
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        #endif
    }

    /// sceneDid断开
    /// - Parameter scene: scene
    func sceneDidDisconnect(_ scene: UIScene) {}

    /// sceneDidBecomeActive
    /// - Parameter scene: scene
    func sceneDidBecomeActive(_ scene: UIScene) {}

    /// sceneWillResignActive
    /// - Parameter scene: scene
    func sceneWillResignActive(_ scene: UIScene) {}

    /// sceneWillEnterForeground
    /// - Parameter scene: scene
    func sceneWillEnterForeground(_ scene: UIScene) {}

    /// sceneDidEnterBackground
    /// - Parameter scene: scene
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
#endif
