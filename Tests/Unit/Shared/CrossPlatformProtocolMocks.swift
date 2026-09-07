//
//  CrossPlatformProtocolMocks.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：为 DeviceInfoProtocol / URLOpenerProtocol / ShareSheetProtocol 提供 Mock 实现，
//          支持业务层单元测试脱离真实平台 API 依赖。
//

import Foundation
#if os(watchOS)
@testable import ZhiYuWatch
#else
@testable import ZhiYu
#endif

// MARK: - Mock DeviceInfoService

/// 模拟设备信息服务，返回固定测试值，用于业务层验证设备信息展示逻辑
final class MockDeviceInfoService: DeviceInfoProtocol, @unchecked Sendable {
    var systemVersion: String
    var deviceModel: String
    var deviceName: String
    var screenHeight: CGFloat

    /// 创建 Mock 设备信息服务
    /// - Parameters:
    ///   - systemVersion: 模拟系统版本，默认 "17.4"
    ///   - deviceModel: 模拟设备型号，默认 "iPhone 15 Pro Mock"
    ///   - deviceName: 模拟设备名称，默认 "Test Device"
    ///   - screenHeight: 模拟屏幕高度，默认 852 pt
    init(
        systemVersion: String = "17.4",
        deviceModel: String = "iPhone 15 Pro Mock",
        deviceName: String = "Test Device",
        screenHeight: CGFloat = 852
    ) {
        self.systemVersion = systemVersion
        self.deviceModel = deviceModel
        self.deviceName = deviceName
        self.screenHeight = screenHeight
    }
}

// MARK: - Mock URLOpenerService

/// 模拟 URL 打开器服务，记录被调用的 URL 而不实际执行系统打开操作，
/// 支持业务层验证 URL 跳转逻辑的正确性
final class MockURLOpenerService: URLOpenerProtocol, @unchecked Sendable {
    /// 按调用顺序记录的所有被打开的 URL
    private(set) var openedURLs: [URL] = []

    /// 最近一次被调用的 URL，未调用过则为 nil
    var lastOpenedURL: URL? {
        openedURLs.last
    }

    /// 是否至少调用过一次
    var wasCalled: Bool {
        !openedURLs.isEmpty
    }

    /// 模拟打开 URL（仅记录，不实际打开系统浏览器）
    func open(_ url: URL) async {
        openedURLs.append(url)
    }
}

// MARK: - Mock ShareSheetService

/// 模拟系统分享面板服务，记录被分享的 items 而不实际弹出系统面板，
/// 支持业务层验证分享内容构造逻辑的正确性
final class MockShareSheetService: ShareSheetProtocol, @unchecked Sendable {
    /// 按调用顺序记录的所有分享批次，每批是一个 items 数组
    private(set) var sharedBatches: [[Any]] = []

    /// 最近一次被分享的 items 数组，未调用过则为 nil
    var lastSharedItems: [Any]? {
        sharedBatches.last
    }

    /// 是否至少调用过一次
    var wasCalled: Bool {
        !sharedBatches.isEmpty
    }

    /// 模拟弹出分享面板（仅记录 items，不实际弹出 UI）
    func presentShareSheet(items: [Any]) async {
        sharedBatches.append(items)
    }
}
