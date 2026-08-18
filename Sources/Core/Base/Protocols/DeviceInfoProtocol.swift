//
//  DeviceInfoProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义设备信息获取的跨平台协议，屏蔽 UIDevice/NSScreen/WKInterfaceDevice 的 API 差异。

import Foundation
import Dependencies
import UFPCore

/// 设备信息协议
public protocol DeviceInfoProtocol: Sendable {
    /// 操作系统版本号，如 "17.4"
    var systemVersion: String { get }
    /// 设备型号名称，如 "iPhone 15 Pro"
    var deviceModel: String { get }
    /// 设备用户自定义名称，如 "我的 iPhone"
    var deviceName: String { get }
    /// 主屏幕逻辑尺寸高度（pt），watchOS/macOS 返回合理默认值
    var screenHeight: CGFloat { get }
}

// MARK: - DependencyKey 注册

/// DeviceInfoProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum DeviceInfoKey: DependencyKey {
    public static var liveValue: any DeviceInfoProtocol {
        ServiceContainer.shared.resolve((any DeviceInfoProtocol).self)
    }

    public static var testValue: any DeviceInfoProtocol {
        ServiceContainer.shared.resolveOptional((any DeviceInfoProtocol).self) ?? NoOpDeviceInfo()
    }
}

/// 无操作设备信息服务（测试/预览占位，DI 未就绪时降级）
public final class NoOpDeviceInfo: DeviceInfoProtocol, @unchecked Sendable {
    public init() {}
    public var systemVersion: String { "" }
    public var deviceModel: String { "" }
    public var deviceName: String { "" }
    public var screenHeight: CGFloat { 0 }
}

extension DependencyValues {
    /// 设备信息服务依赖
    public var deviceInfo: any DeviceInfoProtocol {
        get { self[DeviceInfoKey.self] }
        set { self[DeviceInfoKey.self] = newValue }
    }
}
