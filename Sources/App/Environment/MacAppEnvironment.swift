//
//  MacAppEnvironment.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：平台环境适配实现，桥接 AppEnvironmentProtocol 与具体平台 API。
//
#if os(macOS)
import AppKit

/// macOS 环境能力实现 (含 Catalyst)
final class MacAppEnvironment: AppEnvironmentProtocol {
    var screenClass: ScreenClass { return .expansive }
    
    var interactionStyle: InteractionStyle { return .pointer }
    
    var supportsPencil: Bool { return false }
    
    var hasCamera: Bool { return true } // 大多数 Mac 都有摄像头
    
    var isMobile: Bool { return false }
    
    var platformName: String { return "macOS" }
    
    var deviceName: String {
        return Host.current().localizedName ?? "Mac"
    }
    
    var isCloudSyncSupported: Bool { return false } // macOS Target 暂未配置 entitlements
}
#endif
