//
//  iOSShareSheetService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台系统分享面板实现，封装 UIActivityViewController。

#if os(iOS) && !os(watchOS)
import UIKit

/// iOS 系统分享面板服务
@MainActor
// swiftlint:disable:next redundant_sendable
final class iOSShareSheetService: ShareSheetProtocol, Sendable {
    func presentShareSheet(items: [Any]) async {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let keyWindow = scene.keyWindow,
              let root = keyWindow.rootViewController else {
            return
        }

        // 递归查找顶层 UIViewController
        var topVC = root
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // 适配 iPad 弹窗避免崩溃
        if let popover = controller.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topVC.present(controller, animated: true)
    }
}
#endif
