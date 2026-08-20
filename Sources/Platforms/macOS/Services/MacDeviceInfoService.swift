//
//  MacDeviceInfoService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：macOS 平台设备信息获取实现，封装 ProcessInfo / NSScreen API。

#if os(macOS)
import AppKit
import Foundation

/// macOS 设备信息服务
final class MacDeviceInfoService: DeviceInfoProtocol, Sendable {
    var systemVersion: String {
        let osv = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osv.majorVersion).\(osv.minorVersion).\(osv.patchVersion)"
    }

    var deviceModel: String {
        "Mac"
    }

    var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }

    var screenHeight: CGFloat {
        NSScreen.main?.frame.height ?? 900
    }
}
#endif
