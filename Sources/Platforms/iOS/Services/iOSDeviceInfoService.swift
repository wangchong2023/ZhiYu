//
//  iOSDeviceInfoService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台设备信息获取实现，封装 UIDevice / UIScreen API。

#if os(iOS) && !os(watchOS)
import UIKit
import UFPCore

/// iOS 设备信息服务
final class iOSDeviceInfoService: DeviceInfoProtocol, Sendable {
    var systemVersion: String {
        runOnMainSync { UIDevice.current.systemVersion }
    }

    var deviceModel: String {
        runOnMainSync { UIDevice.current.model }
    }

    var deviceName: String {
        runOnMainSync { UIDevice.current.name }
    }

    var screenHeight: CGFloat {
        // iOS 26.0 废弃 UIScreen.main，改为从活跃 UIWindowScene 获取 screen
        // 测试环境（无 Host App）无 foregroundActive 场景，回退到 UIScreen.main
        runOnMainSync {
            let activeScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            if let scene = activeScene {
                return scene.screen.bounds.height
            }
            if let window = activeScene?.windows.first {
                return window.screen.bounds.height
            }
            // 测试环境回退到 UIScreen.main（iOS 26 废弃但测试环境仍可用）
            return UIScreen.main.bounds.height
        }
    }
}

#endif
