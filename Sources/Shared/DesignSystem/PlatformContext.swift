//
//  PlatformContext.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：平台上下文动态感知，解耦多端（iPhone/iPad/Mac/Watch）设计 Token 差异。
//

import SwiftUI

/// 平台设备家族枚举
public enum PlatformDeviceFamily: String, Sendable, Codable, CaseIterable {
    case phone
    case pad
    case mac
    case watch
}

/// 平台运行时上下文结构体
public struct PlatformContext: Sendable, Equatable {
    /// 设备家族
    public let deviceFamily: PlatformDeviceFamily
    /// 是否为触控优先设备 (Phone/Pad/Watch 为 true, Mac 为 false)
    public let isTouchOptimized: Bool
    /// 屏幕尺寸级别
    public let screenClass: ScreenClass
    
    public init(
        deviceFamily: PlatformDeviceFamily,
        isTouchOptimized: Bool,
        screenClass: ScreenClass = .regular
    ) {
        self.deviceFamily = deviceFamily
        self.isTouchOptimized = isTouchOptimized
        self.screenClass = screenClass
    }
    
    /// 当前运行平台的默认 Context
    public static var current: PlatformContext {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return PlatformContext(
            deviceFamily: .mac,
            isTouchOptimized: false,
            screenClass: .expansive
        )
        #elseif os(watchOS)
        return PlatformContext(
            deviceFamily: .watch,
            isTouchOptimized: true,
            screenClass: .compact
        )
        #else
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return PlatformContext(
            deviceFamily: isPad ? .pad : .phone,
            isTouchOptimized: true,
            screenClass: isPad ? .regular : .compact
        )
        #endif
    }
}

// MARK: - SwiftUI Environment 注入支持

private struct PlatformContextEnvironmentKey: EnvironmentKey {
    static let defaultValue: PlatformContext = .current
}

extension EnvironmentValues {
    /// SwiftUI 视图树中的平台上下文 Token 环境变量
    public var platformContext: PlatformContext {
        get { self[PlatformContextEnvironmentKey.self] }
        set { self[PlatformContextEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// 为视图树注入特定的平台上下文
    public func platformContext(_ context: PlatformContext) -> some View {
        environment(\.platformContext, context)
    }
}
