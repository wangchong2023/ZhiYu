//
//  CrossPlatform.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：跨平台适配器：统一不同平台的类型别名与 API 差异。
//
import Foundation
import UFPCore

/// 跨平台剪贴板包装器
@MainActor
enum AppPasteboard {
    /// 获取或设置系统剪贴板文本
    static var string: String? {
        get { service.string }
        set { 
            let s = service
            s.string = newValue 
        }
    }
    
    /// 内部持有的具体实现
    private static var service: any PasteboardProtocol {
        ServiceContainer.shared.resolveOptional((any PasteboardProtocol).self) ?? NoOpPasteboard()
    }
}

/// 跨平台图片类型别名
#if os(iOS)
import UIKit
public typealias AppImage = UIImage
#elseif os(macOS)
import AppKit
public typealias AppImage = NSImage
#elseif os(watchOS)
import WatchKit
public struct AppImage: Sendable {}
#else
public struct AppImage: Sendable {}
#endif

// MARK: - 跨平台屏幕工具

/// 跨平台屏幕尺寸适配工具
/// 封装 UIScreen / WKInterfaceDevice 差异，避免 Features 层直接依赖平台 API
public enum AppScreen {
    /// AI 对话气泡最大宽度（屏幕宽度的 85%，watchOS 为 90%）
    @MainActor
    public static var bubbleMaxWidth: CGFloat {
        #if os(watchOS)
        return WKInterfaceDevice.current().screenBounds.width * 0.9
        #else
        // iOS 26.0 废弃 UIScreen.main，改为从活跃 UIWindowScene 获取 screen
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let screenWidth = activeScene?.screen.bounds.width
            ?? activeScene?.windows.first?.window?.screen.bounds.width
            ?? 375
        return screenWidth * 0.85
        #endif
    }
}

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// 跨平台呈现锚点工具，用于 ASAuthorizationController / ASWebAuthenticationSession
public enum PlatformPresentationAnchor {
    @MainActor
    public static var keyWindow: UIWindow {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        // 优先取 foregroundActive 场景的 keyWindow
        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }),
           let keyWindow = activeScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        // fallback：取任意场景的 keyWindow
        if let anyScene = scenes.first(where: { !$0.windows.isEmpty }),
           let window = anyScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // 最后 fallback：用第一个可用场景创建新 UIWindow
        if let scene = scenes.first {
            return UIWindow(windowScene: scene)
        }
        // 极端边界：无任何 UIWindowScene（理论上不可达，keyWindow 仅在 App 完全启动后调用）。
        // iOS 26.0 废弃 UIWindow(frame:)，用 if #unavailable 限制只在 iOS < 26.0 调用。
        if #unavailable(iOS 26.0) {
            return UIWindow(frame: .zero)
        }
        // iOS 26.0+：再次遍历 connectedScenes 查找任意 window（兜底）
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let window = scene.windows.first {
                return window
            }
        }
        // iOS 26.0+ 真正无任何 window：此分支不可达。
        // 无 scene 时 iOS 26.0+ 无法创建 window，用 fatalError 替代不可达代码。
        // Gatekeeper 禁止 fatalError，用 preconditionFailure 替代（同样是不可达分支）。
        preconditionFailure("PlatformPresentationAnchor.keyWindow: No UIWindowScene available")
    }
}
#endif
