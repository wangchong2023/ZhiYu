//
//  TestWindowHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：为单元测试提供 UIWindow 创建工具，避免 iOS 26 废弃的 init(frame:)。
//

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// 测试专用 UIWindow 工厂
///
/// iOS 26 废弃了 `UIWindow(frame:)`，建议使用 `UIWindow(windowScene:)`。
/// 本工具优先从 `UIApplication.shared.connectedScenes` 获取 windowScene，
/// 若无可用 scene（单元测试环境常见），则回退到 `init(frame:)` 并抑制废弃警告。
@MainActor
enum TestWindowFactory {

    /// 创建测试用 UIWindow
    ///
    /// - Parameter frame: 窗口 frame，默认 iPhone 14 Pro 尺寸
    /// - Returns: 已配置的 UIWindow
    @discardableResult
    static func makeWindow(
        frame: CGRect = CGRect(x: 0, y: 0, width: 393, height: 852)
    ) -> UIWindow {
        // 优先使用 connectedScenes 中的 windowScene（iOS 13+）
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            let window = UIWindow(windowScene: scene)
            window.frame = frame
            return window
        }

        // 回退：无可用 scene 时使用 init(frame:)，抑制 iOS 26 废弃警告
        // 单元测试环境通常无 connectedScenes，此回退是必要的
        let window = UIWindow(frame: frame)
        return window
    }
}
#endif
