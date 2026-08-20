//
//  WatchDeviceInfoService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：watchOS 平台设备信息获取实现，封装 WKInterfaceDevice API。

#if os(watchOS)
import WatchKit

/// watchOS 设备信息服务
final class WatchDeviceInfoService: DeviceInfoProtocol, Sendable {
    var systemVersion: String {
        WKInterfaceDevice.current().systemVersion
    }

    var deviceModel: String {
        WKInterfaceDevice.current().model
    }

    var deviceName: String {
        WKInterfaceDevice.current().name
    }

    var screenHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.height
    }
}
#endif // os(watchOS)
