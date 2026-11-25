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
import Dependencies

/// macOS 设备信息服务
struct MacDeviceInfoService: DeviceInfoProtocol, Sendable {
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?

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

    var deviceId: String {
        let key = "com.zhiyu.mac.deviceId"
        if let existing = keyStore?.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newID = UUID().uuidString
        keyStore?.set(newID, forKey: key)
        return newID
    }

    var screenHeight: CGFloat {
        NSScreen.main?.frame.height ?? 900
    }
}
#endif
